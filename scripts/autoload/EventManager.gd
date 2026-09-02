extends Node
## EventManager — 뉴스, 코인 리스크, 라이프 이벤트 관리

signal event_triggered(event: Dictionary)
signal crypto_risk_triggered(event: Dictionary, loss: float)
signal life_event_triggered(event: Dictionary)

var _news_pool: Array = []
var _crypto_risk_pool: Array = []
var _life_event_pool: Array = []

var _active_events: Array = []  # 현재 활성 이벤트
var _rng := RandomNumberGenerator.new()

# 뉴스 쿨다운: event_id -> 마지막 발생 day
var _news_cooldown: Dictionary = {}
const NEWS_COOLDOWN_DAYS := 5  # 같은 뉴스 5일간 재발생 방지

# 매일 이벤트 발생 확률
const NEWS_CHANCE_PER_DAY := 0.65
const NEWS_MAX_PER_DAY := 3
const CRYPTO_RISK_CHANCE_PER_DAY := 0.15
const LIFE_EVENT_CHANCE_PER_DAY := 0.25


func _ready() -> void:
	_load_data()
	_rng.seed = Time.get_ticks_msec()


func _load_data() -> void:
	var data = DataUtil.load_json("res://data/events.json")
	if data == null:
		push_error("EventManager: events.json 로드 실패")
		return
	_news_pool = data.get("news", [])
	_crypto_risk_pool = data.get("crypto_risks", [])
	_life_event_pool = data.get("life_events", [])


## 하루 경과 시 호출 — 확률적으로 이벤트 발생
func roll_daily_events() -> Array:
	var triggered: Array = []

	# 뉴스 이벤트 — 하루에 최대 NEWS_MAX_PER_DAY개까지 발생 가능
	var news_chance := NEWS_CHANCE_PER_DAY
	# 결혼 버프: 뉴스 선입수 확률 증가 (서하린)
	if NPCManager.has_marriage_buff("early_news"):
		news_chance = minf(news_chance * (1.0 + NPCManager.get_marriage_buff("early_news")), 1.0)
	if _rng.randf() < news_chance:
		var news_count: int = _rng.randi() % NEWS_MAX_PER_DAY + 1
		var used_ids: Dictionary = {}
		for _i in news_count:
			var event := _pick_news_with_cooldown()
			if event.is_empty() or used_ids.has(event.get("id", "")):
				continue
			used_ids[event.get("id", "")] = true
			_apply_news(event)
			triggered.append(event)
			event_triggered.emit(event)

	# 코인 리스크 (코인 보유 시에만)
	if _has_crypto_holdings() and _rng.randf() < CRYPTO_RISK_CHANCE_PER_DAY:
		var risk := _pick_weighted(_crypto_risk_pool)
		if not risk.is_empty():
			var loss := _apply_crypto_risk(risk)
			triggered.append(risk)
			crypto_risk_triggered.emit(risk, loss)

	# 라이프 이벤트
	if _rng.randf() < LIFE_EVENT_CHANCE_PER_DAY:
		var life := _pick_weighted(_life_event_pool)
		if not life.is_empty():
			_apply_life_event(life)
			triggered.append(life)
			life_event_triggered.emit(life)

	return triggered


## 뉴스 이벤트 적용 — 해당 종목에 가격 충격
func _apply_news(event: Dictionary) -> void:
	var impact: float = event.get("impact", 0.0)
	for stock_id in event.get("stock_ids", []):
		MarketSim.apply_event(stock_id, impact)

	# 쿨다운 기록
	_news_cooldown[event.get("id", "")] = GameManager.player["day"]

	_active_events.append({
		"id": event.get("id", ""),
		"title": event.get("title", ""),
		"desc": event.get("desc", ""),
		"type": "news",
		"day": GameManager.player["day"],
	})


## 코인 리스크 적용 — 보유 코인 손실 + 시장 충격
func _apply_crypto_risk(risk: Dictionary) -> float:
	var impact: float = risk.get("impact", -0.3)
	var loss_pct: float = risk.get("loss_pct", 0.0)
	var total_loss: float = 0.0

	# 코인 가격 하락
	for stock in MarketSim.get_category_stocks("coin"):
		MarketSim.apply_event(stock["id"], impact)

	# 보유 코인 일부 증발 (해킹 등)
	if loss_pct > 0:
		for stock_id in GameManager.player["holdings"]:
			var stock: Dictionary = MarketSim.get_stock(stock_id)
			if stock.get("category") == "coin":
				var qty: int = GameManager.player["holdings"][stock_id]["quantity"]
				var lost := int(qty * loss_pct)
				if lost > 0:
					GameManager.player["holdings"][stock_id]["quantity"] -= lost
					total_loss += lost * stock["price"]

	_active_events.append({
		"id": risk.get("id", ""),
		"title": risk.get("title", ""),
		"desc": risk.get("desc", ""),
		"type": "crypto_risk",
		"day": GameManager.player["day"],
		"loss": total_loss,
	})

	return total_loss


## 라이프 이벤트 적용 — 현금 증감
func _apply_life_event(event: Dictionary) -> void:
	var reward: float = event.get("cash_reward", 0.0)
	# 주거 단계에 따라 의료비 할인
	if reward < 0:
		var house: Dictionary = GameManager.get_current_house()
		var house_index: int = GameManager.get_housing_list().find(house)
		# 고급 주거일수록 의료비 할인
		if house_index >= 5:
			reward *= 0.2
		elif house_index >= 3:
			reward *= 0.5

	GameManager.add_cash(reward)

	_active_events.append({
		"id": event.get("id", ""),
		"title": event.get("title", ""),
		"desc": event.get("desc", ""),
		"type": "life",
		"day": GameManager.player["day"],
		"reward": reward,
	})


func get_active_events() -> Array:
	return _active_events


func clear_old_events(days_to_keep: int = 10) -> void:
	var current_day: int = GameManager.player["day"]
	_active_events = _active_events.filter(
		func(e): return current_day - e.get("day", 0) <= days_to_keep
	)


## 쿨다운이 적용된 뉴스 선택
func _pick_news_with_cooldown() -> Dictionary:
	if _news_pool.is_empty():
		return {}
	var current_day: int = GameManager.player["day"]
	# 쿨다운이 지난 뉴스만 필터링
	var available: Array = []
	for item in _news_pool:
		var eid: String = item.get("id", "")
		var last_day: int = _news_cooldown.get(eid, -999)
		if current_day - last_day >= NEWS_COOLDOWN_DAYS:
			available.append(item)
	if available.is_empty():
		available = _news_pool
	return _pick_weighted(available)


# ─── 내부 유틸 ──────────────────────────────────

func _pick_weighted(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total_weight := 0
	for item in pool:
		total_weight += int(item.get("weight", 1))

	var roll := _rng.randi() % total_weight
	var cumulative := 0
	for item in pool:
		cumulative += int(item.get("weight", 1))
		if roll < cumulative:
			return item
	return pool[pool.size() - 1]


func _has_crypto_holdings() -> bool:
	for stock_id in GameManager.player["holdings"]:
		var stock: Dictionary = MarketSim.get_stock(stock_id)
		if stock.get("category") == "coin":
			return true
	return false

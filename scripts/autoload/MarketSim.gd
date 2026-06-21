extends Node
## MarketSim — 주가 시뮬레이션 엔진
## 랜덤워크 + 트렌드 + 마켓사이클 + 뉴스이벤트 영향을 결합한 가격 변동

signal price_changed(stock_id: String, new_price: float, change_pct: float)
signal market_tick
signal market_phase_changed(phase: String)

var stocks: Dictionary = {}
var market_cycle: float = 0.0
var _tick_timer: float = 0.0
var _elapsed: float = 0.0

var _tick_interval: float = 4.0
var _history_length: int = 60
var _cycle_period: float = 120.0
var _cycle_amplitude: float = 0.6

# 활성 뉴스 이벤트 멀티플라이어: stock_id -> multiplier (1.0 = 영향 없음)
var _event_multipliers: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_config()
	_load_stock_data()
	_rng.seed = Time.get_ticks_msec()


func _load_config() -> void:
	var data = _load_json("res://data/balance.json")
	if data and data.has("market"):
		var m = data["market"]
		_tick_interval = m.get("tick_interval_seconds", 2.0)
		_history_length = int(m.get("history_length", 60))
		_cycle_period = m.get("market_cycle_period", 120.0)
		_cycle_amplitude = m.get("market_cycle_amplitude", 0.6)


func _load_stock_data() -> void:
	var data = _load_json("res://data/stocks.json")
	if not data:
		push_error("MarketSim: stocks.json 로드 실패")
		return

	for s in data["stocks"]:
		var stock: Dictionary = {
			"id": s["id"],
			"name": s["name"],
			"ticker": s.get("ticker", s["id"].to_upper()),
			"category": s["category"],
			"tier": s.get("tier", "normal"),
			"sector": s.get("sector", ""),
			"desc": s.get("desc", ""),
			"price": float(s["price"]),
			"base_price": float(s["price"]),
			"volatility": float(s["volatility"]),
			"trend": float(s["trend"]),
			"day_open": float(s["price"]),
			"change_pct": 0.0,
			"dividend_yield": float(s.get("dividend_yield", 0.0)),
			"dividend_period": int(s.get("dividend_period", 7)),
			"history": [],
		}
		stock["history"].append(stock["price"])
		stocks[stock["id"]] = stock


func _process(_delta: float) -> void:
	# 시간 흐름은 GameClockManager가 관리
	# 주가 갱신은 on_hourly_update()를 통해 장중에만 호출됨
	pass


func _tick() -> void:
	_elapsed += _tick_interval
	_tick_timer = 0.0
	# 마켓 사이클: 사인파 + 노이즈 (bull/bear)
	market_cycle = sin(_elapsed / _cycle_period * TAU) * _cycle_amplitude
	market_cycle += _rng.randf_range(-0.15, 0.15)
	market_cycle = clampf(market_cycle, -1.0, 1.0)

	# 사이클 페이즈 발신
	var phase := "중립"
	if market_cycle > 0.3:
		phase = "강세"
	elif market_cycle < -0.3:
		phase = "약세"
	market_phase_changed.emit(phase)

	for stock_id in stocks:
		var stock: Dictionary = stocks[stock_id]

		# 1. 랜덤워크 (정규분포 근사)
		var random_change: float = _rng.randfn(0.0, 1.0) * stock["volatility"]

		# 2. 트렌드 성분 — 사이클에 따라 동적 부여
		# 기본 trend는 미세 상승 편향 (인플레이션 반영)
		# 강세장에서는 가속, 약세장에서는 마이너스 전환
		var base_trend: float = float(stock["trend"])
		var dynamic_trend: float = base_trend * (0.5 + market_cycle * 1.5)
		# 약세장에서는 하락 트렌드
		if market_cycle < -0.2:
			dynamic_trend -= base_trend * absf(market_cycle) * 2.0

		# 3. 마켓 사이클 영향 (코인 > 성장주 > 블루칩)
		var cycle_weight := 0.3
		if stock["category"] == "coin":
			cycle_weight = 0.8
		elif stock["tier"] == "growth":
			cycle_weight = 0.5
		var cycle_change: float = market_cycle * stock["volatility"] * cycle_weight

		# 4. 뉴스 이벤트 멀티플라이어
		var event_change: float = 0.0
		if _event_multipliers.has(stock_id):
			event_change = (_event_multipliers[stock_id] - 1.0) * 0.15
			# 이벤트 효과 감쇠
			_event_multipliers[stock_id] = lerp(_event_multipliers[stock_id], 1.0, 0.1)

		# 합산
		var total_change: float = random_change + dynamic_trend + cycle_change + event_change
		var new_price: float = float(stock["price"]) * (1.0 + total_change)

		# 하한선 (기준가 10%까지)
		new_price = maxf(new_price, stock["base_price"] * 0.1)
		# 상한선 (기준가 100배)
		new_price = minf(new_price, stock["base_price"] * 100.0)

		var change_pct: float = (new_price - float(stock["price"])) / float(stock["price"]) * 100.0

		stock["price"] = new_price
		stock["change_pct"] = (new_price - stock["day_open"]) / stock["day_open"] * 100.0

		# 히스토리 업데이트
		stock["history"].append(new_price)
		if stock["history"].size() > _history_length:
			stock["history"].pop_front()

		price_changed.emit(stock_id, new_price, change_pct)

	market_tick.emit()


## 외부 이벤트가 특정 종목에 영향을 주는 경우
func apply_event(stock_id: String, impact: float) -> void:
	# impact: -1.0 (대폭락) ~ 1.0 (대폭등)
	if stocks.has(stock_id):
		var current_mult: float = _event_multipliers.get(stock_id, 1.0)
		_event_multipliers[stock_id] = current_mult + impact


func get_stock(stock_id: String) -> Dictionary:
	return stocks.get(stock_id, {})


func get_all_stocks() -> Array:
	return stocks.values()


func get_category_stocks(category: String) -> Array:
	var result: Array = []
	for s in stocks.values():
		if s["category"] == category:
			result.append(s)
	return result


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


## 하루 경과 — 시가 갱신 (전날 종가를 오늘 시가로)
func advance_day() -> void:
	for stock_id in stocks:
		# 종가(close_price)가 있으면 그것을 시가로, 없으면 현재가
		if stocks[stock_id].has("close_price"):
			stocks[stock_id]["day_open"] = stocks[stock_id]["close_price"]
			stocks[stock_id]["price"] = stocks[stock_id]["close_price"]
		else:
			stocks[stock_id]["day_open"] = stocks[stock_id]["price"]
		stocks[stock_id]["change_pct"] = 0.0


## 장 마감 시 종가 저장
func save_close_prices() -> void:
	for stock_id in stocks:
		stocks[stock_id]["close_price"] = stocks[stock_id]["price"]


## 장 개시 — day_open 재설정
func on_market_open() -> void:
	for stock_id in stocks:
		stocks[stock_id]["day_open"] = stocks[stock_id]["price"]
		stocks[stock_id]["change_pct"] = 0.0


## 장중 1시간 경과 시 주가 갱신 (GameClockManager에서 호출)
func on_hourly_update() -> void:
	_tick()


## 장전 뉴스가 주가에 미리 영향을 줄 때
func apply_pre_market_effects() -> void:
	# 장전 뉴스 이벤트를 미리 반영
	for stock_id in stocks:
		var stock: Dictionary = stocks[stock_id]
		if _event_multipliers.has(stock_id):
			var event_change: float = (_event_multipliers[stock_id] - 1.0) * 0.05
			var new_price: float = float(stock["price"]) * (1.0 + event_change)
			new_price = maxf(new_price, stock["base_price"] * 0.1)
			new_price = minf(new_price, stock["base_price"] * 100.0)
			stock["price"] = new_price
			price_changed.emit(stock_id, new_price, 0.0)
	market_tick.emit()

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

# 종목별 일간 종가 히스토리: stock_id -> Array of {"day": int, "close": float}
var _daily_close_history: Dictionary = {}

# 종목별 일간 OHLC: stock_id -> Array of {"day": int, "open": float, "close": float}
var _daily_ohlc: Dictionary = {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_config()
	_load_stock_data()
	_rng.seed = Time.get_ticks_msec()


func _load_config() -> void:
	var data = DataUtil.load_json("res://data/balance.json")
	if data and data.has("market"):
		var m = data["market"]
		_tick_interval = m.get("tick_interval_seconds", 2.0)
		_history_length = int(m.get("history_length", 60))
		_cycle_period = m.get("market_cycle_period", 120.0)
		_cycle_amplitude = m.get("market_cycle_amplitude", 0.6)


func _load_stock_data() -> void:
	var data = DataUtil.load_json("res://data/stocks.json")
	if not data:
		push_error("MarketSim: stocks.json 로드 실패")
		return

	for s in data["stocks"]:
		var stock := {
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
		# 초기 히스토리 시드 — 시작부터 차트가 보이도록 과거 가격 생성
		var base_p: float = float(s["price"])
		for _i in range(15):
			var noise: float = _rng.randfn(0.0, 1.0) * float(s["volatility"]) * 0.5
			var seed_price: float = base_p * (1.0 + noise - float(_i) * 0.001)
			stock["history"].append(maxf(seed_price, base_p * 0.5))
		stock["history"].append(base_p)
		stocks[stock["id"]] = stock


func _process(_delta: float) -> void:
	# 시간 흐름은 GameClockManager가 관리
	# 주가 갱신은 on_hourly_update()를 통해 장중에만 호출됨
	pass


# 주가 변동 추적 (종목별)
var _stock_prev_noise: Dictionary = {}   # stock_id -> float (smoothing)
var _stock_momentum: Dictionary = {}      # stock_id -> float (최근 방향성)
var _stock_momentum_count: Dictionary = {} # stock_id -> int (같은 방향 연속 틱)

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
		var tick_changes: Array[float] = []

		# ── 종목별 설정 ──
		var vol := float(stock["volatility"])
		var tier: String = stock.get("tier", "blue")
		var category: String = stock.get("category", "")
		if NPCManager.has_marriage_buff("volatility_increase"):
			vol *= (1.0 + NPCManager.get_marriage_buff("volatility_increase"))

		# ── 1. 랜덤워크 (smoothing 적용) ──
		var raw_random: float = _rng.randfn(0.0, 1.0) * vol
		var prev_noise: float = _stock_prev_noise.get(stock_id, 0.0)
		var random_change: float = prev_noise * 0.65 + raw_random * 0.35
		_stock_prev_noise[stock_id] = random_change
		tick_changes.append(random_change)

		# ── 2. 트렌드 성분 ──
		var base_trend: float = float(stock["trend"])
		var dynamic_trend: float = base_trend * (0.5 + market_cycle * 1.5)
		if market_cycle < -0.2:
			dynamic_trend -= base_trend * absf(market_cycle) * 2.0
		tick_changes.append(dynamic_trend)

		# ── 3. 마켓 사이클 ──
		var cycle_weight := 0.3
		match tier:
			"crypto": cycle_weight = 0.8
			"growth": cycle_weight = 0.5
			_: cycle_weight = 0.3  # blue
		# 도지코인 추가 가중
		if stock_id == "dogecoin":
			cycle_weight = 1.0
		var cycle_change: float = market_cycle * vol * cycle_weight
		tick_changes.append(cycle_change)

		# ── 4. 뉴스 이벤트 ──
		var event_change: float = 0.0
		if _event_multipliers.has(stock_id):
			event_change = (_event_multipliers[stock_id] - 1.0) * 0.15
			_event_multipliers[stock_id] = lerp(_event_multipliers[stock_id], 1.0, 0.1)
		tick_changes.append(event_change)

		# ── 5. Momentum: 최근 방향 연속성이면 관성 부여 ──
		var momentum: float = _stock_momentum.get(stock_id, 0.0)
		var mom_count: int = _stock_momentum_count.get(stock_id, 0)
		var momentum_force: float = 0.0
		if mom_count >= 3:
			# 같은 방향 3틱 이상이면 관성
			momentum_force = momentum * 0.08 * minf(float(mom_count) / 5.0, 1.5)
		tick_changes.append(momentum_force)

		# ── 6. Mean Reversion: base_price 대비 이탈 시 되돌림 ──
		var base_p: float = float(stock["base_price"])
		var deviation: float = (float(stock["price"]) - base_p) / base_p
		var reversion_force: float = 0.0
		if absf(deviation) > 0.3:
			# 강세장에서는 상승 이탈 덜 되돌림
			var rev_strength: float = 0.02
			if deviation > 0 and market_cycle > 0.2:
				rev_strength *= 0.5  # 강세장 상승 -> 약한 되돌림
			elif deviation < 0 and market_cycle < -0.2:
				rev_strength *= 0.5  # 약세장 하락 -> 약한 되돌림
			reversion_force = -signf(deviation) * rev_strength * absf(deviation)
		tick_changes.append(reversion_force)

		# ── 합산 ──
		var total_change: float = 0.0
		for ch in tick_changes:
			total_change += ch

		# Per-tick 변동률 제한
		var max_tick_pct: float = 0.10  # 기본 10% (도지)
		match tier:
			"blue": max_tick_pct = 0.025
			"growth": max_tick_pct = 0.05
			"crypto": max_tick_pct = 0.08
		# 도지코인 특별처리
		if stock_id == "dogecoin":
			max_tick_pct = 0.10
		total_change = clampf(total_change, -max_tick_pct, max_tick_pct)

		var new_price: float = float(stock["price"]) * (1.0 + total_change)

		# 하한선 (기준가 10%까지)
		new_price = maxf(new_price, stock["base_price"] * 0.1)
		# 상한선 (기준가 100배)
		new_price = minf(new_price, stock["base_price"] * 100.0)

		# Momentum 방향 갱신
		var tick_pct: float = (new_price - float(stock["price"])) / float(stock["price"])
		var new_momentum: float = _stock_momentum.get(stock_id, 0.0)
		if (momentum > 0 and tick_pct > 0) or (momentum < 0 and tick_pct < 0):
			# 같은 방향 유지
			new_momentum = momentum * 0.85 + tick_pct * 0.15
			_stock_momentum_count[stock_id] = mom_count + 1
		else:
			# 방향 전환
			new_momentum = tick_pct
			_stock_momentum_count[stock_id] = 1
		_stock_momentum[stock_id] = new_momentum

		var change_pct: float = tick_pct * 100.0

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

## 특정 종목의 가격 히스토리 배열 반환
func get_price_history(stock_id: String) -> Array:
	var s: Dictionary = stocks.get(stock_id, {})
	return s.get("history", [])

## 특정 종목의 현재가 반환
func get_current_price(stock_id: String) -> float:
	var s: Dictionary = stocks.get(stock_id, {})
	return float(s.get("price", 0.0))

## 특정 종목의 등락률 반환
func get_change_percent(stock_id: String) -> float:
	var s: Dictionary = stocks.get(stock_id, {})
	return float(s.get("change_pct", 0.0))


func get_all_stocks() -> Array:
	return stocks.values()


func get_category_stocks(category: String) -> Array:
	var result: Array = []
	for s in stocks.values():
		if s["category"] == category:
			result.append(s)
	return result



## 하루 경과 — 시가 갱신 (전날 종가를 오늘 시가로) + 전일 OHLC 기록
## yesterday_day: GameManager.advance_day() 호출 전에 저장한 전날 day 값
func advance_day(yesterday_day: int = -1) -> void:
	var yesterday: int = yesterday_day if yesterday_day > 0 else GameManager.player.get("day", 1)
	for stock_id in stocks:
		# 전일 OHLC 기록 (브리핑용)
		if not _daily_ohlc.has(stock_id):
			_daily_ohlc[stock_id] = []
		var open_val: float = float(stocks[stock_id].get("day_open", stocks[stock_id]["price"]))
		var close_val: float = float(stocks[stock_id].get("close_price", stocks[stock_id]["price"]))
		_daily_ohlc[stock_id].append({"day": yesterday, "open": open_val, "close": close_val})
		# 최대 500일 유지 (무한 증가 방지)
		if _daily_ohlc[stock_id].size() > 500:
			_daily_ohlc[stock_id].pop_front()

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


## 하루 종가 기록 — 중복 방지
func record_daily_close(day: int) -> void:
	for stock_id in stocks:
		if not _daily_close_history.has(stock_id):
			_daily_close_history[stock_id] = []
		var hist: Array = _daily_close_history[stock_id]
		# 같은 day가 이미 있으면 갱신, 없으면 추가
		if hist.size() > 0:
			var last: Dictionary = hist[hist.size() - 1]
			if int(last.get("day", 0)) == day:
				last["close"] = stocks[stock_id]["price"]
				continue
		hist.append({"day": day, "close": stocks[stock_id]["price"]})
		# 최대 500일 유지
		if hist.size() > 500:
			hist.pop_front()


## 특정 종목의 D/W/M/Y 수익률 계산
## 반환: {"D": float_or_nan, "W": ..., "M": ..., "Y": ...}
func get_dwmy_returns(stock_id: String, current_day: int) -> Dictionary:
	var result := {"D": NAN, "W": NAN, "M": NAN, "Y": NAN}
	if not _daily_close_history.has(stock_id):
		return result
	var hist: Array = _daily_close_history[stock_id]
	if hist.is_empty():
		return result
	var current_price: float = 0.0
	if stocks.has(stock_id):
		current_price = stocks[stock_id]["price"]
	else:
		return result
	# 과거 특정 day의 종가 찾기 (가장 가까운 과거)
	var periods := {"D": 1, "W": 7, "M": 30, "Y": 365}
	for key in periods:
		var target_day: int = current_day - periods[key]
		var past_price: float = _find_close_before_day(hist, target_day)
		if past_price > 0 and not is_nan(past_price):
			result[key] = (current_price - past_price) / past_price * 100.0
		else:
			result[key] = NAN
	return result


## 히스토리에서 target_day 이하의 가장 가까운 종가 찾기
func _find_close_before_day(hist: Array, target_day: int) -> float:
	var best_price: float = 0.0
	for entry in hist:
		if int(entry.get("day", 0)) <= target_day:
			best_price = float(entry.get("close", 0.0))
		else:
			break
	return best_price


## 일간 종가 히스토리 직렬화
func serialize_daily_close() -> Dictionary:
	return {"close_history": _daily_close_history.duplicate(true), "ohlc": _daily_ohlc.duplicate(true)}


## 일간 종가 히스토리 역직렬화
func deserialize_daily_close(data: Dictionary) -> void:
	_daily_close_history = data.get("close_history", {}).duplicate(true)
	_daily_ohlc = data.get("ohlc", {}).duplicate(true)


## 전일 OHLC 기반 시장 요약 데이터 스냅샷 (브리핑용)
func get_yesterday_ohlc_snapshot(current_day: int) -> Dictionary:
	var target_day: int = current_day - 1
	var snapshot: Dictionary = {}
	for stock_id in _daily_ohlc:
		var arr: Array = _daily_ohlc[stock_id]
		for entry in arr:
			if entry.get("day", 0) == target_day:
				snapshot[stock_id] = entry
				break
	return snapshot


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

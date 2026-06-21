extends Node
## PassiveIncomeManager — 방치형 자동 수익 시스템
## 배당금 + 임대 수익 + 예금 이자를 매 틱마다 계산하여 적립
## 밸런스: 단계형 성장 — 초반 미미, 후반 의미있는 보조 수입

signal passive_income_earned(amount: float, source: String)
signal dividends_paid(total: float)

var _tick_timer: float = 0.0
var _tick_interval: float = 5.0
var _interest_rate: float = 0.00003  # 일일 이율
var _game_accel: float = 10.0  # 1틱 = 게임상 1/N일
var _config: Dictionary = {}

# 일일 캡 (순자산 대비 %)
var _dividend_cap_pct: float = 0.05
var _rental_cap_pct: float = 0.03
var _interest_cap_pct: float = 0.01

# 누적 통계
var _total_dividends: float = 0.0
var _total_rental: float = 0.0
var _total_interest: float = 0.0
var _last_income: float = 0.0  # 마지막 틱 수익


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	var data = _load_json("res://data/balance.json")
	if data and data.has("passive_income"):
		_config = data["passive_income"]
		_tick_interval = _config.get("tick_income_interval", 5.0)
		_interest_rate = _config.get("interest_rate_daily", 0.00003)
		_game_accel = _config.get("game_time_acceleration", 10.0)
		_dividend_cap_pct = _config.get("daily_dividend_cap_pct", 0.05)
		_rental_cap_pct = _config.get("daily_rental_cap_pct", 0.03)
		_interest_cap_pct = _config.get("daily_interest_cap_pct", 0.01)


func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= _tick_interval:
		_tick_timer = 0.0
		_process_tick()

## 매 틱마다 자동 수익 계산 — 실시간 방치형 수익
func _process_tick() -> void:
	var total_income: float = 0.0

	# 1. 배당금 (보유 주식)
	var dividend := _calc_tick_dividend()
	if dividend > 0:
		total_income += dividend
		_total_dividends += dividend
		passive_income_earned.emit(dividend, "배당")

	# 2. 임대 수익 (주거 등급)
	var rental := _calc_tick_rental()
	if rental > 0:
		total_income += rental
		_total_rental += rental
		passive_income_earned.emit(rental, "임대")

	# 3. 현금 이자
	var interest := _calc_tick_interest()
	if interest > 0:
		total_income += interest
		_total_interest += interest
		passive_income_earned.emit(interest, "이자")

	if total_income > 0:
		GameManager.add_cash(total_income)
		_last_income = total_income
		# 퀘스트 추적
		QuestManager.on_dividend_earned(total_income)

## 틱당 배당금 계산
func _calc_tick_dividend() -> float:
	var total: float = 0.0
	var interval := _tick_interval

	for stock_id in GameManager.player["holdings"]:
		var holding: Dictionary = GameManager.player["holdings"][stock_id]
		var stock: Dictionary = MarketSim.get_stock(stock_id)
		if stock.is_empty():
			continue

		var yield_pct: float = float(stock.get("dividend_yield", 0.0))
		if yield_pct <= 0.0:
			continue

		var qty: int = int(holding["quantity"])
		var value: float = float(stock["price"]) * float(qty)

		# 연간 배당률 → 일일 → 틱당 (게임 가속 반영)
		var daily_rate := yield_pct / 100.0 / 365.0
		var tick_rate := daily_rate / _game_accel

		total += value * tick_rate

	# 캡 적용: 일일 배당 한도 (순자산 * cap_pct / 게임가속)
	total = _apply_cap(total, _dividend_cap_pct)
	return total

## 틱당 임대 수익
func _calc_tick_rental() -> float:
	var house: Dictionary = GameManager.get_current_house()
	var house_id: String = house.get("id", "gosiwon")

	var rental_per_day: float = 0.0
	var rental_map: Dictionary = _config.get("rental_income_per_day", {})
	if rental_map.has(house_id):
		rental_per_day = float(rental_map[house_id])

	if rental_per_day <= 0.0:
		return 0.0

	# 하루 수익을 틱으로 분할 (게임 가속 반영)
	var rental = rental_per_day / _game_accel
	rental = _apply_cap(rental, _rental_cap_pct)
	return rental

## 틱당 현금 이자
func _calc_tick_interest() -> float:
	var cash := GameManager.get_cash()
	if cash <= 0:
		return 0.0
	# 일일 이율을 틱으로 분할 (게임 가속 반영)
	var interest = cash * _interest_rate / _game_accel
	interest = _apply_cap(interest, _interest_cap_pct)
	return interest

## 캡 적용 — 순자산 대비 일일 최대 수익 제한
func _apply_cap(amount: float, cap_pct: float) -> float:
	if amount <= 0:
		return 0.0
	var net_worth := GameManager.get_net_worth()
	if net_worth <= 0:
		return amount
	var daily_cap := net_worth * cap_pct
	var tick_cap := daily_cap / _game_accel
	return min(amount, tick_cap)

## 하루 경과 시 임대 수익 + 이자 정산 (advance_day에서 호출)
func pay_daily_rental_interest() -> Dictionary:
	var result := {"rental": 0.0, "interest": 0.0}
	
	# 임대 수익 (주거 등급)
	var house: Dictionary = GameManager.get_current_house()
	var house_id: String = house.get("id", "gosiwon")
	var rental_map: Dictionary = _config.get("rental_income_per_day", {})
	if rental_map.has(house_id):
		var daily_rental: float = float(rental_map[house_id])
		if daily_rental > 0:
			# 캡 적용
			var net_worth := GameManager.get_net_worth()
			if net_worth > 0:
				var cap := net_worth * _rental_cap_pct
				daily_rental = min(daily_rental, cap)
			GameManager.add_cash(daily_rental)
			_total_rental += daily_rental
			result["rental"] = daily_rental
	
	# 현금 이자
	var cash := GameManager.get_cash()
	if cash > 0:
		var daily_interest: float = cash * _interest_rate
		if daily_interest > 0:
			# 캡 적용
			var net_worth := GameManager.get_net_worth()
			if net_worth > 0:
				var cap := net_worth * _interest_cap_pct
				daily_interest = min(daily_interest, cap)
			GameManager.add_cash(daily_interest)
			_total_interest += daily_interest
			result["interest"] = daily_interest
	
	return result
func pay_daily_dividends() -> float:
	var total: float = 0.0

	for stock_id in GameManager.player["holdings"]:
		var holding: Dictionary = GameManager.player["holdings"][stock_id]
		var stock: Dictionary = MarketSim.get_stock(stock_id)
		if stock.is_empty():
			continue

		var yield_pct: float = float(stock.get("dividend_yield", 0.0))
		if yield_pct <= 0.0:
			continue

		var period: int = int(stock.get("dividend_period", 7))
		# 배당 주기마다 지급
		if GameManager.player["day"] % period != 0:
			continue

		var qty: int = int(holding["quantity"])
		var value: float = stock["price"] * qty
		# 연간 배당률 / 365 * 주기(일)
		var dividend: float = value * yield_pct / 100.0 / 365.0 * period
		total += dividend

	# 일일 캡 적용
	if total > 0:
		var net_worth := GameManager.get_net_worth()
		var cap := net_worth * _dividend_cap_pct
		total = min(total, cap)
		GameManager.add_cash(total)
		_total_dividends += total
		dividends_paid.emit(total)

	return total


# ─── 통계 조회 ──────────────────────────────────

func get_total_dividends() -> float:
	return _total_dividends

func get_total_rental() -> float:
	return _total_rental

func get_total_interest() -> float:
	return _total_interest

func get_total_passive() -> float:
	return _total_dividends + _total_rental + _total_interest

func get_last_tick_income() -> float:
	return _last_income

## 초당 예상 수익 (UI 표시용)
func get_projected_per_second() -> float:
	var dividend := _calc_tick_dividend()
	var rental := _calc_tick_rental()
	var interest := _calc_tick_interest()
	return (dividend + rental + interest) / _tick_interval

## 하루 예상 수익 (UI 표시용)
func get_projected_per_day() -> float:
	return get_projected_per_second() * 86400.0 / _game_accel

## 각 항목별 예상 수익 (UI 세분화용)
func get_projected_breakdown() -> Dictionary:
	return {
		"dividend": _calc_tick_dividend() / _tick_interval,
		"rental": _calc_tick_rental() / _tick_interval,
		"interest": _calc_tick_interest() / _tick_interval
	}

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

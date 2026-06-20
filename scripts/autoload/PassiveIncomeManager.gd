extends Node
## PassiveIncomeManager — 방치형 자동 수익 시스템
## 배당금 + 임대 수익 + 예금 이자를 매 틱마다 계산하여 적립

signal passive_income_earned(amount: float, source: String)
signal dividends_paid(total: float)

var _tick_timer: float = 0.0
var _tick_interval: float = 5.0
var _interest_rate: float = 0.0001  # 일일 이율
var _config: Dictionary = {}

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
		_interest_rate = _config.get("interest_rate_daily", 0.0001)


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

		var period: int = int(stock.get("dividend_period", 7))
		var qty: int = int(holding["quantity"])
		var value: float = float(stock["price"]) * float(qty)

		# 연간 배당률을 일일로 변환 → 틱당으로 변환
		var daily_rate := yield_pct / 100.0 / 365.0
		var tick_rate := daily_rate * (interval / 86400.0)  # 틱을 하루(86400초) 기준으로 환산
		# 게임 시간 가속: 1틱 = 게임상 하루의 1/10로 가정
		tick_rate = daily_rate / 10.0

		total += value * tick_rate

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

	# 하루 수익을 틱으로 분할 (1틱 = 게임상 하루의 1/10)
	return rental_per_day / 10.0


## 틱당 현금 이자
func _calc_tick_interest() -> float:
	var cash := GameManager.get_cash()
	if cash <= 0:
		return 0.0
	# 일일 이율을 틱으로 분할
	return cash * _interest_rate / 10.0


## 하루 경과 시 일괄 배당 지급 (큰 금액, 정기적)
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

	if total > 0:
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
	return get_projected_per_second() * 86400.0 / 10.0  # 게임 시간 가속 반영


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

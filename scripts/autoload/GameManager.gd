extends Node
## GameManager — 플레이어 상태, 스탯, 결혼, 세대교체 관리

signal cash_changed(cash: float)
signal holdings_changed
signal net_worth_changed(net_worth: float)
signal day_advanced(day: int)
signal rank_up(new_rank: String)
signal energy_changed(energy: int, max_energy: int)

var player: Dictionary = {}

const DEFAULT_PLAYER := {
	"name": "투자자",
	"cash": 10_000_000.0,
	"day": 1,
	"rank_index": 0,
	"energy": 10,
	"max_energy": 10,
	"holdings": {},        # stock_id -> {"quantity": int, "avg_price": float}
	"married": null,       # NPC id or null
	"generation": 1,
	"house": "gosiwon",
	"vehicle": "bicycle",
	"furniture": [],
	"auto_trade_slots": [],
	"stats": {
		"info_power": 5,
		"stamina": 5,
		"luck": 5,
		"charisma": 5,
	},
	"total_profit": 0.0,
	"trade_count": 0,
	"winning_trades": 0,
	"first_trades_used": 0,  # 초반 보호 (첫 3거래 수익 보장)
}

var _balance: Dictionary = {}


func _ready() -> void:
	_load_balance()
	reset_player()


func _load_balance() -> void:
	var file := FileAccess.open("res://data/balance.json", FileAccess.READ)
	if file:
		_balance = JSON.parse_string(file.get_as_text())
		file.close()


func reset_player() -> void:
	# 깊은 복사
	player = DEFAULT_PLAYER.duplicate(true)
	var start_cash: float = _balance.get("player", {}).get("starting_cash", 10_000_000)
	player["cash"] = float(start_cash)
	player["max_energy"] = _balance.get("player", {}).get("starting_energy", 10)
	player["energy"] = player["max_energy"]


# ─── 현금 ───────────────────────────────────────

func get_cash() -> float:
	return player["cash"]


func can_afford(amount: float) -> bool:
	return player["cash"] >= amount


func add_cash(amount: float) -> void:
	player["cash"] += amount
	cash_changed.emit(player["cash"])


# ─── 매매 ───────────────────────────────────────

func buy_stock(stock_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return _fail("수량 오류")

	var stock := MarketSim.get_stock(stock_id)
	if stock.is_empty():
		return _fail("존재하지 않는 종목")

	var price: float = stock["price"]
	var cost := price * quantity
	var fee := _calc_fee(cost, true)
	var total := cost + fee

	if player["cash"] < total:
		return _fail("잔액 부족 (필요: %s원)" % _format_won(total))

	player["cash"] -= total

	# 보유 내역 갱신
	var holding: Dictionary = player["holdings"].get(stock_id, {"quantity": 0, "avg_price": 0.0})
	var old_total: float = float(holding["quantity"]) * float(holding["avg_price"])
	holding["quantity"] += quantity
	holding["avg_price"] = (old_total + cost) / holding["quantity"]
	player["holdings"][stock_id] = holding

	player["trade_count"] += 1
	cash_changed.emit(player["cash"])
	holdings_changed.emit()
	_emit_net_worth()

	return {"success": true, "cost": total, "fee": fee, "quantity": quantity}


func sell_stock(stock_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return _fail("수량 오류")

	var holding: Dictionary = player["holdings"].get(stock_id, {})
	if holding.get("quantity", 0) < quantity:
		return _fail("보유 수량 부족")

	var stock := MarketSim.get_stock(stock_id)
	if stock.is_empty():
		return _fail("종목 정보 오류")

	var revenue: float = stock["price"] * quantity
	var fee := _calc_fee(revenue, false)
	var net := revenue - fee

	# 수익 계산
	var profit: float = net - (float(holding["avg_price"]) * float(quantity))
	player["total_profit"] += profit
	if profit > 0:
		player["winning_trades"] += 1

	# 보유 내역 갱신
	holding["quantity"] -= quantity
	if holding["quantity"] <= 0:
		player["holdings"].erase(stock_id)
	else:
		player["holdings"][stock_id] = holding

	player["cash"] += net
	player["trade_count"] += 1

	cash_changed.emit(player["cash"])
	holdings_changed.emit()
	_emit_net_worth()

	return {"success": true, "revenue": net, "fee": fee, "profit": profit}


func _calc_fee(amount: float, is_buy: bool) -> float:
	var rate: float = _balance.get("player", {}).get("trade_fee_rate", 0.00015)

	# 초보 보호: 첫 7일 수수료 50% 할인
	if player["day"] <= _balance.get("difficulty", {}).get("newbie_fee_discount_days", 7):
		var discount: float = _balance.get("player", {}).get("trade_fee_discount_newbie", 0.5)
		rate *= (1.0 - discount)

	return amount * rate


# ─── 포트폴리오 ──────────────────────────────────

func get_holding(stock_id: String) -> Dictionary:
	return player["holdings"].get(stock_id, {})


func get_holding_quantity(stock_id: String) -> int:
	return player["holdings"].get(stock_id, {}).get("quantity", 0)


func get_net_worth() -> float:
	var worth: float = player["cash"]
	for stock_id in player["holdings"]:
		var stock := MarketSim.get_stock(stock_id)
		if not stock.is_empty():
			worth += stock["price"] * player["holdings"][stock_id]["quantity"]
	return worth


func _emit_net_worth() -> void:
	net_worth_changed.emit(get_net_worth())


# ─── 경과 / 직급 ────────────────────────────────

signal salary_paid(amount: float)

func advance_day() -> Dictionary:
	player["day"] += 1
	var result := {"day": player["day"], "salary": 0.0, "rank_up": ""}

	# 월급 지급 (7일마다)
	var salary_days: int = _balance.get("career", {}).get("salary_interval_days", 7)
	if player["day"] % salary_days == 0:
		var ranks: Array = _balance.get("career", {}).get("ranks", [])
		if ranks.size() > player["rank_index"]:
			var salary: float = ranks[player["rank_index"]]["salary"]
			player["cash"] += salary
			result["salary"] = salary
			cash_changed.emit(player["cash"])
			salary_paid.emit(salary)

	var old_rank: int = player["rank_index"]
	_check_rank_up()
	if player["rank_index"] > old_rank:
		result["rank_up"] = get_rank_name()

	# 정보력 회복 (하루 경과 시)
	var regen := get_energy_regen_rate()
	recover_energy(regen)

	# 정기 배당금 지급
	var dividends := PassiveIncomeManager.pay_daily_dividends()
	if dividends > 0:
		result["dividends"] = dividends

	# 파산 방지 지원금
	var bailout_thresh: float = _balance.get("difficulty", {}).get("bailout_threshold", 500000)
	var bailout_amt: float = _balance.get("difficulty", {}).get("bailout_amount", 2000000)
	if get_net_worth() < bailout_thresh:
		player["cash"] += bailout_amt
		result["bailout"] = bailout_amt
		cash_changed.emit(player["cash"])

	day_advanced.emit(player["day"])
	return result


func _check_rank_up() -> void:
	var ranks: Array = _balance.get("career", {}).get("ranks", [])
	var net_worth := get_net_worth()

	while player["rank_index"] + 1 < ranks.size():
		var next_rank: Dictionary = ranks[player["rank_index"] + 1]
		var req: float = next_rank["required_net_worth"]
		if net_worth >= req:
			player["rank_index"] += 1
			rank_up.emit(next_rank["rank"])
		else:
			break


func get_rank_name() -> String:
	var ranks: Array = _balance.get("career", {}).get("ranks", [])
	if ranks.size() > player["rank_index"]:
		return ranks[player["rank_index"]]["rank"]
	return "신입사원"


# ─── 라이프 시스템 (주거/차량) ────────────────────

func get_housing_list() -> Array:
	return _balance.get("housing", [])

func get_vehicle_list() -> Array:
	return _balance.get("vehicles", [])

func get_current_house() -> Dictionary:
	for h in get_housing_list():
		if h["id"] == player["house"]:
			return h
	return {}

func get_current_vehicle() -> Dictionary:
	for v in get_vehicle_list():
		if v["id"] == player["vehicle"]:
			return v
	return {}

func buy_house(house_id: String) -> Dictionary:
	var house: Dictionary = {}
	for h in get_housing_list():
		if h["id"] == house_id:
			house = h
			break
	if house.is_empty():
		return _fail("존재하지 않는 주거")

	var current := get_current_house()
	var current_idx := get_housing_list().find(current)
	var new_idx := get_housing_list().find(house)
	if new_idx <= current_idx:
		return _fail("같거나 낮은 등급입니다")

	var price: float = house["price"]
	if player["cash"] < price:
		return _fail("잔액 부족")

	player["cash"] -= price
	player["house"] = house_id
	cash_changed.emit(player["cash"])
	return {"success": true, "house": house}

func buy_vehicle(vehicle_id: String) -> Dictionary:
	var vehicle: Dictionary = {}
	for v in get_vehicle_list():
		if v["id"] == vehicle_id:
			vehicle = v
			break
	if vehicle.is_empty():
		return _fail("존재하지 않는 차량")

	var current := get_current_vehicle()
	var current_idx := get_vehicle_list().find(current)
	var new_idx := get_vehicle_list().find(vehicle)
	if new_idx <= current_idx:
		return _fail("같거나 낮은 등급입니다")

	var price: float = vehicle["price"]
	if player["cash"] < price:
		return _fail("잔액 부족")

	player["cash"] -= price
	player["vehicle"] = vehicle_id
	cash_changed.emit(player["cash"])
	return {"success": true, "vehicle": vehicle}


# ─── 정보력 (에너지) 시스템 ────────────────────────

func get_energy() -> int:
	return int(player.get("energy", 10))


func get_max_energy() -> int:
	var base: int = int(player.get("max_energy", 10))
	# 주거 보너스
	var house: Dictionary = get_current_house()
	base += int(house.get("energy_bonus", 0))
	# 차량 보너스
	var vehicle: Dictionary = get_current_vehicle()
	base += int(vehicle.get("energy_bonus", 0))
	# 결혼 버프: 체력 +50%
	if NPCManager.has_marriage_buff("stamina_boost"):
		base = int(base * (1.0 + NPCManager.get_marriage_buff("stamina_boost")))
	# 결혼 디버프: 정보력 -2
	if NPCManager.has_marriage_buff("energy_penalty"):
		base -= int(NPCManager.get_marriage_buff("energy_penalty"))
	return maxi(base, 1)


func spend_energy(amount: int) -> bool:
	if player["energy"] < amount:
		return false
	player["energy"] -= amount
	energy_changed.emit(get_energy(), get_max_energy())
	return true


func recover_energy(amount: int) -> void:
	var max_e := get_max_energy()
	player["energy"] = mini(player["energy"] + amount, max_e)
	energy_changed.emit(get_energy(), get_max_energy())


func get_energy_regen_rate() -> int:
	# 하루당 회복량: 기본 3 + 주거 보너스
	var rate := 3
	var house: Dictionary = get_current_house()
	rate += int(house.get("energy_bonus", 0))
	# 결혼 디버프: 정보력 회복 -1
	if NPCManager.has_marriage_buff("energy_regen"):
		rate += int(NPCManager.get_marriage_buff("energy_regen"))
	return maxi(rate, 1)


# ─── 유틸 ──────────────────────────────────────

func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}


func _format_won(amount: float) -> String:
	return "%.0f" % amount + "원"

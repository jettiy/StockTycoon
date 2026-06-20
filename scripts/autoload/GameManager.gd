extends Node
## GameManager — 플레이어 상태, 스탯, 결혼, 세대교체 관리

signal cash_changed(cash: float)
signal holdings_changed
signal net_worth_changed(net_worth: float)
signal day_advanced(day: int)
signal rank_up(new_rank: String)

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

func advance_day() -> void:
	player["day"] += 1

	# 월급 지급 (7일마다)
	var salary_days: int = _balance.get("career", {}).get("salary_interval_days", 7)
	if player["day"] % salary_days == 0:
		var ranks: Array = _balance.get("career", {}).get("ranks", [])
		if ranks.size() > player["rank_index"]:
			var salary: float = ranks[player["rank_index"]]["salary"]
			player["cash"] += salary
			cash_changed.emit(player["cash"])

	_check_rank_up()
	day_advanced.emit(player["day"])


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


# ─── 유틸 ──────────────────────────────────────

func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}


func _format_won(amount: float) -> String:
	return "%,.0f" % amount

extends Node
## AutoTradeManager — 자동매매 슬롯 관리
## 조건을 설정하면 실시간 및 오프라인에서 자동으로 거래 실행

signal slot_updated(index: int)
signal auto_trade_executed(slot: Dictionary, result: Dictionary)

var slots: Array[Dictionary] = []
const MAX_SLOTS := 4

const CONDITION_TYPES := {
	"price_below": "가격이 X 이하면",
	"price_above": "가격이 X 이상이면",
	"profit_above": "수익률 X% 달성 시",
	"loss_below": "손실률 X% 도달 시",
}


func _ready() -> void:
	# 기본 슬롯 4개 초기화 (비활성)
	for i in MAX_SLOTS:
		slots.append(_empty_slot())


func _empty_slot() -> Dictionary:
	return {
		"active": false,
		"stock_id": "",
		"condition_type": "price_below",
		"condition_value": 0.0,
		"action": "buy",  # buy or sell
		"quantity": 1,
		"executed_count": 0,
	}


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= MAX_SLOTS:
		return {}
	return slots[index]


func get_active_count() -> int:
	var count := 0
	for s in slots:
		if s["active"]:
			count += 1
	return count


func set_slot(index: int, data: Dictionary) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	slots[index] = data
	slot_updated.emit(index)


func toggle_slot(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	slots[index]["active"] = not slots[index]["active"]
	slot_updated.emit(index)


## MarketSim tick마다 호출 — 활성 슬롯 조건 확인 후 자동 거래
func check_and_execute() -> void:
	for i in MAX_SLOTS:
		var slot: Dictionary = slots[i]
		if not slot["active"] or slot["stock_id"] == "":
			continue

		if _check_condition(slot):
			_execute_trade(i, slot)


func _check_condition(slot: Dictionary) -> bool:
	var stock := MarketSim.get_stock(slot["stock_id"])
	if stock.is_empty():
		return false

	var price: float = stock["price"]
	var cond_type: String = slot["condition_type"]
	var cond_val: float = slot["condition_value"]

	match cond_type:
		"price_below":
			return price <= cond_val
		"price_above":
			return price >= cond_val
		"profit_above":
			var holding := GameManager.get_holding(slot["stock_id"])
			if holding.get("quantity", 0) <= 0:
				return false
			var avg: float = holding["avg_price"]
			var profit_pct := (price - avg) / avg * 100.0
			return profit_pct >= cond_val
		"loss_below":
			var holding2 := GameManager.get_holding(slot["stock_id"])
			if holding2.get("quantity", 0) <= 0:
				return false
			var avg2: float = holding2["avg_price"]
			var loss_pct := (avg2 - price) / avg2 * 100.0
			return loss_pct >= cond_val

	return false


func _execute_trade(index: int, slot: Dictionary) -> void:
	var result: Dictionary
	if slot["action"] == "buy":
		result = GameManager.buy_stock(slot["stock_id"], slot["quantity"])
	else:
		result = GameManager.sell_stock(slot["stock_id"], slot["quantity"])

	if result.get("success", false):
		slot["executed_count"] += 1
		# 일회성 조건이면 비활성화 (수익/손실률은 일회성)
		if slot["condition_type"] in ["profit_above", "loss_below"]:
			slot["active"] = false
		auto_trade_executed.emit(slot, result)
		slot_updated.emit(index)


## 오프라인 보상 계산 — 자동매매 시뮬레이션 (간소화)
func simulate_offline(ticks: int) -> Dictionary:
	var trades_executed := 0
	var total_profit: float = 0.0

	for i in MAX_SLOTS:
		var slot: Dictionary = slots[i]
		if not slot["active"] or slot["stock_id"] == "":
			continue

		var stock := MarketSim.get_stock(slot["stock_id"])
		if stock.is_empty():
			continue

		# 오프라인 동안 평균 가격으로 시뮬레이션
		var avg_price: float = stock["price"]
		var cond_val: float = slot["condition_value"]

		# 간단한 조건 확인
		var ctype: String = slot["condition_type"]
		if ctype == "price_below" and avg_price <= cond_val and slot["action"] == "buy":
			trades_executed += 1
		elif ctype == "price_above" and avg_price >= cond_val and slot["action"] == "sell":
			var holding := GameManager.get_holding(slot["stock_id"])
			if holding.get("quantity", 0) > 0:
				trades_executed += 1
		elif ctype == "profit_above":
			var holding2 := GameManager.get_holding(slot["stock_id"])
			if holding2.get("quantity", 0) > 0:
				var avg_p: float = float(holding2["avg_price"])
				var profit_pct: float = (avg_price - avg_p) / avg_p * 100.0
				if profit_pct >= cond_val:
					trades_executed += 1

	return {
		"trades": trades_executed,
	}

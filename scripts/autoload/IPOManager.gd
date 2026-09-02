extends Node
## IPOManager — IPO 예비 종목 관리, 청약, 상장 처리

signal ipo_announced(ipo: Dictionary)
signal ipo_listed(ipo: Dictionary, listing_price: float)

var _ipo_pool: Array = []  # 전체 IPO 데이터
var _pending: Dictionary = {}  # ipo_id -> {status, subscribed_amount, allocated_qty}
var _listed: Dictionary = {}  # ipo_id -> true (이미 상장됨)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_data()
	_rng.seed = Time.get_ticks_msec()


func _load_data() -> void:
	var path := "res://data/ipo_stocks.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return
	_ipo_pool = data.get("ipo_stocks", [])


## 매일 경과 시 호출 — IPO 이벤트 처리
func on_day_advanced(current_day: int) -> void:
	for ipo in _ipo_pool:
		var ipo_id: String = ipo.get("id", "")
		if _listed.has(ipo_id):
			continue

		# IPO 예정 공지
		if current_day == int(ipo.get("ipo_announce_day", 0)):
			ipo_announced.emit(ipo)

		# 청약 기간 시작
		if current_day == int(ipo.get("subscription_start_day", 0)):
			_pending[ipo_id] = {
				"status": "subscribing",
				"subscribed_amount": 0.0,
				"allocated_qty": 0
			}

		# 청약 종료 — 배정 확정
		if current_day == int(ipo.get("subscription_end_day", 0)) + 1:
			_finalize_subscription(ipo_id)

		# 상장일 — MarketSim에 종목 추가
		if current_day == int(ipo.get("listing_day", 0)):
			_list_stock(ipo)


## 청약 — 유저가 금액을 지불
func subscribe(ipo_id: String, amount: float) -> Dictionary:
	if not _pending.has(ipo_id):
		return {"success": false, "reason": "청약 가능한 IPO가 아닙니다"}
	var entry: Dictionary = _pending[ipo_id]
	if entry.get("status", "") != "subscribing":
		return {"success": false, "reason": "청약 기간이 아닙니다"}
	if amount <= 0:
		return {"success": false, "reason": "금액 오류"}
	if GameManager.get_cash() < amount:
		return {"success": false, "reason": "잔액 부족"}

	GameManager.add_cash(-amount)
	entry["subscribed_amount"] = float(entry.get("subscribed_amount", 0)) + amount
	_pending[ipo_id] = entry
	return {"success": true, "subscribed": amount}


## 청약 종료 — 배정 수량 확정, 미배정 금액 환불
func _finalize_subscription(ipo_id: String) -> void:
	if not _pending.has(ipo_id):
		return
	var entry: Dictionary = _pending[ipo_id]
	var ipo: Dictionary = _get_ipo_def(ipo_id)
	if ipo.is_empty():
		return

	var sub_amount: float = float(entry.get("subscribed_amount", 0))
	if sub_amount <= 0:
		entry["status"] = "closed"
		_pending[ipo_id] = entry
		return

	var sub_price: float = float(ipo.get("subscription_price", 0))
	var alloc_rate: float = float(ipo.get("allocation_rate", 0.3))

	# 배정 수량 = (청약금 / 공모가) * 배정률
	var raw_qty: float = sub_amount / sub_price if sub_price > 0 else 0
	var allocated_qty: int = int(raw_qty * alloc_rate)
	entry["allocated_qty"] = allocated_qty

	# 미배정 금액 환불
	var refund_amount: float = sub_amount - (float(allocated_qty) * sub_price)
	if refund_amount > 0:
		GameManager.add_cash(refund_amount)

	entry["status"] = "closed"
	_pending[ipo_id] = entry


## 상장 — MarketSim에 종목 동적 추가 + 배정 주식 편입
func _list_stock(ipo: Dictionary) -> void:
	var ipo_id: String = ipo.get("id", "")
	if _listed.has(ipo_id):
		return

	# 상장가 결정 (예상 범위 내 랜덤)
	var min_p: float = float(ipo.get("expected_listing_price_min", 0))
	var max_p: float = float(ipo.get("expected_listing_price_max", 0))
	var listing_price: float = lerpf(min_p, max_p, _rng.randf()) if max_p > min_p else min_p

	# MarketSim에 종목 추가
	MarketSim.stocks[ipo_id] = {
		"id": ipo_id,
		"name": ipo.get("name", ipo_id),
		"ticker": ipo.get("ticker", ipo_id.to_upper()),
		"category": ipo.get("region", "korea"),
		"tier": "normal",
		"sector": ipo.get("sector", ""),
		"desc": ipo.get("description", ""),
		"price": listing_price,
		"base_price": listing_price,
		"volatility": float(ipo.get("volatility", 0.04)),
		"trend": float(ipo.get("trend", 0.002)),
		"day_open": listing_price,
		"change_pct": 0.0,
		"dividend_yield": 0.0,
		"dividend_period": 0,
		"history": [listing_price],
	}

	_listed[ipo_id] = true

	# 배정받은 주식 편입
	if _pending.has(ipo_id):
		var entry: Dictionary = _pending[ipo_id]
		var allocated: int = int(entry.get("allocated_qty", 0))
		if allocated > 0:
			var holding: Dictionary = GameManager.player["holdings"].get(ipo_id, {"quantity": 0, "avg_price": 0.0})
			var existing_qty: int = int(holding.get("quantity", 0))
			var existing_avg: float = float(holding.get("avg_price", 0.0))
			var ipo_price: float = float(ipo.get("subscription_price", listing_price))
			holding["quantity"] = existing_qty + allocated
			# 가중평균: 기존 보유량이 있으면 가중평균, 없으면 공모가
			if existing_qty > 0:
				holding["avg_price"] = (existing_qty * existing_avg + allocated * ipo_price) / holding["quantity"]
			else:
				holding["avg_price"] = ipo_price
			GameManager.player["holdings"][ipo_id] = holding
			GameManager.holdings_changed.emit()

		entry["status"] = "listed"
		_pending[ipo_id] = entry

	ipo_listed.emit(ipo, listing_price)


## 현재 청약 가능한 IPO 목록
func get_active_ipos() -> Array:
	var result: Array = []
	for ipo in _ipo_pool:
		var ipo_id: String = ipo.get("id", "")
		if _listed.has(ipo_id):
			continue
		var status := get_status(ipo_id, GameManager.player.get("day", 1))
		if status != "none":
			result.append({
				"ipo": ipo,
				"status": status,
				"pending": _pending.get(ipo_id, {})
			})
	return result


## IPO 상태 반환
func get_status(ipo_id: String, current_day: int) -> String:
	if _listed.has(ipo_id):
		return "listed"
	var ipo: Dictionary = _get_ipo_def(ipo_id)
	if ipo.is_empty():
		return "none"
	if current_day < int(ipo.get("ipo_announce_day", 0)):
		return "none"
	if current_day < int(ipo.get("subscription_start_day", 0)):
		return "announced"
	if current_day <= int(ipo.get("subscription_end_day", 0)):
		return "subscribing"
	if current_day < int(ipo.get("listing_day", 0)):
		return "closed"
	return "listing_day"


func _get_ipo_def(ipo_id: String) -> Dictionary:
	for ipo in _ipo_pool:
		if ipo.get("id", "") == ipo_id:
			return ipo
	return {}


## 직렬화
func serialize() -> Dictionary:
	return {
		"pending": _pending.duplicate(true),
		"listed": _listed.duplicate(true),
	}


## 역직렬화
func deserialize(data: Dictionary) -> void:
	if data.has("pending"):
		_pending = data["pending"].duplicate(true)
	if data.has("listed"):
		_listed = data["listed"].duplicate(true)

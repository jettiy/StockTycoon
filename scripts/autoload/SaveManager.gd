extends Node
## SaveManager — JSON 기반 저장/로드 + 오프라인 보상

const SAVE_PATH := "user://stocktycoon_save.json"

signal saved
signal loaded


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"player": GameManager.player,
		"market": _serialize_market(),
		"autotrade": AutoTradeManager.slots,
		"npc": NPCManager.serialize(),
		"events": {"active": EventManager.get_active_events()},
		"timestamp": Time.get_unix_time_from_system(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: 저장 실패")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit()
	return true


func load_game() -> bool:
	if not has_save():
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null:
		return false

	# 플레이어 복원
	if data.has("player"):
		GameManager.player = data["player"]

	# 마켓 복원
	if data.has("market"):
		_deserialize_market(data["market"])

	# 자동매매 복원
	if data.has("autotrade"):
		_deserialize_autotrade(data["autotrade"])

	# NPC 복원
	if data.has("npc"):
		NPCManager.deserialize(data["npc"])

	# 이벤트 복원
	if data.has("events") and data["events"].has("active"):
		EventManager._active_events = data["events"]["active"]

	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_market() -> Dictionary:
	var result := {}
	for stock_id in MarketSim.stocks:
		var s: Dictionary = MarketSim.stocks[stock_id]
		result[stock_id] = {
			"price": s["price"],
			"day_open": s["day_open"],
		}
	return result


func _deserialize_market(data: Dictionary) -> void:
	for stock_id in data:
		if MarketSim.stocks.has(stock_id):
			MarketSim.stocks[stock_id]["price"] = data[stock_id]["price"]
			MarketSim.stocks[stock_id]["day_open"] = data[stock_id]["day_open"]


func _deserialize_autotrade(data: Array) -> void:
	for i in range(mini(data.size(), AutoTradeManager.MAX_SLOTS)):
		var saved_slot: Dictionary = data[i]
		# 병합: 기존 슬롯 기본값 + 저장된 값
		var slot := AutoTradeManager.get_slot(i)
		for key in saved_slot:
			slot[key] = saved_slot[key]
		AutoTradeManager.set_slot(i, slot)


## 오프라인 보상 계산 — 순자산 기반 수동 수익 + 자동매매 시뮬레이션
func calculate_offline_rewards() -> Dictionary:
	if not has_save():
		return {"cash": 0.0, "time_seconds": 0.0, "auto_trades": 0}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {"cash": 0.0, "time_seconds": 0.0, "auto_trades": 0}
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data.has("timestamp"):
		return {"cash": 0.0, "time_seconds": 0.0, "auto_trades": 0}

	var now := Time.get_unix_time_from_system()
	var elapsed: float = float(now) - float(data["timestamp"])

	# 최소 60초부터 보상
	if elapsed < 60:
		return {"cash": 0.0, "time_seconds": 0.0, "auto_trades": 0}

	# 최대 8시간까지만 보상
	var capped: float = minf(elapsed, 8 * 3600)

	# 시간당 순자산의 2% 보상
	var net_worth: float = GameManager.get_net_worth()
	var rate := 0.02 / 3600.0  # 초당
	var reward: float = net_worth * rate * capped

	# 자동매매 시뮬레이션
	var ticks := int(capped / 2.0)  # 2초당 1틱
	var auto_result := AutoTradeManager.simulate_offline(ticks)
	var auto_trades: int = auto_result.get("trades", 0)

	# 자동매매 수익 (간소화: 각 거래당 순자산 0.5%)
	if auto_trades > 0:
		reward += net_worth * 0.005 * auto_trades

	return {
		"cash": reward,
		"time_seconds": capped,
		"auto_trades": auto_trades,
	}


## 오프라인 보상을 실제로 적용
func apply_offline_rewards() -> Dictionary:
	var rewards := calculate_offline_rewards()
	if rewards["cash"] > 0:
		GameManager.add_cash(rewards["cash"])
	return rewards

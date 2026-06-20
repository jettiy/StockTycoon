extends Node
## SaveManager — JSON 기반 저장/로드

const SAVE_PATH := "user://stocktycoon_save.json"

signal saved
signal loaded

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"player": GameManager.player,
		"market": _serialize_market(),
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


## 오프라인 보상 계산 (간소화)
func calculate_offline_rewards() -> Dictionary:
	if not has_save():
		return {"cash": 0.0, "time_seconds": 0}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {"cash": 0.0, "time_seconds": 0}
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data.has("timestamp"):
		return {"cash": 0.0, "time_seconds": 0}

	var now := Time.get_unix_time_from_system()
	var elapsed: float = now - data["timestamp"]

	# 최대 8시간까지만 보상
	var capped := minf(elapsed, 8 * 3600)

	# 시간당 순자산의 2% 보상 (간소화)
	var net_worth: float = GameManager.get_net_worth()
	var rate := 0.02 / 3600.0  # 초당
	var reward: float = net_worth * rate * capped

	return {
		"cash": reward,
		"time_seconds": capped,
	}

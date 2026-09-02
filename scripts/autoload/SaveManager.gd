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
		"events": {
			"active": EventManager.get_active_events(),
			"news_cooldown": EventManager._news_cooldown.duplicate(true),
		},
		"passive_stats": {
			"dividends": PassiveIncomeManager.get_total_dividends(),
			"rental": PassiveIncomeManager.get_total_rental(),
			"interest": PassiveIncomeManager.get_total_interest(),
		},
		"story": StoryManager.serialize(),
		"quests": QuestManager.serialize(),
		"businesses": BusinessManager.serialize(),
		"clock": GameClockManager.serialize(),
		"ipo": IPOManager.serialize(),
		"net_worth_history": GameManager.serialize_net_worth_history(),
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
	if data.has("events"):
		if data["events"].has("active"):
			EventManager._active_events = data["events"]["active"]
		if data["events"].has("news_cooldown"):
			EventManager._news_cooldown = data["events"]["news_cooldown"]

	# 패시브 수익 통계 복원
	if data.has("passive_stats"):
		var ps: Dictionary = data["passive_stats"]
		if ps.has("dividends"):
			PassiveIncomeManager._total_dividends = float(ps["dividends"])
		if ps.has("rental"):
			PassiveIncomeManager._total_rental = float(ps["rental"])
		if ps.has("interest"):
			PassiveIncomeManager._total_interest = float(ps["interest"])

	# 스토리 복원
	if data.has("story"):
		StoryManager.deserialize(data["story"])
	
	# 퀘스트/업적 복원
	if data.has("quests"):
		QuestManager.deserialize(data["quests"])
	
	# 사업 복원
	if data.has("businesses"):
		BusinessManager.deserialize(data["businesses"])
	
	# 시계 복원
	if data.has("clock"):
		GameClockManager.deserialize(data["clock"])

	# IPO 복원
	if data.has("ipo"):
		IPOManager.deserialize(data["ipo"])

	# 순자산 히스토리 복원
	if data.has("net_worth_history"):
		GameManager.deserialize_net_worth_history(data["net_worth_history"])
	
	loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _serialize_market() -> Dictionary:
	var result := {}
	for stock_id in MarketSim.stocks:
		var s: Dictionary = MarketSim.stocks[stock_id]
		var hist: Array = s["history"].duplicate()
		if hist.size() > 500:
			hist = hist.slice(hist.size() - 500)
		result[stock_id] = {
			"price": s["price"],
			"day_open": s["day_open"],
			"volatility": s["volatility"],
			"trend": s["trend"],
			"change_pct": s["change_pct"],
			"history": hist,
		}
	# _event_multipliers 직렬화
	result["_event_multipliers"] = MarketSim._event_multipliers.duplicate(true)
	# _daily_close + _daily_ohlc 직렬화 (500일 상한)
	var ohlc_trimmed: Dictionary = {}
	for sid in MarketSim._daily_ohlc:
		var arr: Array = MarketSim._daily_ohlc[sid].duplicate(true)
		if arr.size() > 500:
			arr = arr.slice(arr.size() - 500)
		ohlc_trimmed[sid] = arr
	result["_daily_close"] = MarketSim.serialize_daily_close()
	result["_daily_ohlc"] = ohlc_trimmed
	return result


func _deserialize_market(data: Dictionary) -> void:
	# daily_close_history 복원 (먼저 추출)
	if data.has("_daily_close"):
		MarketSim.deserialize_daily_close(data["_daily_close"])
	# _daily_ohlc 개별 복원 (500일 상한 적용)
	if data.has("_daily_ohlc"):
		for sid in data["_daily_ohlc"]:
			var arr: Array = data["_daily_ohlc"][sid]
			if arr.size() > 500:
				arr = arr.slice(arr.size() - 500)
			MarketSim._daily_ohlc[sid] = arr
	# _event_multipliers 복원
	if data.has("_event_multipliers"):
		MarketSim._event_multipliers = data["_event_multipliers"].duplicate(true)
	for stock_id in data:
		if stock_id == "_daily_close" or stock_id == "_daily_ohlc" or stock_id == "_event_multipliers":
			continue
		if MarketSim.stocks.has(stock_id):
			var saved: Dictionary = data[stock_id]
			MarketSim.stocks[stock_id]["price"] = saved["price"]
			MarketSim.stocks[stock_id]["day_open"] = saved["day_open"]
			if saved.has("volatility"):
				MarketSim.stocks[stock_id]["volatility"] = float(saved["volatility"])
			if saved.has("trend"):
				MarketSim.stocks[stock_id]["trend"] = float(saved["trend"])
			if saved.has("change_pct"):
				MarketSim.stocks[stock_id]["change_pct"] = float(saved["change_pct"])
			if saved.has("history"):
				var hist: Array = saved["history"]
				if hist.size() > 500:
					hist = hist.slice(hist.size() - 500)
				MarketSim.stocks[stock_id]["history"] = hist


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

	# 최대 24시간까지만 보상
	var capped: float = minf(elapsed, 24 * 3600)

	# 시간당 순자산의 0.3% 보상 (일일 캡 2%)
	var net_worth: float = GameManager.get_net_worth()
	var rate := 0.003 / 3600.0  # 초당
	var daily_cap: float = net_worth * 0.02  # 일일 최대 2%
	var reward: float = net_worth * rate * capped
	if reward > daily_cap:
		reward = daily_cap

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

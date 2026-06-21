extends Node
## QuestManager — 일일/주간/월간 퀘스트 + 업적 시스템
## 퀘스트는 주기별로 리셋, 업적은 영구 해금

signal quest_completed(quest_id: String, reward: Dictionary)
signal quest_progress_updated(quest_id: String, progress: int, target: int)
signal achievement_unlocked(achievement_id: String, name: String)
signal quest_reset(period: String)

# 퀘스트 정의
var _daily_defs: Array = []
var _weekly_defs: Array = []
var _monthly_defs: Array = []
var _achievement_defs: Array = []

# 진행도 추적 (quest_id -> {progress, claimed})
var _daily_progress: Dictionary = {}
var _weekly_progress: Dictionary = {}
var _monthly_progress: Dictionary = {}
var _achievements_unlocked: Dictionary = {}  # ach_id -> true

# 일별 추적
var _last_daily_reset_day: int = 0
var _last_weekly_reset_day: int = 0
var _last_monthly_reset_day: int = 0

# 누적 통계 (업적용)
var _total_trades: int = 0
var _total_dividends_earned: float = 0.0
var _max_unique_holdings: int = 0
var _rival_wins: int = 0
var _max_house_level: int = 0
var _max_vehicle_level: int = 0
var _autotrade_slots_used: int = 0

# 일일 추적
var _daily_trade_count: int = 0
var _daily_profit: float = 0.0
var _daily_news_checks: int = 0
var _daily_npc_interacts: int = 0
var _daily_dividends: float = 0.0
var _daily_rank_ups: int = 0

# 주간/월간 누적
var _weekly_trade_count: int = 0
var _weekly_profit: float = 0.0
var _weekly_dividends: float = 0.0
var _monthly_trade_count: int = 0
var _monthly_npc_interacts: int = 0
var _month_start_net_worth: float = 0.0

# 한 번에 보상 팝업용 큐
var _pending_rewards: Array = []


func _ready() -> void:
	_load_data()
	_month_start_net_worth = GameManager.get_net_worth()


func _load_data() -> void:
	var qdata = _load_json("res://data/quests.json")
	if qdata:
		_daily_defs = qdata.get("daily_quests", [])
		_weekly_defs = qdata.get("weekly_quests", [])
		_monthly_defs = qdata.get("monthly_quests", [])

	var adata = _load_json("res://data/achievements.json")
	if adata:
		_achievement_defs = adata.get("achievements", [])


# ═══════════════════════════════════════
# 하루 경과 시 호출 (GameManager.advance_day 연결)
# ═══════════════════════════════════════

func on_day_advanced() -> void:
	var day: int = GameManager.player.get("day", 0)

	# 일일 리셋 (매일)
	if day != _last_daily_reset_day:
		_reset_daily()
		_last_daily_reset_day = day

	# 주간 리셋 (7일마다)
	if day - _last_weekly_reset_day >= 7:
		_reset_weekly()
		_last_weekly_reset_day = day

	# 월간 리셋 (30일마다)
	if day - _last_monthly_reset_day >= 30:
		_reset_monthly()
		_last_monthly_reset_day = day

	# 업적 체크
	_check_all_achievements()
	# 퀘스트 완료 체크
	_check_quest_completion()


func _reset_daily() -> void:
	_daily_progress.clear()
	_daily_trade_count = 0
	_daily_profit = 0.0
	_daily_news_checks = 0
	_daily_npc_interacts = 0
	_daily_dividends = 0.0
	_daily_rank_ups = 0
	for q in _daily_defs:
		_daily_progress[q["id"]] = {"progress": 0, "claimed": false}
	quest_reset.emit("daily")


func _reset_weekly() -> void:
	_weekly_progress.clear()
	_weekly_trade_count = 0
	_weekly_profit = 0.0
	_weekly_dividends = 0.0
	for q in _weekly_defs:
		_weekly_progress[q["id"]] = {"progress": 0, "claimed": false}
	quest_reset.emit("weekly")


func _reset_monthly() -> void:
	_monthly_progress.clear()
	_monthly_trade_count = 0
	_monthly_npc_interacts = 0
	_month_start_net_worth = GameManager.get_net_worth()
	for q in _monthly_defs:
		_monthly_progress[q["id"]] = {"progress": 0, "claimed": false}
	quest_reset.emit("monthly")


# ═══════════════════════════════════════
# 이벤트 추적 (각 시스템에서 호출)
# ═══════════════════════════════════════

func on_trade_made(profit: float = 0.0) -> void:
	_total_trades += 1
	_daily_trade_count += 1
	_weekly_trade_count += 1
	_monthly_trade_count += 1
	if profit > 0:
		_daily_profit += profit
		_weekly_profit += profit
	_update_quest_progress("trade_count", _daily_trade_count, _weekly_trade_count, _monthly_trade_count)
	_update_quest_progress("daily_profit", _daily_profit, _weekly_profit, 0)
	_check_all_achievements()


func on_news_checked() -> void:
	_daily_news_checks += 1
	_update_quest_progress("news_check", _daily_news_checks, 0, 0)


func on_npc_interact() -> void:
	_daily_npc_interacts += 1
	_monthly_npc_interacts += 1
	_update_quest_progress("npc_interact", _daily_npc_interacts, 0, _monthly_npc_interacts)


func on_dividend_earned(amount: float) -> void:
	_total_dividends_earned += amount
	_daily_dividends += amount
	_weekly_dividends += amount
	_update_quest_progress("dividend_earned", _daily_dividends, _weekly_dividends, 0)
	_check_all_achievements()


func on_rank_up(new_rank_index: int) -> void:
	_daily_rank_ups += 1
	_update_quest_progress("rank_up", _daily_rank_ups, _daily_rank_ups, 0)


func on_rank_up_check() -> void:
	_daily_rank_ups += 1
	_update_quest_progress("rank_up", _daily_rank_ups, _daily_rank_ups, 0)


func on_house_bought(level: int) -> void:
	if level > _max_house_level:
		_max_house_level = level
	_update_quest_progress("house_level", _max_house_level, 0, 0)
	_check_all_achievements()


func on_vehicle_bought(level: int) -> void:
	if level > _max_vehicle_level:
		_max_vehicle_level = level
	_update_quest_progress("vehicle_level", _max_vehicle_level, 0, 0)
	_check_all_achievements()


func on_rival_win() -> void:
	_rival_wins += 1
	_check_all_achievements()


func on_autotrade_update(active_count: int) -> void:
	if active_count > _autotrade_slots_used:
		_autotrade_slots_used = active_count
	_check_all_achievements()


func on_net_worth_changed() -> void:
	# 보유 종목 수 업데이트
	var holdings_count = GameManager.player.get("holdings", {}).size()
	if holdings_count > _max_unique_holdings:
		_max_unique_holdings = holdings_count
	_check_all_achievements()


# ═══════════════════════════════════════
# 진행도 업데이트
# ═══════════════════════════════════════

func _update_quest_progress(type: String, daily_val: int, weekly_val: int, monthly_val: float) -> void:
	for q in _daily_defs:
		if q.get("type") == type:
			_set_progress(_daily_progress, q["id"], int(daily_val), int(q.get("target", 1)))
	for q in _weekly_defs:
		if q.get("type") == type:
			_set_progress(_weekly_progress, q["id"], int(weekly_val), int(q.get("target", 1)))
	for q in _monthly_defs:
		if q.get("type") == type:
			var val = monthly_val if type != "net_worth_growth" else _check_net_worth_growth()
			_set_progress(_monthly_progress, q["id"], int(val), int(q.get("target", 1)))


func _set_progress(store: Dictionary, quest_id: String, val: int, target: int) -> void:
	if not store.has(quest_id):
		store[quest_id] = {"progress": 0, "claimed": false}
	var entry = store[quest_id]
	if val > int(entry.get("progress", 0)):
		entry["progress"] = val
		store[quest_id] = entry
		quest_progress_updated.emit(quest_id, val, target)


func _check_net_worth_growth() -> int:
	if _month_start_net_worth <= 0:
		return 0
	var ratio = GameManager.get_net_worth() / _month_start_net_worth
	return int(ratio)


# ═══════════════════════════════════════
# 퀘스트 완료 체크 + 보상
# ═══════════════════════════════════════

func _check_quest_completion() -> void:
	# autotrade_active 특수 처리
	var active_at = AutoTradeManager.get_active_count()
	_update_quest_progress("autotrade_active", active_at, active_at, 0)

	# 완료 가능한 퀘스트 자동 클레임
	_auto_claim(_daily_defs, _daily_progress)
	_auto_claim(_weekly_defs, _weekly_progress)
	_auto_claim(_monthly_defs, _monthly_progress)


func _auto_claim(defs: Array, store: Dictionary) -> void:
	for q in defs:
		var qid = q["id"]
		if not store.has(qid):
			continue
		var entry = store[qid]
		if entry.get("claimed", false):
			continue
		if int(entry.get("progress", 0)) >= int(q.get("target", 1)):
			_grant_quest_reward(q)
			entry["claimed"] = true
			store[qid] = entry


func _grant_quest_reward(quest: Dictionary) -> void:
	var cash_reward: float = float(quest.get("reward_cash", 0))
	var energy_reward: int = int(quest.get("reward_energy", 0))

	if cash_reward > 0:
		GameManager.add_cash(cash_reward)
	if energy_reward > 0:
		GameManager.recover_energy(energy_reward)

	var reward := {"cash": cash_reward, "energy": energy_reward, "name": quest.get("name", "")}
	quest_completed.emit(quest["id"], reward)
	_pending_rewards.append({"type": "quest", "quest": quest, "reward": reward})


# ═══════════════════════════════════════
# 업적 체크
# ═══════════════════════════════════════

func _check_all_achievements() -> void:
	for ach in _achievement_defs:
		var aid = ach["id"]
		if _achievements_unlocked.has(aid):
			continue
		if _check_achievement_condition(ach):
			_unlock_achievement(ach)


func _check_achievement_condition(ach: Dictionary) -> bool:
	var type: String = ach.get("type", "")
	var target = ach.get("target", 0)
	match type:
		"total_trades":
			return _total_trades >= int(target)
		"net_worth":
			return GameManager.get_net_worth() >= float(target)
		"total_dividends":
			return _total_dividends_earned >= float(target)
		"house_level":
			return _max_house_level >= int(target)
		"vehicle_level":
			return _max_vehicle_level >= int(target)
		"married":
			return NPCManager.is_married()
		"rival_wins":
			return _rival_wins >= int(target)
		"generation":
			return GameManager.player.get("generation", 1) >= int(target)
		"unique_holdings":
			return _max_unique_holdings >= int(target)
		"autotrade_slots":
			return _autotrade_slots_used >= int(target)
		"bear_market_profit":
			# 약세장에서 수익 — 추후 구현
			return false
		_:
			return false


func _unlock_achievement(ach: Dictionary) -> void:
	_achievements_unlocked[ach["id"]] = true
	var cash_reward: float = float(ach.get("reward_cash", 0))
	if cash_reward > 0:
		GameManager.add_cash(cash_reward)
	achievement_unlocked.emit(ach["id"], ach.get("name", ""))
	_pending_rewards.append({"type": "achievement", "achievement": ach, "reward": {"cash": cash_reward}})


# ═══════════════════════════════════════
# 조회
# ═══════════════════════════════════════

func get_daily_quests() -> Array:
	return _format_quest_list(_daily_defs, _daily_progress)

func get_weekly_quests() -> Array:
	return _format_quest_list(_weekly_defs, _weekly_progress)

func get_monthly_quests() -> Array:
	return _format_quest_list(_monthly_defs, _monthly_progress)

func _format_quest_list(defs: Array, store: Dictionary) -> Array:
	var result: Array = []
	for q in defs:
		var qid = q["id"]
		var entry = store.get(qid, {"progress": 0, "claimed": false})
		result.append({
			"id": qid,
			"name": q.get("name", ""),
			"desc": q.get("desc", ""),
			"progress": int(entry.get("progress", 0)),
			"target": int(q.get("target", 1)),
			"claimed": entry.get("claimed", false),
			"reward_cash": q.get("reward_cash", 0),
			"reward_energy": q.get("reward_energy", 0)
		})
	return result

func get_achievements() -> Array:
	var result: Array = []
	for ach in _achievement_defs:
		result.append({
			"id": ach["id"],
			"name": ach.get("name", ""),
			"desc": ach.get("desc", ""),
			"category": ach.get("category", ""),
			"unlocked": _achievements_unlocked.has(ach["id"]),
			"reward_cash": ach.get("reward_cash", 0)
		})
	return result

func get_unlocked_achievement_count() -> int:
	return _achievements_unlocked.size()

func get_total_achievement_count() -> int:
	return _achievement_defs.size()

func get_pending_rewards() -> Array:
	return _pending_rewards

func clear_pending_rewards() -> void:
	_pending_rewards.clear()

func get_total_trades() -> int:
	return _total_trades


# ═══════════════════════════════════════
# 저장/로드
# ═══════════════════════════════════════

func serialize() -> Dictionary:
	return {
		"completed_daily": _daily_progress.duplicate(true),
		"completed_weekly": _weekly_progress.duplicate(true),
		"completed_monthly": _monthly_progress.duplicate(true),
		"achievements": _achievements_unlocked.duplicate(),
		"total_trades": _total_trades,
		"total_dividends": _total_dividends_earned,
		"max_holdings": _max_unique_holdings,
		"rival_wins": _rival_wins,
		"max_house": _max_house_level,
		"max_vehicle": _max_vehicle_level,
		"last_daily_reset": _last_daily_reset_day,
		"last_weekly_reset": _last_weekly_reset_day,
		"last_monthly_reset": _last_monthly_reset_day
	}

func deserialize(data: Dictionary) -> void:
	_daily_progress = data.get("completed_daily", {}).duplicate(true)
	_weekly_progress = data.get("completed_weekly", {}).duplicate(true)
	_monthly_progress = data.get("completed_monthly", {}).duplicate(true)
	_achievements_unlocked = data.get("achievements", {}).duplicate()
	_total_trades = int(data.get("total_trades", 0))
	_total_dividends_earned = float(data.get("total_dividends", 0))
	_max_unique_holdings = int(data.get("max_holdings", 0))
	_rival_wins = int(data.get("rival_wins", 0))
	_max_house_level = int(data.get("max_house", 0))
	_max_vehicle_level = int(data.get("max_vehicle", 0))
	_last_daily_reset_day = int(data.get("last_daily_reset", 0))
	_last_weekly_reset_day = int(data.get("last_weekly_reset", 0))
	_last_monthly_reset_day = int(data.get("last_monthly_reset", 0))


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

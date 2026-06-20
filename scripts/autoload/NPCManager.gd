extends Node
## NPCManager — NPC 데이터, 호감도, 결혼, 정보거래, 라이벌 대결

signal affinity_changed(npc_id: String, affinity: int)
signal married(npc_id: String)
signal rival_defeated(npc_id: String)

var _data: Dictionary = {}
var _affinity: Dictionary = {}  # npc_id -> int

# 결혼으로 얻은 버프
var _marriage_buffs: Dictionary = {}  # buff_type -> value

# 라이벌 전적
var _rival_record: Dictionary = {}  # npc_id -> {wins, losses}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_data()
	_rng.seed = Time.get_ticks_msec() + 1


func _load_data() -> void:
	_data = _load_json("res://data/npcs.json")
	if _data == null:
		push_error("NPCManager: npcs.json 로드 실패")
		_data = {"rivals": [], "helpers": [], "marriage_targets": []}

	_init_affinity()


func _init_affinity() -> void:
	_affinity.clear()
	for category in ["rivals", "helpers", "marriage_targets"]:
		for npc in _data.get(category, []):
			_affinity[npc["id"]] = int(npc.get("initial_affinity", 0))


# ─── 조회 ──────────────────────────────────────

func get_npcs_by_category(category: String) -> Array:
	return _data.get(category, [])


func get_all_npcs() -> Array:
	var all: Array = []
	all.append_array(get_npcs_by_category("rivals"))
	all.append_array(get_npcs_by_category("helpers"))
	all.append_array(get_npcs_by_category("marriage_targets"))
	return all


func get_npc(npc_id: String) -> Dictionary:
	for npc in get_all_npcs():
		if npc["id"] == npc_id:
			return npc
	return {}


func get_affinity(npc_id: String) -> int:
	return _affinity.get(npc_id, 0)


func get_affinity_level(npc_id: String) -> String:
	var aff := get_affinity(npc_id)
	if aff >= 80: return "친밀"
	if aff >= 50: return "호감"
	if aff >= 20: return "보통"
	if aff >= 0: return "어색"
	return "적대"


# ─── 호감도 변동 ────────────────────────────────

func add_affinity(npc_id: String, amount: int) -> void:
	var old := get_affinity(npc_id)
	_affinity[npc_id] = clampi(old + amount, -100, 100)
	affinity_changed.emit(npc_id, _affinity[npc_id])


# ─── 결혼 ──────────────────────────────────────

func is_married() -> bool:
	return GameManager.player.get("married", null) != null


func get_spouse_id() -> String:
	return GameManager.player.get("married", "")


func can_marry(npc_id: String) -> Dictionary:
	if is_married():
		return {"success": false, "reason": "이미 결혼했습니다"}

	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	if npc.get("role", "").find("세무") < 0 and npc.get("role", "").find("변호사") < 0 and npc.get("role", "").find("기자") < 0 and npc.get("role", "").find("퀀트") < 0 and npc.get("role", "").find("의사") < 0:
		return {"success": false, "reason": "결혼 대상이 아닙니다"}

	var required: int = int(npc.get("required_affinity", 80))
	if get_affinity(npc_id) < required:
		return {"success": false, "reason": "호감도 부족 (%d/%d)" % [get_affinity(npc_id), required]}

	var cost: float = float(npc.get("gift_cost", 0))
	if GameManager.get_cash() < cost:
		return {"success": false, "reason": "프로포즈 비용 부족 (%.0f원)" % cost}

	return {"success": true, "cost": cost}


func marry(npc_id: String) -> Dictionary:
	var check := can_marry(npc_id)
	if not check.get("success"):
		return check

	var npc := get_npc(npc_id)
	var cost: float = float(check.get("cost", 0))

	GameManager.player["cash"] -= cost
	GameManager.player["married"] = npc_id

	# 버프 적용
	_marriage_buffs.clear()
	var buff_type: String = npc.get("buff_type", "")
	var buff_val: float = float(npc.get("buff_value", 0))
	if buff_type != "":
		_marriage_buffs[buff_type] = buff_val

	GameManager.cash_changed.emit(GameManager.player["cash"])
	married.emit(npc_id)
	return {"success": true, "npc": npc}


func get_marriage_buff(buff_type: String) -> float:
	return _marriage_buffs.get(buff_type, 0.0)


func has_marriage_buff(buff_type: String) -> bool:
	return _marriage_buffs.has(buff_type)


func get_spouse() -> Dictionary:
	var sid := get_spouse_id()
	if sid == "":
		return {}
	return get_npc(sid)


# ─── 선물 (호감도 올리기) ──────────────────────

func give_gift(npc_id: String, amount: float) -> Dictionary:
	if GameManager.get_cash() < amount:
		return {"success": false, "reason": "잔액 부족"}

	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	GameManager.add_cash(-amount)

	# 호감도 증가: 금액에 비례 (100만원당 +1, 최대 +10)
	var gain := clampi(int(amount / 1000000), 1, 10)
	add_affinity(npc_id, gain)

	return {"success": true, "gain": gain, "affinity": get_affinity(npc_id)}


# ─── 도움 NPC 서비스 ───────────────────────────

func use_helper_service(npc_id: String) -> Dictionary:
	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	if not npc_id in ["kim_info", "ajumma_broker", "taxi_driver"]:
		return {"success": false, "reason": "서비스 불가능한 NPC"}

	var cost: float = float(npc.get("service_cost", 0))
	if GameManager.get_cash() < cost:
		return {"success": false, "reason": "잔액 부족 (%.0f원)" % cost}

	GameManager.add_cash(-cost)
	add_affinity(npc_id, 2)

	# 서비스 효과
	match npc_id:
		"kim_info":
			# 다음 뉴스 이벤트를 미리 알려줌
			return {"success": true, "type": "early_news", "desc": "김정보가 다가올 시장 움직임을 귀띔해줬다."}
		"ajumma_broker":
			# 호감도 50 이상이면 수수료 할인 (임시)
			if get_affinity(npc_id) >= 50:
				return {"success": true, "type": "fee_discount", "desc": "수수료 20% 할인 적용!", "duration": 7}
			return {"success": true, "type": "info", "desc": "호감도가 더 필요하다 (50 이상)."}

		"taxi_driver":
			# 무작위 팁
			var tips := [
				"요즘 삼전전자 좋다더라.",
				"코인 조심해라, 거품이야.",
				"비트코인 다시 오를 것 같아.",
				"아마존 실적 좋다던데.",
				"AI 주식 아직 멀었어.",
			]
			var tip: String = tips[_rng.randi() % tips.size()]
			return {"success": true, "type": "tip", "desc": tip}

	return {"success": false, "reason": "알 수 없는 서비스"}


# ─── 라이벌 대결 ───────────────────────────────

func challenge_rival(npc_id: String) -> Dictionary:
	var npc := get_npc(npc_id)
	if npc.is_empty() or not npc_id in ["goldberg", "queen_realtime", "algo_k"]:
		return {"success": false, "reason": "라이벌이 아닙니다"}

	# 현재 순자산 기준 승패 판정 (간소화)
	var my_net := GameManager.get_net_worth()
	var rival_power := _calc_rival_power(npc_id)

	var won: bool = my_net >= rival_power
	var record: Dictionary = _rival_record.get(npc_id, {"wins": 0, "losses": 0})
	if won:
		record["wins"] = record.get("wins", 0) + 1
		add_affinity(npc_id, 5)
		# 보상: 순자산의 5%
		var reward := my_net * 0.05
		GameManager.add_cash(reward)
		rival_defeated.emit(npc_id)
		_rival_record[npc_id] = record
		return {"success": true, "won": true, "reward": reward}
	else:
		record["losses"] = record.get("losses", 0) + 1
		add_affinity(npc_id, -3)
		var penalty := my_net * 0.03
		GameManager.add_cash(-penalty)
		_rival_record[npc_id] = record
		return {"success": true, "won": false, "penalty": penalty}


func _calc_rival_power(npc_id: String) -> float:
	var my_day: int = GameManager.player["day"]
	var base: float = 10_000_000.0 * (1.0 + my_day * 0.15)
	match npc_id:
		"goldberg":
			return base * 1.2
		"queen_realtime":
			return base * 1.0
		"algo_k":
			return base * 1.1
	return base


func get_rival_record(npc_id: String) -> Dictionary:
	return _rival_record.get(npc_id, {"wins": 0, "losses": 0})


# ─── 세대교체 ──────────────────────────────────

func start_new_generation() -> Dictionary:
	if not is_married():
		return {"success": false, "reason": "결혼을 먼저 해야 세대교체 가능"}

	var old_net := GameManager.get_net_worth()
	var old_stats: Dictionary = GameManager.player["stats"].duplicate()
	var old_generation: int = GameManager.player["generation"]

	# 자산 50% 상속
	var inherited_cash := old_net * 0.5

	# 플레이어 리셋
	GameManager.reset_player()
	GameManager.player["generation"] = old_generation + 1
	GameManager.player["cash"] = inherited_cash

	# 스탯 30% 상속
	for key in old_stats:
		GameManager.player["stats"][key] = int(old_stats[key] * 0.3) + 5  # 기본 5

	# 결혼 상태 초기화
	_marriage_buffs.clear()

	# 호감도 일부 유지 (결혼 배우자만)
	var spouse := get_spouse_id()
	for npc_id in _affinity:
		if npc_id == spouse:
			_affinity[npc_id] = int(_affinity[npc_id] * 0.5)
		else:
			_affinity[npc_id] = int(_affinity[npc_id] * 0.2)

	# 라이벌 전적 초기화
	_rival_record.clear()

	# 이벤트 기록 초기화
	EventManager._active_events.clear()

	GameManager.cash_changed.emit(GameManager.get_cash())
	GameManager.net_worth_changed.emit(GameManager.get_net_worth())

	return {
		"success": true,
		"new_generation": GameManager.player["generation"],
		"inherited_cash": inherited_cash,
	}


func get_marriage_buffs() -> Dictionary:
	return _marriage_buffs


# ─── 저장/로드 ──────────────────────────────────

func serialize() -> Dictionary:
	return {
		"affinity": _affinity,
		"marriage_buffs": _marriage_buffs,
		"rival_record": _rival_record,
	}


func deserialize(data: Dictionary) -> void:
	_affinity = data.get("affinity", _affinity)
	_marriage_buffs = data.get("marriage_buffs", {})
	_rival_record = data.get("rival_record", {})


# ─── 내부 ──────────────────────────────────────

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

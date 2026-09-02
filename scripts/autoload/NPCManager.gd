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

# 데이트 쿨다운 (npc_id -> 마지막 데이트한 날)
var _date_cooldown: Dictionary = {}  # npc_id -> int (day)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_data()
	_rng.seed = Time.get_ticks_msec() + 1


func _load_data() -> void:
	_data = DataUtil.load_json("res://data/npcs.json")
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
	var val: Variant = GameManager.player.get("married", null)
	if val == null or val is String and val == "":
		return ""
	return str(val)


func can_marry(npc_id: String) -> Dictionary:
	if is_married():
		return {"success": false, "reason": "이미 결혼했습니다"}

	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	# 카테고리 체크 (marriage_targets에 있는지)
	if not _is_marriage_target(npc_id):
		return {"success": false, "reason": "결혼 대상이 아닙니다"}

	var required: int = int(npc.get("required_affinity", 100))
	if get_affinity(npc_id) < required:
		return {"success": false, "reason": "호감도 부족 (%d/%d)" % [get_affinity(npc_id), required]}

	var cost: float = float(npc.get("gift_cost", 0))
	if GameManager.get_cash() < cost:
		return {"success": false, "reason": "프로포즈 비용 부족 (%.0f원)" % cost}

	return {"success": true, "cost": cost}


func _is_marriage_target(npc_id: String) -> bool:
	for npc in _data.get("marriage_targets", []):
		if npc.get("id", "") == npc_id:
			return true
	return false


func marry(npc_id: String) -> Dictionary:
	var check := can_marry(npc_id)
	if not check.get("success"):
		return check

	var npc := get_npc(npc_id)
	var cost: float = float(check.get("cost", 0))

	GameManager.player["cash"] -= cost
	GameManager.player["married"] = npc_id
	GameManager.player["married_day"] = GameManager.player["day"]

	# 버프 + 디버프 적용
	_marriage_buffs.clear()
	var buff_type: String = npc.get("buff_type", "")
	var buff_val: float = float(npc.get("buff_value", 0))
	if buff_type != "":
		_marriage_buffs[buff_type] = buff_val
	var debuff_type: String = npc.get("debuff_type", "")
	var debuff_val: float = float(npc.get("debuff_value", 0))
	if debuff_type != "":
		_marriage_buffs[debuff_type] = debuff_val

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
	# 차량 등급에 따른 선물 비용 절감
	var discount := _get_date_discount()
	var actual_amount: float = amount * (1.0 - discount)

	if GameManager.get_cash() < actual_amount:
		return {"success": false, "reason": "잔액 부족"}

	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	GameManager.add_cash(-actual_amount)

	# 호감도 증가: 금액에 비례 (100만원당 +1, 최대 +10)
	var gain := clampi(int(amount / 1000000), 1, 10)
	add_affinity(npc_id, gain)

	return {"success": true, "gain": gain, "affinity": get_affinity(npc_id), "cost": actual_amount}


## 현재 차량의 데이트/선물 비용 절감율 반환 (0.0 ~ 0.8)
func _get_date_discount() -> float:
	var vehicle := GameManager.get_current_vehicle()
	if vehicle.is_empty():
		return 0.0
	return float(vehicle.get("date_cost_discount", 0.0))


# ─── 도움 NPC 서비스 ───────────────────────────

func use_helper_service(npc_id: String) -> Dictionary:
	var npc := get_npc(npc_id)
	if npc.is_empty():
		return {"success": false, "reason": "존재하지 않는 NPC"}

	# helpers 카테고리에 있는지 확인
	if not _is_helper(npc_id):
		return {"success": false, "reason": "서비스 불가능한 NPC"}

	var cost: float = float(npc.get("service_cost", 0))
	if GameManager.get_cash() < cost:
		return {"success": false, "reason": "잔액 부족 (%.0f원)" % cost}

	GameManager.add_cash(-cost)
	add_affinity(npc_id, 2)

	# service_type 기반 동적 처리
	var svc_type: String = npc.get("service_type", "")
	match svc_type:
		"early_news":
			return {"success": true, "type": "early_news", "desc": "김정보가 다가올 시장 움직임을 귀띔해줬다."}
		"fee_discount":
			if get_affinity(npc_id) >= 50:
				return {"success": true, "type": "fee_discount", "desc": "수수료 20% 할인 적용! (7일)", "duration": 7}
			return {"success": true, "type": "info", "desc": "호감도가 더 필요하다 (50 이상)."}
		"random_tip":
			var tips := [
				"요즘 삼성전자 좋다더라.",
				"코인 조심해라, 거품이야.",
				"비트코인 다시 오를 것 같아.",
				"아마존 실적 좋다던데.",
				"AI 주식 아직 멀었어.",
			]
			var tip: String = tips[_rng.randi() % tips.size()]
			return {"success": true, "type": "tip", "desc": tip}
		"legal_immunity":
			if get_affinity(npc_id) >= 60:
				return {"success": true, "type": "legal_immunity", "desc": "도윤재가 내부자거래 면책권을 보장했다! (1회)"}
			return {"success": true, "type": "info", "desc": "호감도가 더 필요하다 (60 이상)."}
		"autotrade_boost":
			if get_affinity(npc_id) >= 60:
				return {"success": true, "type": "autotrade_boost", "desc": "강시우가 자동매매 알고리즘을 최적화했다! 수익 +10% (7일)", "duration": 7}
			return {"success": true, "type": "info", "desc": "호감도가 더 필요하다 (60 이상)."}

	return {"success": false, "reason": "알 수 없는 서비스"}


func _is_helper(npc_id: String) -> bool:
	for npc in _data.get("helpers", []):
		if npc.get("id", "") == npc_id:
			return true
	return false


# ─── 라이벌 미니게임 ───────────────────────────

# 라이벌별 일일 참여 횟수
var _rival_daily_plays: Dictionary = {}  # npc_id -> plays today
const RIVAL_MAX_PLAYS_PER_DAY := 1
# 베팅 상한: 현재 현금의 최대 10%
const RIVAL_MAX_BET_RATIO := 0.10

## 라이벌 미니게임 — 베팅 금액 입력, 게임별 로직으로 승패 판정
func play_rival_game(npc_id: String, bet_amount: float) -> Dictionary:
	var npc := get_npc(npc_id)
	if npc.is_empty() or not _is_rival(npc_id):
		return {"success": false, "reason": "라이벌이 아닙니다"}

	# 일일 횟수 확인
	var today: int = GameManager.player.get("day", 1)
	var last_day: int = _rival_daily_plays.get(npc_id + "_day", 0)
	if today != last_day:
		_rival_daily_plays[npc_id] = 0
		_rival_daily_plays[npc_id + "_day"] = today
	var plays: int = _rival_daily_plays.get(npc_id, 0)
	if plays >= RIVAL_MAX_PLAYS_PER_DAY:
		return {"success": false, "reason": "오늘 참여 횟수 초과 (%d/%d)" % [plays, RIVAL_MAX_PLAYS_PER_DAY]}

	# 베팅 금액 검증
	var cash: float = GameManager.get_cash()
	if bet_amount <= 0:
		return {"success": false, "reason": "베팅 금액 오류"}
	var max_bet: float = cash * RIVAL_MAX_BET_RATIO
	if bet_amount > max_bet:
		return {"success": false, "reason": "베팅 상한 초과 (최대 %s)" % _fmt_simple(max_bet)}
	if cash < bet_amount:
		return {"success": false, "reason": "잔액 부족"}

	# 베팅금 차감
	GameManager.add_cash(-bet_amount)
	_rival_daily_plays[npc_id] = plays + 1

	# 라이벌별 미니게임 실행
	var game_type: String = npc.get("game_type", "dice")
	var result: Dictionary
	match game_type:
		"blackjack":
			result = _play_blackjack(bet_amount)
		"ladder":
			result = _play_ladder(bet_amount)
		_:  # dice
			result = _play_dice(bet_amount)

	# 전적 기록
	var record: Dictionary = _rival_record.get(npc_id, {"wins": 0, "losses": 0})
	if result.get("won", false):
		record["wins"] = record.get("wins", 0) + 1
		add_affinity(npc_id, 3)
	else:
		record["losses"] = record.get("losses", 0) + 1
	_rival_record[npc_id] = record

	return result


## 블랙잭 — 유저 초기 2장 드로우
## 반환: { cards: [{card, val}, ...], total: int }
func bj_deal_user_cards() -> Dictionary:
	var cards: Array = []
	var total: int = 0
	for _i in 2:
		var card: int = _rng.randi_range(1, 13)
		var val: int = min(card, 10)
		cards.append({"card": card, "val": val})
		total += val
	return {"cards": cards, "total": total}

## 블랙잭 — 유저 Hit (1장 추가)
## 반환: { card: int, val: int, total: int, busted: bool }
func bj_user_hit(current_total: int) -> Dictionary:
	var card: int = _rng.randi_range(1, 13)
	var val: int = min(card, 10)
	var new_total: int = current_total + val
	return {"card": card, "val": val, "total": new_total, "busted": new_total > 21}

## 블랙잭 — 딜러 자동 플레이 (16 이하면 Hit)
## 반환: { cards: [{card, val}, ...], total: int, busted: bool }
func bj_play_dealer() -> Dictionary:
	var cards: Array = []
	var total: int = 0
	for _i in 2:
		var card: int = _rng.randi_range(1, 13)
		var val: int = min(card, 10)
		cards.append({"card": card, "val": val})
		total += val
	while total <= 16:
		var card: int = _rng.randi_range(1, 13)
		var val: int = min(card, 10)
		cards.append({"card": card, "val": val})
		total += val
	return {"cards": cards, "total": total, "busted": total > 21}

## 블랙잭 — 결과 정산 (유저 busted면 딜러 카드 무관)
## 반환: { won: bool, tie: bool, payout: float }
func bj_settle(user_total: int, dealer_total: int, bet: float) -> Dictionary:
	var user_busted: bool = user_total > 21
	var dealer_busted: bool = dealer_total > 21
	if user_busted and not dealer_busted:
		return {"won": false, "tie": false, "payout": 0.0}
	if dealer_busted and not user_busted:
		var payout: float = bet * 1.5
		GameManager.add_cash(payout)
		return {"won": true, "tie": false, "payout": payout}
	if user_busted and dealer_busted:
		GameManager.add_cash(bet)
		return {"won": false, "tie": true, "payout": bet}
	if user_total > dealer_total:
		var mult: float = 2.0 if user_total == 21 else 1.5
		var payout: float = bet * mult
		GameManager.add_cash(payout)
		return {"won": true, "tie": false, "payout": payout}
	elif user_total == dealer_total:
		GameManager.add_cash(bet)
		return {"won": false, "tie": true, "payout": bet}
	else:
		return {"won": false, "tie": false, "payout": 0.0}

## 블랙잭 자동 플레이 (play_rival_game 경로 전용)
## 유저/딜러 모두 자동으로 16 이하 Hit, 결과 정산까지 수행
func _play_blackjack(bet: float) -> Dictionary:
	var user := bj_deal_user_cards()
	var dealer := bj_play_dealer()
	var settle := bj_settle(int(user.get("total", 0)), int(dealer.get("total", 0)), bet)
	return {
		"success": true,
		"hand_user": user,
		"hand_dealer": dealer,
		"won": settle.get("won", false),
		"tie": settle.get("tie", false),
		"payout": float(settle.get("payout", 0.0)),
	}

## 사다리타기 미니게임 (실시간 퀸)
## 4개 선택지 중 하나 선택, 당첨 시 3배, 50% 확률
func _play_ladder(bet: float) -> Dictionary:
	# 4개 중 당첨 확률 40% (기대값 = 0.4 * 3배 = 1.2 - 1.0 = 0.2... 너무 높음)
	# 기대값 < 100% 맞추기: 당첨 확률 30%, 배당 3배 → 0.3*3 = 0.9 < 1.0
	var win_chance: float = 0.33
	var won: bool = _rng.randf() < win_chance
	var choice: int = _rng.randi_range(1, 4)
	var answer: int = _rng.randi_range(1, 4)
	if won:
		var payout: float = bet * 3.0
		GameManager.add_cash(payout)
		return {"success": true, "won": true, "game": "ladder",
				"choice": choice, "answer": answer, "payout": payout,
				"desc": "당첨! 선택 %d — +%s" % [choice, _fmt_simple(payout - bet)]}
	else:
		return {"success": true, "won": false, "game": "ladder",
				"choice": choice, "answer": answer, "payout": 0,
				"desc": "꽝... 선택 %d — -%s" % [choice, _fmt_simple(bet)]}


## 주사위 굴리기 미니게임 (알고리즘 K)
## 주사위 2개 굴림 (프론트엔드 UI 전용)
func dice_roll() -> Dictionary:
	var d1: int = _rng.randi_range(1, 6)
	var d2: int = _rng.randi_range(1, 6)
	return {"d1": d1, "d2": d2, "total": d1 + d2}

## 주사위 결과 정산 (프론트엔드 UI 전용)
func dice_settle(user_total: int, rival_total: int, bet: float) -> Dictionary:
	if user_total > rival_total:
		var payout: float = bet * 1.8
		GameManager.add_cash(payout)
		return {"won": true, "payout": payout}
	else:
		return {"won": false, "payout": 0.0}

## 주사위 자동 플레이 (play_rival_game 경로 전용)
## 주사위 2개 합계, 동점 시 최대 3회 재굴림
func _play_dice(bet: float) -> Dictionary:
	var user_result: Dictionary = dice_roll()
	var rival_result: Dictionary = dice_roll()
	var rerolls: int = 0
	while user_result.get("total", 0) == rival_result.get("total", 0) and rerolls < 3:
		user_result = dice_roll()
		rival_result = dice_roll()
		rerolls += 1
	var my_roll: int = int(user_result.get("total", 0))
	var rival_roll: int = int(rival_result.get("total", 0))
	var settled: Dictionary = dice_settle(my_roll, rival_roll, bet)
	if my_roll > rival_roll:
		return {"success": true, "won": true, "game": "dice",
				"user": my_roll, "rival": rival_roll, "payout": float(settled.get("payout", 0.0)),
				"desc": "승리! %d vs %d — +%s" % [my_roll, rival_roll, _fmt_simple(float(settled.get("payout", 0.0)) - bet)]}
	return {"success": true, "won": false, "game": "dice",
			"user": my_roll, "rival": rival_roll, "payout": 0,
			"desc": "패배... %d vs %d — -%s" % [my_roll, rival_roll, _fmt_simple(bet)]}


func _fmt_simple(v: float) -> String:
	var ab := absf(v)
	if ab >= 100_000_000:
		return "%.1f억" % (v / 100_000_000)
	elif ab >= 10_000:
		return "%.0f만" % (v / 10_000)
	return "%.0f원" % v


func get_rival_plays_today(npc_id: String) -> int:
	var today: int = GameManager.player.get("day", 1)
	var last_day: int = _rival_daily_plays.get(npc_id + "_day", 0)
	if today != last_day:
		return 0
	return _rival_daily_plays.get(npc_id, 0)


## 사다리타기 등 프론트엔드 미니게임 결과 기록용
func record_rival_game_result(npc_id: String, won: bool) -> void:
	var today: int = GameManager.player.get("day", 1)
	var last_day: int = _rival_daily_plays.get(npc_id + "_day", 0)
	if today != last_day:
		_rival_daily_plays[npc_id] = 0
		_rival_daily_plays[npc_id + "_day"] = today
	var plays: int = _rival_daily_plays.get(npc_id, 0)
	_rival_daily_plays[npc_id] = plays + 1

	var record: Dictionary = _rival_record.get(npc_id, {"wins": 0, "losses": 0})
	if won:
		record["wins"] = record.get("wins", 0) + 1
		add_affinity(npc_id, 3)
	else:
		record["losses"] = record.get("losses", 0) + 1
	_rival_record[npc_id] = record


func _calc_rival_power(npc_id: String) -> float:
	var my_day: int = GameManager.player["day"]
	var base: float = 10_000_000.0 * (1.0 + my_day * 0.15)
	# 라이벌 난이도를 데이터에서 읽거나 기본값 사용
	var npc := get_npc(npc_id)
	var difficulty: float = float(npc.get("difficulty", 1.0))
	return base * difficulty


func _is_rival(npc_id: String) -> bool:
	for npc in _data.get("rivals", []):
		if npc.get("id", "") == npc_id:
			return true
	return false


# ─── 데이트 시스템 ──────────────────────────────

func can_date(npc_id: String) -> Dictionary:
	if not _is_marriage_target(npc_id):
		return {"success": false, "reason": "데이트 불가능한 NPC"}
	if is_married():
		return {"success": false, "reason": "이미 결혼했습니다"}

	var npc := get_npc(npc_id)
	var date_cost: float = float(npc.get("date_cost", 5000000))
	var discount_d := _get_date_discount()
	date_cost = date_cost * (1.0 - discount_d)
	if GameManager.get_cash() < date_cost:
		return {"success": false, "reason": "데이트 비용 부족 (%.0f원)" % date_cost}

	# 쿨다운 체크 (1일 1회)
	var today: int = GameManager.player.get("day", 1)
	var last_date: int = _date_cooldown.get(npc_id, 0)
	if today == last_date:
		return {"success": false, "reason": "오늘 이미 데이트했다 (내일 가능)"}

	return {"success": true, "cost": date_cost}


func go_on_date(npc_id: String, activity: String) -> Dictionary:
	var check := can_date(npc_id)
	if not check.get("success"):
		return check

	var npc := get_npc(npc_id)
	var today: int = GameManager.player.get("day", 1)

	# 활동별 비용과 호감도 효과
	var base_cost: float = float(npc.get("date_cost", 5000000))
	# 차량 등급에 따른 데이트 비용 절감
	var discount := _get_date_discount()
	base_cost = base_cost * (1.0 - discount)
	var affinity_gain: int = 3
	var actual_cost: float = base_cost
	var desc_msg: String = ""

	match activity:
		"cafe":
			actual_cost = base_cost * 0.5
			affinity_gain = 3
			desc_msg = "분위기 좋은 카페에서 커피를 마셨다."
		"restaurant":
			actual_cost = base_cost
			affinity_gain = 6
			desc_msg = "고급 레스토랑에서 저녁 식사를 했다."
		"luxury":
			actual_cost = base_cost * 2.0
			affinity_gain = 12
			desc_msg = "화려한 럭셔리 데이트! 최고의 서비스를 즐겼다."

	if GameManager.get_cash() < actual_cost:
		return {"success": false, "reason": "잔액 부족 (%.0f원)" % actual_cost}

	GameManager.add_cash(-actual_cost)

	# 대화 성공 랜덤 보너스 (50% 확률로 +50% 호감도)
	var luck: float = _rng.randf()
	var bonus: int = 0
	if luck > 0.5:
		bonus = affinity_gain / 2
		desc_msg += " 대화가 매우 잘 통했다! (+보너스)"
	elif luck < 0.2:
		bonus = -1
		desc_msg += " 약간 어색한 분위기였다..."

	affinity_gain += bonus
	add_affinity(npc_id, affinity_gain)
	_date_cooldown[npc_id] = today

	return {
		"success": true,
		"gain": affinity_gain,
		"affinity": get_affinity(npc_id),
		"cost": actual_cost,
		"desc": desc_msg,
	}


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

	# 사업 초기화
	BusinessManager.reset_owned()
	# 퀘스트 초기화
	QuestManager.reset_all()
	# 패시브 수익 누적 통계 초기화
	PassiveIncomeManager.reset_accumulated()
	# 자동매매 슬롯 초기화
	AutoTradeManager.reset_slots()

	# 호감도 일부 유지 (결혼 배우자만)
	var spouse := get_spouse_id()
	for npc_id in _affinity:
		if npc_id == spouse:
			_affinity[npc_id] = int(_affinity[npc_id] * 0.5)
		else:
			_affinity[npc_id] = int(_affinity[npc_id] * 0.2)

	# 라이벌 전적 초기화
	_rival_record.clear()

	# 데이트 쿨다운 초기화
	_date_cooldown.clear()

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
		"rival_daily_plays": _rival_daily_plays,
		"date_cooldown": _date_cooldown,
	}


func deserialize(data: Dictionary) -> void:
	_affinity = data.get("affinity", {})
	_marriage_buffs = data.get("marriage_buffs", {})
	_rival_record = data.get("rival_record", {})
	_rival_daily_plays = data.get("rival_daily_plays", {})
	_date_cooldown = data.get("date_cooldown", {})



extends Node
## BusinessManager — 사업 운영 시스템
## 18종 사업 (요식/IT/소매/부동산) 구매/업그레이드/직원/이벤트
## 방치형 핵심: 매 틱 자동 수익 + 매일 정산

signal business_purchased(business_id: String)
signal business_upgraded(business_id: String, new_level: int)
signal employee_hired(business_id: String, count: int)
signal business_event(business_id: String, event_data: Dictionary)

var _defs: Array = []
var _config: Dictionary = {}
var _events: Array = []

# 보유 사업: business_id -> {level, employees, event_multiplier, event_days_left}
var _owned: Dictionary = {}

# 누적 수익
var _total_revenue: float = 0.0
var _last_tick_revenue: float = 0.0

# 일일 캡
var _daily_cap_pct: float = 0.15  # 순자산 대비 일일 사업 수익 한계


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	var data = _load_json("res://data/businesses.json")
	if data:
		_config = data.get("config", {})
		_defs = data.get("businesses", [])
		_events = data.get("events", [])


# ═══════════════════════════════════════
# 구매
# ═══════════════════════════════════════

func purchase(business_id: String) -> Dictionary:
	var def = _get_def(business_id)
	if def.is_empty():
		return _fail("존재하지 않는 사업")

	if _owned.has(business_id):
		return _fail("이미 보유 중")

	# 카테고리별 보유 제한
	var max_per_cat: int = int(_config.get("max_businesses_per_category", 2))
	var cat_count = _count_category(def.get("category", ""))
	if cat_count >= max_per_cat:
		return _fail("카테고리 한도 초과 (%d개까지)" % max_per_cat)

	var price: float = float(def.get("purchase_price", 0))
	if not GameManager.can_afford(price):
		return _fail("잔액 부족")

	GameManager.add_cash(-price)
	_owned[business_id] = {
		"level": 1,
		"employees": 0,
		"event_multiplier": 1.0,
		"event_days_left": 0
	}
	business_purchased.emit(business_id)
	return {"success": true, "business": def}


# ═══════════════════════════════════════
# 업그레이드
# ═══════════════════════════════════════

func upgrade(business_id: String) -> Dictionary:
	if not _owned.has(business_id):
		return _fail("보유하지 않은 사업")

	var def = _get_def(business_id)
	var entry = _owned[business_id]
	var max_level: int = int(_config.get("max_level", 10))

	if entry["level"] >= max_level:
		return _fail("최대 레벨 달성")

	# 업그레이드 비용 = 매입가 * 0.3 * 현재레벨
	var base_price: float = float(def.get("purchase_price", 0))
	var cost_mult: float = float(_config.get("base_upgrade_cost_multiplier", 0.3))
	var upgrade_cost: float = base_price * cost_mult * entry["level"]

	if not GameManager.can_afford(upgrade_cost):
		return _fail("잔액 부족 (필요: %s원)" % _fmt(upgrade_cost))

	GameManager.add_cash(-upgrade_cost)
	entry["level"] += 1
	_owned[business_id] = entry
	business_upgraded.emit(business_id, entry["level"])
	return {"success": true, "new_level": entry["level"], "cost": upgrade_cost}


# ═══════════════════════════════════════
# 직원 고용
# ═══════════════════════════════════════

func hire_employee(business_id: String) -> Dictionary:
	if not _owned.has(business_id):
		return _fail("보유하지 않은 사업")

	var entry = _owned[business_id]
	var max_emp: int = int(_config.get("max_employees", 5))

	if entry["employees"] >= max_emp:
		return _fail("최대 직원 수 달성")

	# 정보력 소모
	var energy_cost: int = int(_config.get("employee_hire_energy_cost", 3))
	if not GameManager.spend_energy(energy_cost):
		return _fail("정보력 부족")

	entry["employees"] += 1
	_owned[business_id] = entry
	employee_hired.emit(business_id, entry["employees"])
	return {"success": true, "employees": entry["employees"]}


# ═══════════════════════════════════════
# 수익 계산
# ═══════════════════════════════════════

## 틱당 사업 수익 (PassiveIncomeManager에서 호출)
func calc_tick_revenue() -> float:
	var game_accel: float = float(_config.get("game_accel", 10.0))
	var total: float = 0.0

	for bid in _owned:
		var revenue = _calc_business_daily_revenue(bid)
		total += revenue

	# 틱으로 분할
	total = total / game_accel

	# 일일 캡 적용
	total = _apply_cap(total)
	return total


func _calc_business_daily_revenue(business_id: String) -> float:
	var def = _get_def(business_id)
	if def.is_empty():
		return 0.0
	var entry = _owned.get(business_id, {})
	if entry.is_empty():
		return 0.0

	var base: float = float(def.get("base_revenue_per_day", 0))

	# 레벨 보너스
	var level_bonus: float = float(_config.get("upgrade_revenue_bonus_per_level", 0.2))
	var level_mult: float = 1.0 + level_bonus * (int(entry.get("level", 1)) - 1)

	# 직원 보너스
	var emp_bonus: float = float(_config.get("employee_revenue_bonus", 0.05))
	var emp_mult: float = 1.0 + emp_bonus * int(entry.get("employees", 0))

	# 이벤트 배율
	var event_mult: float = float(entry.get("event_multiplier", 1.0))

	return base * level_mult * emp_mult * event_mult


## 하루 경과 시 일괄 정산
func pay_daily_revenue() -> Dictionary:
	var game_accel: float = float(_config.get("game_accel", 10.0))
	var total: float = 0.0
	var breakdown: Dictionary = {}

	for bid in _owned:
		var rev = _calc_business_daily_revenue(bid)
		# 캡은 전체에 적용
		total += rev
		breakdown[bid] = rev

	# 캡
	total = _apply_cap(total, true)

	if total > 0:
		GameManager.add_cash(total)
		_total_revenue += total

	# 이벤트 감소
	_decay_events()

	return {"total": total, "breakdown": breakdown}


func _apply_cap(amount: float, is_daily: bool = false) -> float:
	if amount <= 0:
		return 0.0
	var net_worth := GameManager.get_net_worth()
	if net_worth <= 0:
		return amount
	var game_accel: float = float(_config.get("game_accel", 10.0))
	if is_daily:
		var cap := net_worth * _daily_cap_pct
		return min(amount, cap)
	else:
		var cap := net_worth * _daily_cap_pct / game_accel
		return min(amount, cap)


# ═══════════════════════════════════════
# 이벤트
# ═══════════════════════════════════════

## 하루 경과 시 사업 이벤트 발생 체크
func roll_daily_events() -> Array:
	var triggered: Array = []
	if _owned.size() == 0:
		return triggered

	var chance: float = float(_config.get("event_chance_daily", 0.12))

	for bid in _owned.keys():
		if randf() > chance:
			continue
		var event = _pick_event(bid)
		if event.is_empty():
			continue
		_apply_event(bid, event)
		triggered.append({"business_id": bid, "event": event})
		business_event.emit(bid, event)

	return triggered


func _pick_event(business_id: String) -> Dictionary:
	var def = _get_def(business_id)
	var cat: String = def.get("category", "")
	var pool: Array = []
	var total_weight: int = 0

	for ev in _events:
		# 카테고리 필터
		if ev.has("category_filter") and ev["category_filter"] != cat:
			continue
		pool.append(ev)
		total_weight += int(ev.get("weight", 10))

	if pool.is_empty() or total_weight <= 0:
		return {}

	var roll: int = randi() % total_weight
	var acc: int = 0
	for ev in pool:
		acc += int(ev.get("weight", 10))
		if roll < acc:
			return ev
	return pool[0]


func _apply_event(business_id: String, event: Dictionary) -> void:
	if not _owned.has(business_id):
		return
	var entry = _owned[business_id]
	var type: String = event.get("type", "")

	match type:
		"revenue_boost", "revenue_penalty":
			entry["event_multiplier"] = float(event.get("multiplier", 1.0))
			entry["event_days_left"] = int(event.get("duration_days", 5))
		"penalty_cash":
			# 일일 수익의 N% 벌금
			var daily_rev = _calc_business_daily_revenue(business_id)
			var penalty = daily_rev * float(event.get("amount_pct_of_daily", 10)) / 100.0
			GameManager.add_cash(-penalty)
		"free_employee":
			var max_emp: int = int(_config.get("max_employees", 5))
			if entry.get("employees", 0) < max_emp:
				entry["employees"] = int(entry.get("employees", 0)) + 1

	_owned[business_id] = entry


func _decay_events() -> void:
	for bid in _owned.keys():
		var entry = _owned[bid]
		var days: int = int(entry.get("event_days_left", 0))
		if days > 0:
			days -= 1
			entry["event_days_left"] = days
			if days <= 0:
				entry["event_multiplier"] = 1.0
			_owned[bid] = entry


# ═══════════════════════════════════════
# 조회
# ═══════════════════════════════════════

func _get_def(business_id: String) -> Dictionary:
	for d in _defs:
		if d.get("id", "") == business_id:
			return d
	return {}

func _count_category(cat: String) -> int:
	var count: int = 0
	for bid in _owned:
		var def = _get_def(bid)
		if def.get("category", "") == cat:
			count += 1
	return count

func get_all_defs() -> Array:
	return _defs

func get_owned() -> Dictionary:
	return _owned

func get_owned_list() -> Array:
	var result: Array = []
	for bid in _owned:
		var def = _get_def(bid)
		var entry = _owned[bid]
		result.append({
			"id": bid,
			"name": def.get("name", ""),
			"category": def.get("category", ""),
			"icon": def.get("icon", ""),
			"level": int(entry.get("level", 1)),
			"employees": int(entry.get("employees", 0)),
			"daily_revenue": _calc_business_daily_revenue(bid),
			"event_mult": float(entry.get("event_multiplier", 1.0)),
			"event_days": int(entry.get("event_days_left", 0))
		})
	return result

func get_available() -> Array:
	var result: Array = []
	for def in _defs:
		if not _owned.has(def.get("id", "")):
			result.append(def)
	return result

func get_total_daily_revenue() -> float:
	var total: float = 0.0
	for bid in _owned:
		total += _calc_business_daily_revenue(bid)
	return total

func get_total_revenue_earned() -> float:
	return _total_revenue

func get_last_tick_revenue() -> float:
	return _last_tick_revenue

func get_upgrade_cost(business_id: String) -> float:
	if not _owned.has(business_id):
		return 0.0
	var def = _get_def(business_id)
	var base: float = float(def.get("purchase_price", 0))
	var mult: float = float(_config.get("base_upgrade_cost_multiplier", 0.3))
	var level: int = int(_owned[business_id].get("level", 1))
	return base * mult * level


# ═══════════════════════════════════════
# 저장/로드
# ═══════════════════════════════════════

func serialize() -> Dictionary:
	return {
		"owned": _owned.duplicate(true),
		"total_revenue": _total_revenue
	}

func deserialize(data: Dictionary) -> void:
	_owned = data.get("owned", {}).duplicate(true)
	_total_revenue = float(data.get("total_revenue", 0))


func _fail(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}

func _fmt(amount: float) -> String:
	var a = int(amount)
	if abs(a) >= 100000000:
		return "%.2f억" % (amount / 100000000.0)
	elif abs(a) >= 10000:
		return "%.1f만" % (amount / 10000.0)
	else:
		return "%d" % a

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

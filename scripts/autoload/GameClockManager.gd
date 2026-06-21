extends Node
## GameClockManager — 장전/장중/장마감 페이즈 기반 시간 시스템
## 장전(07:00-09:00): 뉴스/브리핑, 1시간 단위 진행
## 장중(09:00-16:00): 주가 변동, 분 단위 진행 (1x=1분, 4x=5분)
## 장마감(16:00-07:00): NPC/외부활동, 1시간 단위 진행

signal time_changed(hour: int, minute: int, phase: int)
signal phase_changed(old_phase: int, new_phase: int)
signal day_advanced(day: int, result: Dictionary)
signal hourly_price_update(hour: int)
signal pre_market_started()
signal market_opened()
signal market_closed()

enum Phase { PRE_MARKET, MARKET, AFTER_HOURS }

var current_phase: int = Phase.PRE_MARKET
var in_game_hour: int = 7
var in_game_minute: int = 0
var is_paused: bool = false
var speed_multiplier: float = 1.0

# 틱 설정
const TICK_INTERVAL: float = 1.0  # 1초마다 1틱
const PREMARKET_SECONDS_PER_HOUR: float = 3.0  # 장전: 3초 = 1시간
const AFTER_HOURS_SECONDS_PER_HOUR: float = 3.0  # 장마감: 3초 = 1시간

var _tick_accumulator: float = 0.0
var _advancing: bool = false
var _hour_update_pending: bool = false

# 장전 뉴스가 표시되었는지
var pre_market_news_shown: bool = false


func _process(delta: float) -> void:
	if is_paused or _advancing:
		return

	_tick_accumulator += delta * speed_multiplier

	match current_phase:
		Phase.PRE_MARKET:
			if _tick_accumulator >= PREMARKET_SECONDS_PER_HOUR:
				_tick_accumulator = 0.0
				_advance_hour()
		Phase.MARKET:
			# 속도별 분 단위 진행: 1x=1분, 2x=2분, 4x=5분
			var minutes_per_tick := _get_minutes_per_tick()
			var seconds_per_tick: float = TICK_INTERVAL
			if _tick_accumulator >= seconds_per_tick:
				_tick_accumulator = 0.0
				_advance_minutes(minutes_per_tick)
		Phase.AFTER_HOURS:
			if _tick_accumulator >= AFTER_HOURS_SECONDS_PER_HOUR:
				_tick_accumulator = 0.0
				# 장마감은 16:00~19:00까지만 (3시간), 이후 자동 다음날
				if in_game_hour >= 19:
					in_game_hour = 7
					in_game_minute = 0
					_do_advance_day()
					_enter_phase(Phase.PRE_MARKET)
				else:
					_advance_hour()


func _get_minutes_per_tick() -> int:
	match int(speed_multiplier):
		1: return 1
		2: return 2
		4: return 5
		_: return int(speed_multiplier)


## 1시간 진행 (장전/장마감용)
func _advance_hour() -> void:
	in_game_hour += 1
	in_game_minute = 0

	# 장전 → 장중 전환 (09:00)
	if current_phase == Phase.PRE_MARKET and in_game_hour >= 9:
		_enter_phase(Phase.MARKET)
		return

	# 장마감 → 다음날 장전 (07:00) — 19:00에 자동 전환
	# 실제 전환은 _process에서 처리하므로 여기서는 시간만 진행
	if current_phase == Phase.AFTER_HOURS and in_game_hour >= 19:
		in_game_hour = 7
		in_game_minute = 0
		_do_advance_day()
		_enter_phase(Phase.PRE_MARKET)
		return

	time_changed.emit(in_game_hour, in_game_minute, current_phase)


## 분 단위 진행 (장중용)
func _advance_minutes(minutes: int) -> void:
	in_game_minute += minutes

	# 시간 넘김
	while in_game_minute >= 60:
		in_game_minute -= 60
		in_game_hour += 1
		# 1시간마다 주가 갱신
		hourly_price_update.emit(in_game_hour)

	# 장중 → 장마감 전환 (16:00)
	if in_game_hour >= 16:
		in_game_hour = 16
		in_game_minute = 0
		# 종가 저장
		MarketSim.save_close_prices()
		_enter_phase(Phase.AFTER_HOURS)
		return

	time_changed.emit(in_game_hour, in_game_minute, current_phase)


## 페이즈 전환
func _enter_phase(new_phase: int) -> void:
	var old := current_phase
	current_phase = new_phase
	_tick_accumulator = 0.0

	match new_phase:
		Phase.PRE_MARKET:
			pre_market_news_shown = false
			pre_market_started.emit()
		Phase.MARKET:
			MarketSim.on_market_open()
			market_opened.emit()
		Phase.AFTER_HOURS:
			market_closed.emit()

	phase_changed.emit(old, new_phase)
	time_changed.emit(in_game_hour, in_game_minute, current_phase)


## 하루 경과 처리
func _do_advance_day() -> void:
	_advancing = true

	var r := GameManager.advance_day()
	var events := EventManager.roll_daily_events()
	r["events"] = events
	EventManager.clear_old_events()

	# 다음날 시가 = 전날 종가
	MarketSim.advance_day()

	day_advanced.emit(GameManager.player.get("day", 1), r)
	_advancing = false


## 장마감에서 "다음날로" 버튼 (또는 자동)
func advance_to_next_day() -> void:
	if current_phase != Phase.AFTER_HOURS:
		return
	in_game_hour = 7
	in_game_minute = 0
	_do_advance_day()
	_enter_phase(Phase.PRE_MARKET)


## 외부 이벤트(NPC 대화 등)로 인한 일시정지
func pause_for_event() -> void:
	is_paused = true

func resume_from_event() -> void:
	is_paused = false


func toggle_pause() -> void:
	is_paused = not is_paused

func set_speed(mult: float) -> void:
	speed_multiplier = mult
	if is_paused:
		is_paused = false


## 페이즈 이름
func get_phase_name() -> String:
	match current_phase:
		Phase.PRE_MARKET: return "장전"
		Phase.MARKET: return "장중"
		Phase.AFTER_HOURS: return "장마감"
		_: return ""

## 시간 문자열
func get_time_string() -> String:
	return "%02d:%02d" % [in_game_hour, in_game_minute]

## 전체 상태 문자열
func get_status_string() -> String:
	return "%s %02d:%02d" % [get_phase_name(), in_game_hour, in_game_minute]

## 진행률 (ProgressBar용, 현재 페이즈 내 진행도)
func get_phase_progress() -> float:
	match current_phase:
		Phase.PRE_MARKET:
			# 07:00 ~ 09:00 = 2시간
			return float(in_game_hour - 7) / 2.0
		Phase.MARKET:
			# 09:00 ~ 16:00 = 7시간
			var total_min: float = (in_game_hour - 9) * 60 + in_game_minute
			return total_min / 420.0
		Phase.AFTER_HOURS:
			# 16:00 ~ 19:00 = 3시간
			return float(in_game_hour - 16) / 3.0
		_: return 0.0


## 게임 시작 시 초기화
func start_new_game() -> void:
	current_phase = Phase.PRE_MARKET
	in_game_hour = 7
	in_game_minute = 0
	is_paused = false
	speed_multiplier = 1.0
	pre_market_news_shown = false
	time_changed.emit(in_game_hour, in_game_minute, current_phase)


## 저장/로드
func serialize() -> Dictionary:
	return {
		"phase": current_phase,
		"hour": in_game_hour,
		"minute": in_game_minute,
		"is_paused": is_paused,
		"speed_multiplier": speed_multiplier
	}

func deserialize(data: Dictionary) -> void:
	current_phase = int(data.get("phase", Phase.PRE_MARKET))
	in_game_hour = int(data.get("hour", 7))
	in_game_minute = int(data.get("minute", 0))
	is_paused = bool(data.get("is_paused", false))
	speed_multiplier = float(data.get("speed_multiplier", 1.0))

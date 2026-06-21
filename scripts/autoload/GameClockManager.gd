extends Node
## GameClockManager — 자동 시간 흐름 시스템
## 방치형 핵심: 시간이 자동으로 흐르고, 하루가 차면 advance_day 호출
## 수동 "하루 넘기기" 버튼도 같은 경로를 사용한다

signal day_progress_changed(progress: float)
signal day_advanced(result: Dictionary)
signal time_tick(day: int, progress: float)

var real_seconds_per_game_day: float = 120.0
var day_progress: float = 0.0
var is_paused: bool = false
var speed_multiplier: float = 1.0

var _advancing: bool = false  # 중복 진행 방지 락


func _process(delta: float) -> void:
	if is_paused or _advancing:
		return

	# delta를 누적해서 하루 진행률 계산
	day_progress += (delta * speed_multiplier) / real_seconds_per_game_day

	if day_progress >= 1.0:
		day_progress = 0.0
		_do_advance_day()
	else:
		day_progress_changed.emit(day_progress)
		time_tick.emit(GameManager.player.get("day", 1), day_progress)


## 자동 시간 흐름으로 하루가 찼을 때 호출
func _do_advance_day() -> void:
	_advancing = true

	var r := GameManager.advance_day()
	MarketSim.advance_day()
	day_progress = 0.0

	# 이벤트 발생
	var events := EventManager.roll_daily_events()
	r["events"] = events
	EventManager.clear_old_events()

	day_advanced.emit(r)
	day_progress_changed.emit(0.0)

	_advancing = false


## 수동 "하루 넘기기" 버튼 — 즉시 하루 진행
func force_advance_day() -> void:
	if _advancing:
		return
	_do_advance_day()


## 일시정지 토글
func toggle_pause() -> void:
	is_paused = not is_paused


## 진행 속도 설정
func set_speed(mult: float) -> void:
	speed_multiplier = mult


## 가상 시간 문자열 (09:00 ~ 24:00)
func get_virtual_time() -> String:
	# day_progress 0.0 = 09:00, 1.0 = 09:00 다음 날
	var total_minutes := int(day_progress * 15.0 * 60.0)  # 15시간 = 09:00~24:00
	var hour := 9 + total_minutes / 60
	var minute := total_minutes % 60
	if hour >= 24:
		hour -= 24
	return "%02d:%02d" % [hour, minute]


## 저장/로드
func serialize() -> Dictionary:
	return {
		"day_progress": day_progress,
		"is_paused": is_paused,
		"speed_multiplier": speed_multiplier
	}

func deserialize(data: Dictionary) -> void:
	day_progress = float(data.get("day_progress", 0.0))
	is_paused = bool(data.get("is_paused", false))
	speed_multiplier = float(data.get("speed_multiplier", 1.0))

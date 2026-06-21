extends Node
## StoryManager — 스토리 챕터 진행 + 컷신 재생 시스템

signal chapter_started(chapter_id: String)
signal chapter_completed(chapter_id: String)
signal scene_ready(scene_data: Dictionary)
signal story_event(text: String)  # UI에서 컷신 표시용

var _chapters: Array = []
var _completed_chapters: Dictionary = {}  # chapter_id -> true
var _current_chapter: String = ""
var _current_scene_idx: int = 0
var _is_playing: bool = false


func _ready() -> void:
	_load_data()


func _load_data() -> void:
	var data = _load_json("res://data/story.json")
	if data and data.has("chapters"):
		_chapters = data["chapters"]


## 게임 시작 시 호출 — ch1 자동 재생
func check_start_story() -> void:
	if _chapters.size() == 0:
		return
	var ch1 = _chapters[0]
	var trigger = ch1.get("trigger", {})
	if trigger.get("type") == "start":
		if not _completed_chapters.has(ch1["id"]):
			_play_chapter(ch1)


## 매 틱/이벤트마다 트리거 체크
func check_triggers() -> void:
	if _is_playing:
		return
	for chapter in _chapters:
		if _completed_chapters.has(chapter["id"]):
			continue
		if _check_trigger(chapter.get("trigger", {})):
			_play_chapter(chapter)
			break


func _check_trigger(trigger: Dictionary) -> bool:
	var type: String = trigger.get("type", "")
	match type:
		"start":
			return false  # 이미 check_start_story에서 처리
		"net_worth":
			return GameManager.get_net_worth() >= float(trigger.get("value", 0))
		"rank_index":
			return GameManager.player.get("rank_index", 0) >= int(trigger.get("value", 0))
		"married_days":
			if not NPCManager.is_married():
				return false
			var married_day: int = GameManager.player.get("married_day", -1)
			var current_day: int = GameManager.player.get("day", 0)
			return (current_day - married_day) >= int(trigger.get("value", 0))
		_:
			return false
	return false


func _play_chapter(chapter: Dictionary) -> void:
	_current_chapter = chapter["id"]
	_current_scene_idx = 0
	_is_playing = true
	chapter_started.emit(chapter["id"])
	_show_current_scene(chapter)


func _show_current_scene(chapter: Dictionary) -> void:
	var scenes: Array = chapter.get("scenes", [])
	if _current_scene_idx >= scenes.size():
		_complete_chapter()
		return
	var scene = scenes[_current_scene_idx]
	scene_ready.emit(scene)
	# UI에서 story_event 시그널을 받아 컷신을 표시
	story_event.emit(_format_scene(scene))


func _format_scene(scene: Dictionary) -> String:
	var speaker: String = scene.get("speaker", "")
	var text: String = scene.get("text", "")
	return "[b]%s[/b]\n%s" % [speaker, text]


## 다음 컷신으로 (UI에서 "다음" 버튼 클릭 시 호출)
func advance_scene() -> void:
	if not _is_playing:
		return
	_current_scene_idx += 1
	var chapter = _get_current_chapter()
	if chapter.is_empty():
		_is_playing = false
		return
	_show_current_scene(chapter)


## 스토리 스킵
func skip_chapter() -> void:
	_complete_chapter()


func _complete_chapter() -> void:
	if _current_chapter != "":
		_completed_chapters[_current_chapter] = true
		chapter_completed.emit(_current_chapter)
	_current_chapter = ""
	_current_scene_idx = 0
	_is_playing = false


func _get_current_chapter() -> Dictionary:
	for ch in _chapters:
		if ch["id"] == _current_chapter:
			return ch
	return {}


# ─── 조회 ──────────────────────────────

func is_playing() -> bool:
	return _is_playing

func get_current_scene_info() -> Dictionary:
	var chapter = _get_current_chapter()
	if chapter.is_empty():
		return {}
	var scenes: Array = chapter.get("scenes", [])
	if _current_scene_idx >= scenes.size():
		return {}
	var scene = scenes[_current_scene_idx]
	scene["chapter_title"] = chapter.get("title", "")
	scene["scene_idx"] = _current_scene_idx
	scene["total_scenes"] = scenes.size()
	return scene

func get_completed_chapters() -> Array:
	return _completed_chapters.keys()

func get_chapter_count() -> int:
	return _chapters.size()


# ─── 저장/로드 ──────────────────────────

func serialize() -> Dictionary:
	return {
		"completed_chapters": _completed_chapters.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	_completed_chapters = data.get("completed_chapters", {}).duplicate()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)

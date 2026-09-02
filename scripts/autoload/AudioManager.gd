extends Node
## AudioManager — BGM 재생 관리 + SFX 스텁

var _bgm_player: AudioStreamPlayer
var _bgm_on: bool = true
const BGM_VOLUME: float = 0.5
var _tex_on: ImageTexture
var _tex_off: ImageTexture


func _ready() -> void:
	_tex_on = _load_texture("res://assets/images/icon_music_on.png")
	_tex_off = _load_texture("res://assets/images/icon_music_off.png")
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = linear_to_db(BGM_VOLUME)
	add_child(_bgm_player)


## BGM 재생 (무한 루프) — 이미 재생 중이면 무시
func play_bgm() -> void:
	if not _bgm_on or not _bgm_player:
		return
	if _bgm_player.playing:
		return
	var stream := _load_wav("res://bgm/bgm_group_bubble.wav")
	if not stream:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_player.stream = stream
	_bgm_player.play()


## WAV 파일 수동 파싱 → AudioStreamWAV (에디터 import 불필요)
func _load_wav(res_path: String) -> AudioStreamWAV:
	var fs_path := ProjectSettings.globalize_path(res_path)
	var file := FileAccess.open(fs_path, FileAccess.READ)
	if not file:
		return null
	# RIFF 헤더 스킵
	file.get_32()  # "RIFF"
	file.get_32()  # file size
	file.get_32()  # "WAVE"
	# fmt chunk 찾기
	var channels: int = 1
	var sample_rate: int = 44100
	var fmt_found := false
	while file.get_position() < file.get_length() and not fmt_found:
		var chunk_id := file.get_32()
		var chunk_size := file.get_32()
		if chunk_id == 0x20746D66:  # "fmt "
			file.get_16()  # audio format (PCM=1)
			channels = file.get_16()
			sample_rate = file.get_32()
			file.get_32()  # byte rate
			file.get_16()  # block align
			file.get_16()  # bits per sample
			fmt_found = true
		else:
			file.seek(file.get_position() + chunk_size)
	if not fmt_found:
		return null
	# data chunk 찾기
	var data: PackedByteArray = []
	while file.get_position() < file.get_length():
		var chunk_id := file.get_32()
		var chunk_size := file.get_32()
		if chunk_id == 0x61746164:  # "data"
			data = file.get_buffer(chunk_size)
			break
		else:
			file.seek(file.get_position() + chunk_size)
	if data.is_empty():
		return null
	# AudioStreamWAV 조립 (기존 SFX와 동일 방식)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = channels >= 2
	stream.data = data
	return stream


## BGM 정지
func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


## BGM 토글 (재생 ↔ 정지). 현재 상태 반환.
func toggle_bgm() -> bool:
	_bgm_on = not _bgm_on
	if _bgm_on:
		play_bgm()
	else:
		stop_bgm()
	return _bgm_on


## 현재 BGM 상태 반환
func is_bgm_on() -> bool:
	return _bgm_on


## 현재 아이콘 텍스처 반환 (토글 버튼용)
func get_icon_on() -> ImageTexture:
	return _tex_on

func get_icon_off() -> ImageTexture:
	return _tex_off


## 텍스처 로드 헬퍼
func _load_texture(res_path: String) -> ImageTexture:
	var full_path := ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(full_path):
		return null
	var img := Image.load_from_file(full_path)
	if img:
		return ImageTexture.create_from_image(img)
	return null


# ─── SFX 스텁 (미사용 — 기존 호출 호환성 유지) ──────────
func play_buy() -> void: pass
func play_sell() -> void: pass
func play_error() -> void: pass
func play_day_advance() -> void: pass
func play_event_news() -> void: pass
func play_event_bad() -> void: pass
func play_rank_up() -> void: pass
func play_auto_trade() -> void: pass
func play_marriage() -> void: pass
func play_button_click() -> void: pass
func play_quest_complete() -> void: pass
func play_achievement_unlock() -> void: pass
func play_story_unlock() -> void: pass
func play_business_good() -> void: pass
func play_business_bad() -> void: pass

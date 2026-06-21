extends Node
## AudioManager — 절차적 효과음 생성 (오디오 파일 없이 코드로 사운드 생성)

var _master_volume: float = 0.6
var _sfx_enabled: bool = true

var _audio_players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS := 8
var _player_index := 0


func _ready() -> void:
	for i in MAX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(_master_volume)
		add_child(p)
		_audio_players.append(p)


func _get_player() -> AudioStreamPlayer:
	var p := _audio_players[_player_index]
	_player_index = (_player_index + 1) % MAX_PLAYERS
	return p


## 짧은 효과음 생성 — freq(주파수), duration(초), type(파형)
func _make_blip(freq: float, duration: float, type: int = 0) -> AudioStreamWAV:
	var sample_rate := 22050
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t := float(i) / sample_rate
		var sample: float = 0.0

		match type:
			0:  # sine
				sample = sin(t * freq * TAU)
			1:  # square
				sample = 1.0 if sin(t * freq * TAU) > 0 else -1.0
			2:  # sawtooth
				sample = fmod(t * freq, 1.0) * 2.0 - 1.0
			3:  # noise burst
				sample = randf_range(-1.0, 1.0)

		# envelope (attack-decay)
		var env: float = 1.0
		var attack := 0.01
		var release_start := duration * 0.6
		if t < attack:
			env = t / attack
		elif t > release_start:
			env = maxf(0.0, 1.0 - (t - release_start) / (duration - release_start))

		sample *= env * 0.3

		var s16 := int(clampf(sample, -1.0, 1.0) * 32767)
		data.encode_s16(i * 2, s16)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _play(stream: AudioStreamWAV, volume_offset: float = 0.0) -> void:
	if not _sfx_enabled:
		return
	var p := _get_player()
	p.stream = stream
	p.volume_db = linear_to_db(_master_volume) + volume_offset
	p.play()


# ─── 게임 효과음 ──────────────────────────────

func play_buy() -> void:
	# 상승음 (C5 -> E5 -> G5)
	var s := _make_blip(523.0, 0.08, 0)
	_play(s, 2.0)
	get_tree().create_timer(0.06).timeout.connect(func(): _play(_make_blip(659.0, 0.08, 0), 2.0))
	get_tree().create_timer(0.12).timeout.connect(func(): _play(_make_blip(784.0, 0.12, 0), 2.0))


func play_sell() -> void:
	# 하락음 (G5 -> E5 -> C5)
	var s := _make_blip(784.0, 0.08, 0)
	_play(s, 2.0)
	get_tree().create_timer(0.06).timeout.connect(func(): _play(_make_blip(659.0, 0.08, 0), 2.0))
	get_tree().create_timer(0.12).timeout.connect(func(): _play(_make_blip(523.0, 0.12, 0), 2.0))


func play_error() -> void:
	# 에러음 (낮은 buzzing)
	var s := _make_blip(150.0, 0.15, 1)
	_play(s, -2.0)


func play_day_advance() -> void:
	# 하루 경과 (부드러운 차임벨)
	var s := _make_blip(440.0, 0.15, 0)
	_play(s, 0.0)
	get_tree().create_timer(0.08).timeout.connect(func(): _play(_make_blip(660.0, 0.2, 0), 0.0))


func play_event_news() -> void:
	# 뉴스 이벤트 (트리플 알림)
	for i in 3:
		var delay := i * 0.1
		get_tree().create_timer(delay).timeout.connect(
			func(): _play(_make_blip(880.0, 0.06, 0), 3.0)
		)


func play_event_bad() -> void:
	# 나쁜 소식 (저음 톤)
	var s := _make_blip(200.0, 0.3, 2)
	_play(s, -1.0)


func play_rank_up() -> void:
	# 승진 (팡파르 — 상승 아르페지오)
	var notes := [523.0, 659.0, 784.0, 1047.0]
	for i in notes.size():
		var delay := i * 0.08
		get_tree().create_timer(delay).timeout.connect(
			func(n: float = notes[i]): _play(_make_blip(n, 0.15, 0), 4.0)
		)


func play_auto_trade() -> void:
	# 자동매매 실행 (전자음)
	var s := _make_blip(1200.0, 0.04, 0)
	_play(s, 1.0)
	get_tree().create_timer(0.04).timeout.connect(func(): _play(_make_blip(800.0, 0.04, 0), 1.0))


func play_marriage() -> void:
	# 결혼 (로맨틱 차임)
	var notes := [659.0, 784.0, 1047.0, 784.0, 1047.0]
	for i in notes.size():
		var delay := i * 0.12
		get_tree().create_timer(delay).timeout.connect(
			func(n: float = notes[i]): _play(_make_blip(n, 0.2, 0), 3.0)
		)


func play_button_click() -> void:
	var s := _make_blip(800.0, 0.03, 0)
	_play(s, -3.0)


## 퀘스트 완료 — 상승 멜로디
func play_quest_complete() -> void:
	var s1 := _make_blip(660.0, 0.08, 0)
	_play(s1, 0.0)
	var s2 := _make_blip(880.0, 0.08, 0)
	get_tree().create_timer(0.08).timeout.connect(func(): _play(s2, 0.0))
	var s3 := _make_blip(1100.0, 0.12, 0)
	get_tree().create_timer(0.16).timeout.connect(func(): _play(s3, 0.0))


## 업적 달성 — 골드 멜로디
func play_achievement_unlock() -> void:
	var s1 := _make_blip(880.0, 0.06, 1)
	_play(s1, 0.0)
	var s2 := _make_blip(1320.0, 0.10, 1)
	get_tree().create_timer(0.06).timeout.connect(func(): _play(s2, 0.0))


## 스토리 해금 — 깊은음
func play_story_unlock() -> void:
	var s := _make_blip(330.0, 0.25, 2)
	_play(s, 2.0)


## 사업 이벤트 (호황)
func play_business_good() -> void:
	var s := _make_blip(770.0, 0.10, 0)
	_play(s, 0.0)


## 사업 이벤트 (불황)
func play_business_bad() -> void:
	var s := _make_blip(300.0, 0.15, 2)
	_play(s, 0.0)


func set_volume(vol: float) -> void:
	_master_volume = clampf(vol, 0.0, 1.0)
	for p in _audio_players:
		p.volume_db = linear_to_db(_master_volume)


func toggle_sfx() -> bool:
	_sfx_enabled = not _sfx_enabled
	return _sfx_enabled


func is_sfx_enabled() -> bool:
	return _sfx_enabled

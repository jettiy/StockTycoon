extends Control
## Boot — 시작 화면 + 오프라인 보상 팝업
## 모든 해상도 대응: CenterContainer 기반 동적 배치
## 어두운 HTS 느낌 + 희미한 그리드 배경

const MAIN_SCENE := "res://scenes/main.tscn"

# 색상 — 파란색/회색/흰색 계열
const COL_BG := Color(0.063, 0.067, 0.078, 1)
const COL_PANEL := Color(0.106, 0.110, 0.122, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
const COL_UP := Color(0.15, 0.65, 0.39, 1)
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)
const COL_TEXT := Color(0.82, 0.82, 0.85, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
const COL_GOLD := Color(0.85, 0.70, 0.30, 1)
const COL_GRID := Color(0.10, 0.12, 0.16, 0.5)  # 희미한 그리드

var _container: VBoxContainer
var _load_button: Button
var _popup: PanelContainer
var _grid_bg: Control  # 커스텀 그리드 배경


func _ready() -> void:
	_setup_window()
	_build_ui()


func _setup_window() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var win_w := int(screen_size.x * 0.85)
	var win_h := int(screen_size.y * 0.85)
	DisplayServer.window_set_size(Vector2i(win_w, win_h))
	DisplayServer.window_set_position(Vector2i(
		(screen_size.x - win_w) / 2,
		(screen_size.y - win_h) / 2
	))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				_setup_window()
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_ESCAPE:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				_setup_window()


## ─── 메인 UI 빌드 ──────────────────────────────

func _build_ui() -> void:
	# 1. 배경
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. 희미한 그리드 배경 (커스텀 _draw)
	_grid_bg = Control.new()
	_grid_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_bg.draw.connect(_draw_grid)
	# 리사이즈 시 다시 그리기
	_grid_bg.resized.connect(func(): _grid_bg.queue_redraw())
	add_child(_grid_bg)

	# 3. CenterContainer — 모든 해상도에서 중앙 정렬
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 좌우 상하 패딩 (최소 80px 하단 여백 보장)
	center.offset_left = 40
	center.offset_right = -40
	center.offset_top = 40
	center.offset_bottom = -80  # 하단 최소 80px 여백
	add_child(center)

	# 4. 타이틀 그룹 VBox
	_container = VBoxContainer.new()
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", _scale(18))
	center.add_child(_container)

	# 뷰포트 기반 동적 폰트 스케일
	var vp_h := get_viewport_rect().size.y
	var fs_title := _scale_font(vp_h, 76, 56)
	var fs_sub := _scale_font(vp_h, 28, 20)
	var fs_desc := _scale_font(vp_h, 18, 14)

	# ── 타이틀 ──
	var title := Label.new()
	title.text = "주식잡스"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", fs_title)
	title.add_theme_color_override("font_color", COL_ACCENT)
	_container.add_child(title)

	# ── 영문 부제 ──
	var subtitle := Label.new()
	subtitle.text = "STOCK TYCOON"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", fs_sub)
	subtitle.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(subtitle)

	_container.add_child(_spacer(_scale(24)))

	# ── 설명 문구 ──
	var desc := Label.new()
	desc.text = "증권가에 취직한 청년의 주식 투자 인생"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", fs_desc)
	desc.add_theme_color_override("font_color", COL_TEXT)
	_container.add_child(desc)

	_container.add_child(_spacer(_scale(36)))

	# ── 새 게임 버튼 ──
	var new_game := _make_button("새 게임", COL_UP, true)
	new_game.pressed.connect(_on_new_game)
	_container.add_child(new_game)

	# ── 이어하기 버튼 ──
	_load_button = _make_button("이어하기", COL_ACCENT, false)
	_load_button.disabled = not SaveManager.has_save()
	_load_button.pressed.connect(_on_load_game)
	_container.add_child(_load_button)

	_container.add_child(_spacer(_scale(28)))

	# ── 버전 정보 ──
	var ver := Label.new()
	ver.text = "v0.2.0"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", _scale_font(vp_h, 13, 11))
	ver.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(ver)

	# 리사이즈 시 폰트 재계산
	get_viewport().size_changed.connect(_on_viewport_resized)


## ─── 그리드 배경 드로잉 ──────────────────────────

func _draw_grid() -> void:
	if not _grid_bg:
		return
	var size := _grid_bg.size
	if size.x <= 0 or size.y <= 0:
		return

	var spacing := _scale(60)

	# 수직선
	var x := spacing
	while x < size.x:
		_grid_bg.draw_line(
			Vector2(x, 0), Vector2(x, size.y), COL_GRID, 1.0
		)
		x += spacing

	# 수평선
	var y := spacing
	while y < size.y:
		_grid_bg.draw_line(
			Vector2(0, y), Vector2(size.x, y), COL_GRID, 1.0
		)
		y += spacing

	# 중앙 강조 라인 (희미한 액센트)
	var center_line := Color(0.20, 0.56, 0.85, 0.08)
	_grid_bg.draw_line(
		Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0),
		center_line, 2.0
	)


## ─── 동적 스케일 헬퍼 ──────────────────────────

## 뷰포트 크기에 비례한 픽셀값 (1280x720 기준 1.0)
func _scale(base: float) -> float:
	var vp := get_viewport_rect().size
	var ref := minf(vp.x / 1280.0, vp.y / 720.0)
	return base * clampf(ref, 0.75, 1.5)

## 뷰포트 높이에 따른 폰트 사이즈 (max ~ min 범위)
func _scale_font(vp_h: float, max_size: int, min_size: int) -> int:
	var ratio := clampf(vp_h / 1080.0, 0.6, 1.2)
	return int(clampf(float(max_size) * ratio, float(min_size), float(max_size)))


## ─── 버튼 생성 (hover 구분 강화) ──────────────────

func _make_button(text: String, color: Color, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text

	# 동적 사이즈
	var vp_h := get_viewport_rect().size.y
	var btn_w := int(_scale_font(vp_h, 360, 280))
	var btn_h := int(_scale_font(vp_h, 56, 46))
	btn.custom_minimum_size = Vector2(btn_w, btn_h)
	btn.add_theme_font_size_override("font_size", _scale_font(vp_h, 22, 17))

	# 기본 상태: 어두운 패널 + 얇은 테두리
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = COL_PANEL
	style_normal.border_color = color if is_primary else COL_TEXT_DIM
	style_normal.set_border_width_all(2 if is_primary else 1)
	style_normal.set_corner_radius_all(6)
	style_normal.content_margin_left = 20
	style_normal.content_margin_right = 20
	style_normal.content_margin_top = 12
	style_normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", style_normal)

	# hover 상태: 테두리 색으로 채우기 + 글자색 변화
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(color.r * 0.18, color.g * 0.18, color.b * 0.18, 1)
	style_hover.border_color = color
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(6)
	style_hover.content_margin_left = 20
	style_hover.content_margin_right = 20
	style_hover.content_margin_top = 12
	style_hover.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", style_hover)

	# pressed 상태: 완전 채우기
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 1)
	style_pressed.border_color = color
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(6)
	style_pressed.content_margin_left = 20
	style_pressed.content_margin_right = 20
	style_pressed.content_margin_top = 12
	style_pressed.content_margin_bottom = 12
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# disabled
	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = COL_PANEL
	style_disabled.border_color = Color(0.15, 0.15, 0.18, 1)
	style_disabled.set_border_width_all(1)
	style_disabled.set_corner_radius_all(6)
	style_disabled.content_margin_left = 20
	style_disabled.content_margin_right = 20
	style_disabled.content_margin_top = 12
	style_disabled.content_margin_bottom = 12
	btn.add_theme_stylebox_override("disabled", style_disabled)

	btn.add_theme_color_override("font_color", color if is_primary else COL_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", COL_TEXT_DIM)

	return btn


## ─── 뷰포트 리사이즈 핸들러 ──────────────────────

func _on_viewport_resized() -> void:
	if _grid_bg:
		_grid_bg.queue_redraw()


## ─── 게임 시작 ──────────────────────────────────

func _on_new_game() -> void:
	GameManager.reset_player()
	StoryManager.check_start_story()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_load_game() -> void:
	SaveManager.load_game()
	var rewards := SaveManager.calculate_offline_rewards()
	if rewards["cash"] > 0:
		_show_offline_popup(rewards)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)


## ─── 오프라인 보상 팝업 ──────────────────────────

func _show_offline_popup(rewards: Dictionary) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.z_index = 51
	add_child(center)

	_popup = PanelContainer.new()
	var vp_h := get_viewport_rect().size.y
	_popup.custom_minimum_size = Vector2(_scale_font(vp_h, 520, 420), _scale_font(vp_h, 340, 280))
	_popup.add_theme_stylebox_override("panel", _style_border(COL_PANEL, COL_ACCENT, 12))
	center.add_child(_popup)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", _scale(12))
	vbox.offset_left = _scale(24)
	vbox.offset_top = _scale(24)
	vbox.offset_right = -_scale(24)
	vbox.offset_bottom = -_scale(24)
	_popup.add_child(vbox)

	var title := Label.new()
	title.text = "오프라인 보상"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _scale_font(vp_h, 28, 22))
	title.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(title)

	var hours: float = rewards["time_seconds"] / 3600.0
	var mins := int(rewards["time_seconds"] / 60.0) % 60
	var time_label := Label.new()
	time_label.text = "부재 시간: %d시간 %d분" % [int(hours), mins]
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", _scale_font(vp_h, 17, 14))
	time_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(time_label)

	vbox.add_child(_spacer(_scale(8)))

	var cash_label := Label.new()
	cash_label.text = "+ %s" % _fmt_won(rewards["cash"])
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_label.add_theme_font_size_override("font_size", _scale_font(vp_h, 32, 24))
	cash_label.add_theme_color_override("font_color", COL_UP)
	vbox.add_child(cash_label)

	if rewards.get("auto_trades", 0) > 0:
		var auto_label := Label.new()
		auto_label.text = "자동매매: %d건 실행" % rewards["auto_trades"]
		auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		auto_label.add_theme_font_size_override("font_size", _scale_font(vp_h, 17, 14))
		auto_label.add_theme_color_override("font_color", COL_ACCENT)
		vbox.add_child(auto_label)

	vbox.add_child(_spacer(_scale(16)))

	var claim_btn := _make_button("수령하고 계속하기", COL_UP, true)
	claim_btn.pressed.connect(
		func():
			SaveManager.apply_offline_rewards()
			get_tree().change_scene_to_file(MAIN_SCENE)
	)
	vbox.add_child(claim_btn)


## ─── 유틸리티 ──────────────────────────────────

func _style_border(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _fmt_won(amount: float) -> String:
	var ab := absf(amount)
	var sign := "-" if amount < 0 else ""
	if ab >= 1_000_000_000_000:
		return "%s%.2f조원" % [sign, ab / 1_000_000_000_000]
	elif ab >= 100_000_000:
		return "%s%.2f억원" % [sign, ab / 100_000_000]
	elif ab >= 10_000_000:
		return "%s%.1f천만원" % [sign, ab / 10_000_000]
	elif ab >= 1_000_000:
		return "%s%d만원" % [sign, int(ab / 10_000)]
	elif ab >= 10_000:
		return "%s%.1f만원" % [sign, ab / 10_000]
	return "%s%.0f원" % [sign, ab]

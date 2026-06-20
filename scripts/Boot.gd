extends Control
## Boot — 시작 화면 (타이틀 + 새게임/이어하기)

const MAIN_SCENE := "res://scenes/main.tscn"

var _container: VBoxContainer
var _load_button: Button

# 색상 (다크 트레이딩 터미널 톤)
const COL_BG := Color(0.063, 0.067, 0.078, 1)
const COL_PANEL := Color(0.106, 0.110, 0.122, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)     # muted blue
const COL_UP := Color(0.15, 0.65, 0.39, 1)          # muted green
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)        # muted red
const COL_TEXT := Color(0.82, 0.82, 0.85, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 중앙 컨테이너
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.custom_minimum_size = Vector2(500, 400)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 16)
	add_child(_container)

	# 타이틀
	var title := Label.new()
	title.text = "주식잡스"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", COL_ACCENT)
	_container.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Stock Tycoon"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(subtitle)

	# 여백
	_container.add_child(_spacer(20))

	# 설명
	var desc := Label.new()
	desc.text = "증권가에 취직한 청년의 주식 투자 인생"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(desc)

	_container.add_child(_spacer(30))

	# 새 게임 버튼
	var new_game := _make_button("새 게임", COL_UP)
	new_game.pressed.connect(_on_new_game)
	_container.add_child(new_game)

	# 이어하기 버튼
	_load_button = _make_button("이어하기", COL_ACCENT)
	_load_button.disabled = not SaveManager.has_save()
	_load_button.pressed.connect(_on_load_game)
	_container.add_child(_load_button)

	# 버전
	_container.add_child(_spacer(30))
	var ver := Label.new()
	ver.text = "v0.1.0 — Prototype"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(ver)


func _on_new_game() -> void:
	GameManager.reset_player()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_load_game() -> void:
	SaveManager.load_game()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _btn_style(COL_PANEL, color, false))
	btn.add_theme_stylebox_override("hover", _btn_style(color, color, true))
	btn.add_theme_stylebox_override("pressed", _btn_style(color, color, false))
	btn.add_theme_stylebox_override("disabled", _btn_style(COL_PANEL, COL_TEXT_DIM, false))
	return btn


func _btn_style(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

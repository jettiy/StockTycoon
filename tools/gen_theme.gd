extends Node
## 임시 테마 생성기 — 부팅 시 자동 실행 후 자기 자신을 비활성화

const THEME_PATH := "res://assets/themes/dark_trading.tres"

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14

	var COL_PANEL := Color(0.094, 0.098, 0.110, 1)
	var COL_PANEL_LIGHT := Color(0.122, 0.126, 0.138, 1)
	var COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
	var COL_TEXT := Color(0.82, 0.82, 0.85, 1)
	var COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
	var COL_TEXT_BRIGHT := Color(0.95, 0.95, 0.97, 1)

	theme.set_stylebox("normal", "Button", _flat(COL_PANEL, 4))
	theme.set_stylebox("hover", "Button", _flat(COL_PANEL_LIGHT, 4))
	theme.set_stylebox("pressed", "Button", _flat(COL_ACCENT, 4))
	theme.set_stylebox("disabled", "Button", _flat(Color(0.06, 0.06, 0.07, 1), 4))
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", COL_TEXT_DIM)
	theme.set_font_size("font_size", "Button", 14)

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 14)

	theme.set_stylebox("normal", "OptionButton", _flat(COL_PANEL, 4))
	theme.set_color("font_color", "OptionButton", COL_TEXT)
	theme.set_font_size("font_size", "OptionButton", 13)
	theme.set_font_size("font_size", "SpinBox", 14)
	theme.set_stylebox("panel", "ScrollContainer", _flat(COL_PANEL, 0))
	theme.set_stylebox("panel", "PanelContainer", _flat(COL_PANEL, 6))

	var err := ResourceSaver.save(theme, THEME_PATH)
	if err == OK:
		print("Theme saved OK")
	else:
		print("Theme save failed: ", err)

	get_tree().quit()

func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s

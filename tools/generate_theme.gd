extends Node
## 헤드리스 테마 생성 스크립트

const THEME_PATH := "res://assets/themes/dark_trading.tres"

const COL_BG := Color(0.063, 0.067, 0.078, 1)
const COL_PANEL := Color(0.094, 0.098, 0.110, 1)
const COL_PANEL_LIGHT := Color(0.122, 0.126, 0.138, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
const COL_UP := Color(0.15, 0.65, 0.39, 1)
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)
const COL_TEXT := Color(0.82, 0.82, 0.85, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
const COL_TEXT_BRIGHT := Color(0.95, 0.95, 0.97, 1)
const COL_GOLD := Color(0.85, 0.70, 0.30, 1)


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 14

	# Button
	theme.set_stylebox("normal", "Button", _flat(COL_PANEL, 4))
	theme.set_stylebox("hover", "Button", _flat(COL_PANEL_LIGHT, 4))
	theme.set_stylebox("pressed", "Button", _flat(COL_ACCENT, 4))
	theme.set_stylebox("disabled", "Button", _flat(Color(0.06, 0.06, 0.07, 1), 4))
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", COL_TEXT_DIM)
	theme.set_font_size("font_size", "Button", 14)

	# Label
	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 14)

	# OptionButton
	theme.set_stylebox("normal", "OptionButton", _flat(COL_PANEL, 4))
	theme.set_stylebox("hover", "OptionButton", _flat(COL_PANEL_LIGHT, 4))
	theme.set_stylebox("pressed", "OptionButton", _flat(COL_ACCENT, 4))
	theme.set_color("font_color", "OptionButton", COL_TEXT)
	theme.set_font_size("font_size", "OptionButton", 13)

	# SpinBox
	theme.set_font_size("font_size", "SpinBox", 14)

	# ScrollContainer
	theme.set_stylebox("panel", "ScrollContainer", _flat(COL_PANEL, 0))

	# PanelContainer
	theme.set_stylebox("panel", "PanelContainer", _flat(COL_PANEL, 6))

	# HSeparator
	theme.set_stylebox("separator", "HSeparator", _flat(Color(0.12, 0.12, 0.14, 1), 0))
	theme.set_constant("separation", "HSeparator", 8)

	# 저장
	var err := ResourceSaver.save(theme, THEME_PATH)
	if err == OK:
		print("✅ Theme saved: ", THEME_PATH)
	else:
		push_error("Failed to save theme: %d" % err)

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

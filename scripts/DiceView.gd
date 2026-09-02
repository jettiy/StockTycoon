class_name DiceView extends Control

@export var bg_color: Color = Color("#1E2130")
@export var border_color: Color = Color("#35354a")
@export var pip_color: Color = Color("#E6E6E6")
@export var border_width: float = 2.0
@export var corner_radius: float = 8.0

var _value: int = 1

func _ready() -> void:
	custom_minimum_size = Vector2(80, 80)
	queue_redraw()

func set_value(v: int) -> void:
	_value = clamp(v, 1, 6)
	queue_redraw()

func get_value() -> int:
	return _value

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	# Border
	draw_rect(Rect2(Vector2(border_width * 0.5, border_width * 0.5), size - Vector2.ONE * border_width), border_color, false, border_width)

	# Pip positions: 80x80 grid with margin=20, spacing=40
	var margin: float = 20.0
	var spacing: float = 40.0
	var pip_radius: float = 6.0

	var tl := Vector2(margin, margin)
	var tc := Vector2(margin + spacing * 0.5, margin)
	var tr := Vector2(margin + spacing, margin)
	var ml := Vector2(margin, margin + spacing * 0.5)
	var mc := Vector2(margin + spacing * 0.5, margin + spacing * 0.5)
	var mr := Vector2(margin + spacing, margin + spacing * 0.5)
	var bl := Vector2(margin, margin + spacing)
	var bc := Vector2(margin + spacing * 0.5, margin + spacing)
	var br := Vector2(margin + spacing, margin + spacing)

	var pips: Array = []
	match _value:
		1:
			pips = [mc]
		2:
			pips = [tl, br]
		3:
			pips = [tl, mc, br]
		4:
			pips = [tl, tr, bl, br]
		5:
			pips = [tl, tr, mc, bl, br]
		6:
			pips = [tl, tr, ml, mr, bl, br]

	for pos in pips:
		draw_circle(pos, pip_radius, pip_color)

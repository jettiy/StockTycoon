extends Control
## Sparkline — 미니 가격 차트
## 종목별 가격 히스토리를 작은 라인 그래프로 렌더링

var _history: PackedFloat32Array = PackedFloat32Array()
var _line_color: Color = Color(0.15, 0.65, 0.39, 1)
var _fill_color: Color = Color(0.15, 0.65, 0.39, 0.15)
var _bg_color: Color = Color(0.04, 0.04, 0.05, 0.5)


func set_data(history: Array, is_up: bool) -> void:
	_history.clear()
	for v in history:
		_history.append(v)

	if is_up:
		_line_color = Color(0.15, 0.65, 0.39, 1)
		_fill_color = Color(0.15, 0.65, 0.39, 0.15)
	else:
		_line_color = Color(0.80, 0.27, 0.27, 1)
		_fill_color = Color(0.80, 0.27, 0.27, 0.15)

	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 2 or size.y < 2:
		return

	# 배경
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color, true)

	if _history.size() < 2:
		return

	# 최소/최대값
	var min_val: float = _history[0]
	var max_val: float = _history[0]
	for v in _history:
		min_val = minf(min_val, v)
		max_val = maxf(max_val, v)

	var range_val: float = max_val - min_val
	if range_val < 0.0001:
		range_val = 1.0  # 0으로 나누기 방지

	# 포인트 계산
	var points: PackedVector2Array = PackedVector2Array()
	var n: int = _history.size()
	for i in n:
		var x: float = float(i) / float(n - 1) * size.x
		var y: float = size.y - (_history[i] - min_val) / range_val * size.y
		# 약간의 패딩 (위아래 3px)
		y = clampf(y, 3.0, size.y - 3.0)
		points.append(Vector2(x, y))

	# 채우기 (아래쪽까지)
	var fill_points := points.duplicate()
	fill_points.append(Vector2(size.x, size.y))
	fill_points.append(Vector2(0, size.y))
	draw_colored_polygon(fill_points, _fill_color)

	# 라인
	if points.size() >= 2:
		for i in points.size() - 1:
			draw_line(points[i], points[i + 1], _line_color, 1.5, true)

	# 마지막 점 강조
	if points.size() > 0:
		var last := points[points.size() - 1]
		draw_circle(last, 2.0, _line_color)

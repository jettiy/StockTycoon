extends Control
## Sparkline — 미니 가격 차트
## 종목별 가격 히스토리를 작은 라인 그래프로 렌더링
## 각 Row는 자신의 stock_id 히스토리만 사용 (selected_stock_id와 무관)

var _history: PackedFloat32Array = PackedFloat32Array()
var _line_color: Color = COL_NEUTRAL
var _fill_color: Color = Color(0.54, 0.55, 0.59, 0.08)

# 배경: Row 배경보다 살짝 어두운 톤
var _bg_color: Color = Color(0.082, 0.098, 0.133, 0.9)  # #151922
var _grid_color: Color = Color(0.165, 0.180, 0.227, 0.5)  # #2A2E3A alpha

# 작업지시문 스펙 색상
const COL_UP := Color(0.188, 0.651, 0.416, 1)       # #28A66A
const COL_DOWN := Color(0.800, 0.271, 0.271, 1)     # #CC4545
const COL_NEUTRAL := Color(0.541, 0.553, 0.588, 1)  # #8A8D96


## 히스토리 데이터 설정 — Array를 PackedFloat32Array로 변환 후 redraw
func set_data(history: Array, is_up: bool) -> void:
	_history.clear()
	for v in history:
		_history.append(float(v))

	# 색상은 _draw에서 first vs last로 자동 판단하지만,
	# is_up 플래그가 명시적으로 주어지면 우선 적용
	if is_up:
		_line_color = COL_UP
		_fill_color = Color(COL_UP.r, COL_UP.g, COL_UP.b, 0.12)
	else:
		_line_color = COL_DOWN
		_fill_color = Color(COL_DOWN.r, COL_DOWN.g, COL_DOWN.b, 0.12)

	queue_redraw()


func _draw() -> void:
	var size := get_size()
	if size.x < 2 or size.y < 2:
		return

	# 배경
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color, true)

	# 희미한 기준선 (중앙 수평선)
	draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), _grid_color, 0.5, true)

	if _history.size() < 2:
		# 데이터 부족 시 중립 기준선만 표시 (빈 박스 방지)
		return

	# 최소/최대값 계산
	var min_val: float = _history[0]
	var max_val: float = _history[0]
	for v in _history:
		min_val = minf(min_val, v)
		max_val = maxf(max_val, v)

	var range_val: float = max_val - min_val

	# 최소 y-range 보장 — 데이터가 작게 움직여도 선이 납작해지지 않게
	# 평균값의 3%를 최소 범위로 설정
	var avg_val: float = (min_val + max_val) * 0.5
	var min_range: float = maxf(avg_val * 0.03, 1.0)
	if range_val < min_range:
		# 중심을 유지하면서 범위 확장
		var center: float = avg_val
		min_val = center - min_range * 0.5
		max_val = center + min_range * 0.5
		range_val = max_val - min_val

	# 변화율에 따라 색상 결정 (마지막 vs 첫번째)
	var first_v: float = _history[0]
	var last_v: float = _history[_history.size() - 1]
	var pct_change: float = (last_v - first_v) / first_v if first_v > 0 else 0.0
	if pct_change > 0.001:
		_line_color = COL_UP
		_fill_color = Color(COL_UP.r, COL_UP.g, COL_UP.b, 0.12)
	elif pct_change < -0.001:
		_line_color = COL_DOWN
		_fill_color = Color(COL_DOWN.r, COL_DOWN.g, COL_DOWN.b, 0.12)
	else:
		_line_color = COL_NEUTRAL
		_fill_color = Color(COL_NEUTRAL.r, COL_NEUTRAL.g, COL_NEUTRAL.b, 0.08)

	# 포인트 계산 — 상하 여백 4px
	var points: PackedVector2Array = PackedVector2Array()
	var n: int = _history.size()
	var pad: float = 4.0
	for i in n:
		var x: float = float(i) / float(n - 1) * size.x
		var y: float = size.y - pad - (_history[i] - min_val) / range_val * (size.y - pad * 2.0)
		points.append(Vector2(x, y))

	# 채우기 (아래쪽까지)
	var fill_points := points.duplicate()
	fill_points.append(Vector2(size.x, size.y))
	fill_points.append(Vector2(0, size.y))
	draw_colored_polygon(fill_points, _fill_color)

	# 라인 — 두께 2.0px (작업지시문: 1.5~2px)
	if points.size() >= 2:
		for i in points.size() - 1:
			draw_line(points[i], points[i + 1], _line_color, 2.0, true)

	# 마지막 점 강조
	if points.size() > 0:
		var last := points[points.size() - 1]
		draw_circle(last, 2.5, _line_color)

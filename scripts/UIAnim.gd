extends Control
## UIAnimationHelper — 재사용 가능한 UI 애니메이션 유틸리티

class_name UIAnim

const COL_FLASH_UP := Color(0.15, 0.65, 0.39, 0.25)
const COL_FLASH_DOWN := Color(0.80, 0.27, 0.27, 0.25)


## 컨트롤을 잠깐 플래시 (가격 변동 시)
static func flash(node: Control, color: Color, duration: float = 0.3) -> void:
	var original := node.modulate
	var flash_mod := Color(
		minf(original.r + color.r * 2, 1.0),
		minf(original.g + color.g * 2, 1.0),
		minf(original.b + color.b * 2, 1.0),
		1.0
	)
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", flash_mod, duration * 0.3)
	tw.tween_property(node, "modulate", original, duration * 0.7)


## 가격 상승 플래시 (초록)
static func flash_up(node: Control, duration: float = 0.3) -> void:
	flash(node, COL_FLASH_UP, duration)


## 가격 하락 플래시 (빨강)
static func flash_down(node: Control, duration: float = 0.3) -> void:
	flash(node, COL_FLASH_DOWN, duration)


## 버튼 펄스 (클릭 피드백)
static func pulse(node: Control, scale: float = 1.05, duration: float = 0.15) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(scale, scale), duration * 0.4)
	tw.tween_property(node, "scale", Vector2.ONE, duration * 0.6)
	node.scale = Vector2.ONE


## 노드가 위에서 아래로 미끄러지며 나타남
static func slide_in_from_top(node: Control, distance: float = 20.0, duration: float = 0.2) -> void:
	var orig_y := node.position.y
	node.position.y = orig_y - distance
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position:y", orig_y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate:a", 1.0, duration)


## 노드가 아래에서 위로 미끄러지며 나타남
static func slide_in_from_bottom(node: Control, distance: float = 20.0, duration: float = 0.2) -> void:
	var orig_y := node.position.y
	node.position.y = orig_y + distance
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position:y", orig_y, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(node, "modulate:a", 1.0, duration)


## 패널이 스케일 인하며 나타남
static func pop_in(node: Control, duration: float = 0.2) -> void:
	node.scale = Vector2(0.8, 0.8)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(node, "modulate:a", 1.0, duration * 0.5)


## 패널이 사라짐
static func fade_out(node: Control, duration: float = 0.15) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, duration)


## 텍스트가 타자기처럼 나타남
static func typewriter(label: Label, full_text: String, char_delay: float = 0.02) -> void:
	label.text = ""
	var chars := full_text.length()
	for i in range(chars):
		label.text = full_text.substr(0, i + 1)
		await label.get_tree().create_timer(char_delay).timeout


## 진동 (에러/경고)
static func shake(node: Control, intensity: float = 5.0, duration: float = 0.3) -> void:
	var orig := node.position
	var tw := node.create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var decay := 1.0 - float(i) / float(steps)
		tw.tween_property(node, "position:x", orig.x + dir * intensity * decay, 0.05)
	tw.tween_property(node, "position", orig, 0.05)

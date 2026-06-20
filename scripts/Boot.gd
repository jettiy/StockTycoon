extends Control
## Boot — 시작 화면 + 오프라인 보상 팝업

const MAIN_SCENE := "res://scenes/main.tscn"

# 색상
const COL_BG := Color(0.063, 0.067, 0.078, 1)
const COL_PANEL := Color(0.106, 0.110, 0.122, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
const COL_UP := Color(0.15, 0.65, 0.39, 1)
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)
const COL_TEXT := Color(0.82, 0.82, 0.85, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
const COL_GOLD := Color(0.85, 0.70, 0.30, 1)

var _container: VBoxContainer
var _load_button: Button
var _popup: PanelContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_CENTER)
	_container.custom_minimum_size = Vector2(500, 400)
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 16)
	add_child(_container)

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

	_container.add_child(_spacer(20))

	var desc := Label.new()
	desc.text = "증권가에 취직한 청년의 주식 투자 인생"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(desc)

	_container.add_child(_spacer(30))

	var new_game := _make_button("새 게임", COL_UP)
	new_game.pressed.connect(_on_new_game)
	_container.add_child(new_game)

	_load_button = _make_button("이어하기", COL_ACCENT)
	_load_button.disabled = not SaveManager.has_save()
	_load_button.pressed.connect(_on_load_game)
	_container.add_child(_load_button)

	_container.add_child(_spacer(30))

	var ver := Label.new()
	ver.text = "v0.2.0 — Phase 2"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", COL_TEXT_DIM)
	_container.add_child(ver)


func _on_new_game() -> void:
	GameManager.reset_player()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_load_game() -> void:
	SaveManager.load_game()
	var rewards := SaveManager.calculate_offline_rewards()

	if rewards["cash"] > 0:
		_show_offline_popup(rewards)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)


func _show_offline_popup(rewards: Dictionary) -> void:
	# 오버레이
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.custom_minimum_size = Vector2(450, 300)
	_popup.add_theme_stylebox_override("panel", _style_border(COL_PANEL, COL_ACCENT, 12))
	_popup.z_index = 51
	add_child(_popup)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.offset_left = 24
	vbox.offset_top = 24
	vbox.offset_right = -24
	vbox.offset_bottom = -24
	_popup.add_child(vbox)

	# 타이틀
	var title := Label.new()
	title.text = "오프라인 보상"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(title)

	# 시간
	var hours: float = rewards["time_seconds"] / 3600.0
	var mins := int(rewards["time_seconds"] / 60.0) % 60
	var time_label := Label.new()
	time_label.text = "부재 시간: %d시간 %d분" % [int(hours), mins]
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(time_label)

	vbox.add_child(_spacer(8))

	# 현금 보상
	var cash_label := Label.new()
	cash_label.text = "+ %s" % _fmt_won(rewards["cash"])
	cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cash_label.add_theme_font_size_override("font_size", 28)
	cash_label.add_theme_color_override("font_color", COL_UP)
	vbox.add_child(cash_label)

	# 자동매매 정보
	if rewards.get("auto_trades", 0) > 0:
		var auto_label := Label.new()
		auto_label.text = "자동매매: %d건 실행" % rewards["auto_trades"]
		auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		auto_label.add_theme_font_size_override("font_size", 14)
		auto_label.add_theme_color_override("font_color", COL_ACCENT)
		vbox.add_child(auto_label)

	vbox.add_child(_spacer(16))

	# 수령 버튼
	var claim_btn := Button.new()
	claim_btn.text = "수령하고 계속하기"
	claim_btn.custom_minimum_size = Vector2(300, 44)
	claim_btn.add_theme_font_size_override("font_size", 16)
	claim_btn.add_theme_color_override("font_color", COL_UP)
	claim_btn.add_theme_stylebox_override("normal", _style_border(COL_PANEL, COL_UP, 6))
	claim_btn.add_theme_stylebox_override("hover", _style_border(Color(0.10, 0.15, 0.10, 1), COL_UP, 6))
	claim_btn.pressed.connect(
		func():
			SaveManager.apply_offline_rewards()
			get_tree().change_scene_to_file(MAIN_SCENE)
	)
	vbox.add_child(claim_btn)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", _style_border(COL_PANEL, color, 6))
	btn.add_theme_stylebox_override("hover", _style_border(color, color, 6))
	btn.add_theme_stylebox_override("pressed", _style_border(color, color, 6))
	btn.add_theme_stylebox_override("disabled", _style_border(COL_PANEL, COL_TEXT_DIM, 6))
	return btn


func _style_flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


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
	var abs_amount := absf(amount)
	if abs_amount >= 100_000_000:
		return "%.2f억원" % (amount / 100_000_000)
	elif abs_amount >= 10_000_000:
		return "%.1f천만원" % (amount / 10_000_000)
	return "%,.0f원" % amount

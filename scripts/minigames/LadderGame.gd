class_name LadderGame extends Control
## 사다리타기 미니게임 (실시간 퀸)
## 독립 Control로 분리 — MainGame에서 add_child 후 game_finished 시그널로 결과 전달

signal game_finished(result: Dictionary)  # {won: bool, payout: float, npc_id: String}

# ─── 색상 상수 (MainGame 복사) ───
const COL_NPC := Color(0.91, 0.11, 0.55, 1)       # #E81C8C — 핑크
const COL_USER := Color(0.13, 0.78, 0.85, 1)      # #21C7D9 — 시안
const COL_WIN := Color(0.16, 0.65, 0.42, 1)        # #28A66A — 승리
const COL_LOSE := Color(0.80, 0.27, 0.27, 1)        # #CC4545 — 패배
const COL_PANEL := Color(0.165, 0.165, 0.239, 1)   # #2A2A3D
const COL_BORDER := Color(0.239, 0.239, 0.333, 1)  # #3D3D55
const COL_TEXT_DIM := Color(0.55, 0.55, 0.62, 1)   # #8C8C9E
const COL_TEXT_BRIGHT := Color(0.88, 0.88, 0.92, 1) # #E0E0EB
const COL_DOWN := Color(1.0, 0.44, 0.26, 1)        # #FF7043
const OVERLAY_ALPHA := 0.75

# ─── 외부에서 설정 ───
var npc_id: String = ""
var show_toast_callback: Callable = func(_msg: String, _color: Color): pass
var refresh_npc_callback: Callable = func(): pass
var pixel_font: FontFile = null

# ─── 내부 상태 ───
var _layer: CanvasLayer = null
var _bet: float = 0.0
var _outcomes: Array = []
var _user_choice: int = -1
var _settled: bool = false
var _settled_shown: bool = false

func _ready() -> void:
	_show_ladder_game()

func _show_ladder_game() -> void:
	GameClockManager.pause_for_event()
	var npc := NPCManager.get_npc(npc_id)
	var cash: float = GameManager.get_cash()
	var daily_plays: int = NPCManager.get_rival_plays_today(npc_id)
	var max_plays: int = NPCManager.RIVAL_MAX_PLAYS_PER_DAY

	if _layer:
		_layer.queue_free()
		_layer = null
	_outcomes.clear()
	_user_choice = -1
	_settled = false

	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, OVERLAY_ALPHA)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 440)
	var ps := StyleBoxFlat.new()
	ps.bg_color = COL_PANEL
	ps.border_color = COL_BORDER
	ps.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(m)
	m.add_child(vbox)

	var title := Label.new()
	title.text = npc.get("name", "래더 퀸") + " - 사다리타기"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_NPC)
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	vbox.add_child(title)

	var remain := Label.new()
	remain.text = "남은 대결: %d/%d" % [max_plays - daily_plays, max_plays]
	remain.add_theme_font_size_override("font_size", 13)
	remain.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(remain)

	vbox.add_child(_np_spacer(4))

	# 베팅
	var bet_hbox := HBoxContainer.new()
	bet_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(bet_hbox)

	var bet_label := Label.new()
	bet_label.text = "베팅금"
	bet_label.add_theme_font_size_override("font_size", 14)
	bet_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	bet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bet_hbox.add_child(bet_label)

	var bet_edit := SpinBox.new()
	bet_edit.name = "BetSpin"
	bet_edit.min_value = 10000
	bet_edit.max_value = mini(10000000, maxi(10000, int(cash * 0.1)))
	bet_edit.step = 10000
	bet_edit.value = clampi(int(cash * 0.05), 10000, bet_edit.max_value)
	bet_edit.custom_minimum_size = Vector2(140, 36)
	bet_edit.value_changed.connect(_on_ladder_bet_changed)
	bet_hbox.add_child(bet_edit)

	var cash_label := Label.new()
	cash_label.name = "CashLabel"
	cash_label.text = "보유: %s" % UIUtil._fmt_won(cash)
	cash_label.add_theme_font_size_override("font_size", 13)
	cash_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bet_hbox.add_child(cash_label)

	var bet_spacer := Control.new()
	bet_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_hbox.add_child(bet_spacer)

	var pct_row := HBoxContainer.new()
	pct_row.add_theme_constant_override("separation", 4)
	vbox.add_child(pct_row)
	for pct in [10, 25, 50]:
		var pbtn := Button.new()
		pbtn.text = "%d%%" % pct
		pbtn.custom_minimum_size = Vector2(0, 28)
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.add_theme_font_size_override("font_size", 12)
		pbtn.pressed.connect(_on_ladder_quick_bet.bind(pct, bet_edit, cash))
		pct_row.add_child(pbtn)
	var max_btn := Button.new()
	max_btn.text = "MAX"
	max_btn.custom_minimum_size = Vector2(0, 28)
	max_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_btn.add_theme_font_size_override("font_size", 12)
	max_btn.pressed.connect(_on_ladder_quick_bet.bind(100, bet_edit, cash))
	pct_row.add_child(max_btn)

	vbox.add_child(_np_spacer(8))

	# 색상 범례
	var legend_row := HBoxContainer.new()
	legend_row.name = "LegendRow"
	legend_row.add_theme_constant_override("separation", 16)
	legend_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(legend_row)

	var p_legend_box := HBoxContainer.new()
	p_legend_box.add_theme_constant_override("separation", 6)
	legend_row.add_child(p_legend_box)
	var p_swatch := ColorRect.new()
	p_swatch.color = COL_USER
	p_swatch.custom_minimum_size = Vector2(12, 12)
	p_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p_legend_box.add_child(p_swatch)
	var p_legend_text := Label.new()
	p_legend_text.text = "플레이어"
	p_legend_text.add_theme_font_size_override("font_size", 12)
	p_legend_text.add_theme_color_override("font_color", COL_USER)
	p_legend_box.add_child(p_legend_text)

	var q_legend_box := HBoxContainer.new()
	q_legend_box.add_theme_constant_override("separation", 6)
	legend_row.add_child(q_legend_box)
	var q_swatch := ColorRect.new()
	q_swatch.color = COL_NPC
	q_swatch.custom_minimum_size = Vector2(12, 12)
	q_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	q_legend_box.add_child(q_swatch)
	var q_legend_text := Label.new()
	q_legend_text.text = "래더 퀸"
	q_legend_text.add_theme_font_size_override("font_size", 12)
	q_legend_text.add_theme_color_override("font_color", COL_NPC)
	q_legend_box.add_child(q_legend_text)

	vbox.add_child(_np_spacer(4))

	# 사다리 영역
	var ladder_area := Control.new()
	ladder_area.name = "LadderArea"
	ladder_area.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(ladder_area)

	# A/B 선택지 (2개)
	var choice_row := HBoxContainer.new()
	choice_row.name = "ChoiceRow"
	choice_row.add_theme_constant_override("separation", 8)
	vbox.add_child(choice_row)
	var labels := ["A", "B"]
	for i in 2:
		var cbtn := Button.new()
		cbtn.text = labels[i]
		cbtn.custom_minimum_size = Vector2(0, 44)
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.add_theme_font_size_override("font_size", 18)
		cbtn.pressed.connect(_on_ladder_choice.bind(i))
		cbtn.name = "ChoiceBtn%d" % i
		choice_row.add_child(cbtn)

	var start_btn := Button.new()
	start_btn.name = "StartBtn"
	start_btn.text = "선택지를 골라주세요"
	start_btn.disabled = true
	start_btn.custom_minimum_size = Vector2(0, 46)
	start_btn.add_theme_font_size_override("font_size", 17)
	start_btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	start_btn.pressed.connect(_on_ladder_start.bind(ladder_area, choice_row))
	vbox.add_child(start_btn)

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.text = ""
	result_label.add_theme_font_size_override("font_size", 16)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		result_label.add_theme_font_override("font", pixel_font)
	vbox.add_child(result_label)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.name = "CloseBtn"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_on_ladder_close)
	vbox.add_child(close_btn)

	overlay.gui_input.connect(
		func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				_on_ladder_close()
	)

	if daily_plays >= max_plays:
		start_btn.text = "대결 횟수 초과 (%d/%d)" % [max_plays, max_plays]
		for child in choice_row.get_children():
			child.disabled = true
		bet_edit.editable = false
		close_btn.visible = true

	if cash < 10000:
		start_btn.text = "베팅금 부족 (최소 1만원 필요)"
		for child in choice_row.get_children():
			child.disabled = true
		bet_edit.editable = false
		close_btn.visible = true


func _np_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _on_ladder_bet_changed(_v: float) -> void:
	if _layer:
		var cash: float = GameManager.get_cash()
		var cl: Label = _layer.find_child("CashLabel", true, false)
		if cl:
			cl.text = "보유: %s" % UIUtil._fmt_won(cash)

func _on_ladder_quick_bet(pct: int, spin: SpinBox, cash: float) -> void:
	if pct >= 100:
		spin.value = clampi(int(cash * 0.1), spin.min_value, spin.max_value)
	else:
		spin.value = clampi(int(cash * pct / 100.0), spin.min_value, spin.max_value)

func _on_ladder_choice(lane: int) -> void:
	_user_choice = lane
	var user_color := COL_USER
	if _layer:
		var row: Node = _layer.find_child("ChoiceRow", true, false)
		if row:
			for i in row.get_child_count():
				var btn := row.get_child(i) as Button
				if btn:
					btn.add_theme_color_override("font_color", user_color if i == lane else COL_TEXT_BRIGHT)
					if i == lane:
						var sb := StyleBoxFlat.new()
						sb.bg_color = Color(0.10, 0.20, 0.24, 1)
						sb.set_border_width_all(2)
						sb.border_color = user_color
						btn.add_theme_stylebox_override("normal", sb)
					else:
						btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
		var sb: Button = _layer.find_child("StartBtn", true, false)
		if sb:
			sb.text = "사다리 타기 시작!"
			sb.disabled = false
			sb.add_theme_color_override("font_color", user_color)

func _on_ladder_start(ladder_area: Control, choice_row: HBoxContainer) -> void:
	if _settled:
		return
	if _user_choice < 0:
		return

	var bet_edit: SpinBox = _layer.find_child("BetSpin", true, false)
	if not bet_edit:
		return
	_bet = bet_edit.value

	var cash: float = GameManager.get_cash()
	if _bet < 10000:
		show_toast_callback.call("최소 베팅 1만원", COL_DOWN)
		return
	if cash < _bet:
		show_toast_callback.call("잔액 부족", COL_DOWN)
		return

	GameManager.add_cash(-_bet)
	_settled = true

	for child in choice_row.get_children():
		child.disabled = true
	choice_row.visible = false
	var sb: Button = _layer.find_child("StartBtn", true, false)
	if sb:
		sb.disabled = true
		sb.text = "진행 중..."

	# 결과 결정 — 2개 선택지 (당첨 1, 실패 1)
	var outcomes: Array = ["실패", "당첨"]
	outcomes.shuffle()
	_outcomes = outcomes
	var user_result: String = outcomes[_user_choice]

	# NPC는 유저와 반대
	var npc_choice: int = 1 - _user_choice

	# 애니메이션 내부에서 outcomes 전달
	_ladder_draw_and_animate(ladder_area, _user_choice, npc_choice, outcomes)
	await get_tree().create_timer(3.0).timeout
	_ladder_apply_result(user_result, outcomes, _user_choice, npc_choice)

## 사다리 그리기 + 마커 이동 애니메이션
func _ladder_draw_and_animate(area: Control, user_lane: int, npc_lane: int, outcomes: Array) -> void:
	for child in area.get_children():
		child.queue_free()

	var h := 160.0
	var area_w := area.size.x if area.size.x > 0 else 432.0
	var lane_w := area_w / 2.0
	var user_color := COL_USER
	var npc_color := COL_NPC
	var line_color := COL_BORDER

	var crosses: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ladder_%d" % Time.get_ticks_msec())
	var heights := [0.22, 0.45, 0.68, 0.85]
	heights.shuffle()
	var cross_count := rng.randi_range(2, 3)
	for ci in cross_count:
		crosses.append({"y": heights[ci]})
	crosses.sort_custom(func(a, b): return a["y"] < b["y"])

	for i in 2:
		var cx: float = lane_w * (float(i) + 0.5)
		var vline := ColorRect.new()
		vline.color = line_color
		vline.position = Vector2(cx - 1, 0)
		vline.size = Vector2(2, h)
		area.add_child(vline)

	for cross in crosses:
		var cy: float = float(cross["y"]) * h
		var hline := ColorRect.new()
		hline.color = line_color
		hline.position = Vector2(lane_w * 0.5, cy - 1)
		hline.size = Vector2(lane_w, 2)
		area.add_child(hline)

	for i in 2:
		var cx: float = lane_w * (float(i) + 0.5)
		var lbl := Label.new()
		lbl.text = ["A", "B"][i]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		lbl.position = Vector2(cx - 8, -18)
		area.add_child(lbl)

	var user_path_data := _ladder_calc_path_segments(user_lane, crosses, lane_w, h)
	var npc_path_data := _ladder_calc_path_segments(npc_lane, crosses, lane_w, h)

	var user_marker := ColorRect.new()
	user_marker.color = user_color
	user_marker.size = Vector2(10, 10)
	user_marker.position = Vector2(lane_w * (float(user_lane) + 0.5) - 5, -5)
	area.add_child(user_marker)

	var npc_marker := ColorRect.new()
	npc_marker.color = npc_color
	npc_marker.size = Vector2(10, 10)
	npc_marker.position = Vector2(lane_w * (float(npc_lane) + 0.5) - 5, -5)
	npc_marker.visible = false
	area.add_child(npc_marker)

	_ladder_animate_path(user_marker, user_path_data["segments"], user_color, area)

	await get_tree().create_timer(0.15).timeout
	npc_marker.visible = true
	_ladder_animate_path(npc_marker, npc_path_data["segments"], npc_color, area)

func _ladder_calc_path_segments(start_col: int, crosses: Array, lane_w: float, h: float) -> Dictionary:
	var segments: Array = []
	var col: int = start_col
	var x: float = lane_w * (float(col) + 0.5)
	var cur_y: float = 0.0

	for cross in crosses:
		var cy: float = float(cross["y"]) * h
		segments.append({"type": "vertical", "from": Vector2(x, cur_y), "to": Vector2(x, cy)})
		col = 1 - col
		var new_x: float = lane_w * (float(col) + 0.5)
		segments.append({"type": "horizontal", "from": Vector2(x, cy), "to": Vector2(new_x, cy)})
		x = new_x
		cur_y = cy

	segments.append({"type": "vertical", "from": Vector2(x, cur_y), "to": Vector2(x, h)})
	return {"segments": segments, "end_col": col}

func _ladder_animate_path(marker: Control, segments: Array, trail_color: Color, area: Control) -> void:
	for seg in segments:
		var duration: float = _ladder_seg_duration(seg)
		var target_pos: Vector2 = seg["to"] - marker.size / 2.0
		var tw := create_tween()
		tw.tween_property(marker, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
		_ladder_add_trail(area, seg, trail_color)

func _ladder_seg_duration(seg: Dictionary) -> float:
	var dist: float = seg["from"].distance_to(seg["to"])
	if seg["type"] == "vertical":
		return clampf(dist / 500.0, 0.15, 0.28)
	else:
		return clampf(dist / 500.0, 0.12, 0.18)

func _ladder_add_trail(area: Control, seg: Dictionary, color: Color) -> void:
	var trail := ColorRect.new()
	trail.color = color
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a: Vector2 = seg["from"]
	var b: Vector2 = seg["to"]
	if absf(b.x - a.x) < 1.0:
		trail.position = Vector2(a.x - 1.5, minf(a.y, b.y))
		trail.size = Vector2(3, absf(b.y - a.y))
	else:
		trail.position = Vector2(minf(a.x, b.x), a.y - 1.5)
		trail.size = Vector2(absf(b.x - a.x), 3)
	area.add_child(trail)

func _ladder_calc_path(start_lane: int, crosses: Array, lane_w: float, h: float) -> Array:
	var path: Array = []
	var lane := start_lane
	var x: float = lane_w * (float(lane) + 0.5)
	path.append(Vector2(x, 0))

	for cross in crosses:
		var cy: float = float(cross["y"]) * h
		path.append(Vector2(x, cy))
		lane = 1 - lane
		x = lane_w * (float(lane) + 0.5)
		path.append(Vector2(x, cy))

	path.append(Vector2(x, h))
	return path

func _ladder_apply_result(user_result: String, outcomes: Array, user_lane: int, npc_lane: int) -> void:
	if not _layer:
		return

	var won: bool = (user_result == "당첨")
	var payout: float = 0.0
	if won:
		payout = _bet * 3.0
		GameManager.add_cash(payout)

	var result_lbl: Label = _layer.find_child("ResultLabel", true, false)
	if result_lbl:
		var user_outcome: String = outcomes[user_lane]
		var npc_outcome: String = outcomes[npc_lane]
		result_lbl.text = "플레이어: %s | 래더 퀸: %s" % [user_outcome, npc_outcome]
		if won:
			result_lbl.text += "\n+%s" % UIUtil._fmt_won(payout)
			result_lbl.add_theme_color_override("font_color", COL_WIN)
		else:
			result_lbl.text += "\n-%s" % UIUtil._fmt_won(_bet)
			result_lbl.add_theme_color_override("font_color", COL_LOSE)

	var start_btn: Button = _layer.find_child("StartBtn", true, false)
	if start_btn:
		start_btn.text = "확인"
		start_btn.disabled = false
		if start_btn.is_connected("pressed", _on_ladder_start):
			start_btn.pressed.disconnect(_on_ladder_start)
		if not start_btn.is_connected("pressed", _on_ladder_close):
			start_btn.pressed.connect(_on_ladder_close)

	_settled_shown = true
	NPCManager.record_rival_game_result(npc_id, won)
	var desc: String = "+%s" % UIUtil._fmt_won(payout) if won else "-%s" % UIUtil._fmt_won(_bet)
	show_toast_callback.call("플레이어 %s! %s" % ["당첨" if won else "실패", desc], COL_WIN if won else COL_LOSE)
	refresh_npc_callback.call()

	# 시그널 발송
	game_finished.emit({"won": won, "payout": payout, "npc_id": npc_id})

func _on_ladder_close() -> void:
	if _settled and _bet > 0 and not _settled_shown:
		GameManager.add_cash(_bet)
		show_toast_callback.call("대결 중단, 베팅금 반환", COL_TEXT_DIM)
		NPCManager.record_rival_game_result(npc_id, false)
		refresh_npc_callback.call()
	GameClockManager.resume_from_event()
	queue_free()

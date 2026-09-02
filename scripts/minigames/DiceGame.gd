class_name DiceGame extends Control
## 주사위 미니게임 (알고리즘 K)
## 독립 Control로 분리 — MainGame에서 add_child 후 game_finished 시그널로 결과 전달

signal game_finished(result: Dictionary)  # {won: bool, payout: float, npc_id: String}

const UIAnim := preload("res://scripts/UIAnim.gd")

# ─── 색상 상수 (MainGame 복사) ───
const COL_NPC := Color(0.91, 0.11, 0.55, 1)       # #E81C8C
const COL_USER := Color(0.13, 0.78, 0.85, 1)      # #21C7D9
const COL_WIN := Color(0.16, 0.65, 0.42, 1)        # #28A66A
const COL_LOSE := Color(0.80, 0.27, 0.27, 1)        # #CC4545
const COL_TIE := Color(0.85, 0.70, 0.30, 1)        # #D9B34D
const COL_PANEL := Color(0.165, 0.165, 0.239, 1)   # #2A2A3D
const COL_BORDER := Color(0.239, 0.239, 0.333, 1)
const COL_TEXT_DIM := Color(0.55, 0.55, 0.62, 1)
const COL_TEXT_BRIGHT := Color(0.88, 0.88, 0.92, 1)
const COL_DOWN := Color(1.0, 0.44, 0.26, 1)
const OVERLAY_ALPHA := 0.75

# ─── 외부에서 설정 ───
var npc_id: String = ""
var show_toast_callback: Callable = func(_msg: String, _color: Color): pass
var refresh_npc_callback: Callable = func(): pass
var pixel_font: FontFile = null

# ─── 내부 상태 ───
var _layer: CanvasLayer = null
var _bet: float = 0.0
var _settled: bool = false
enum DiceState { IDLE, ROLLING_PLAYER, ROLLING_NPC, RESOLVED, CLOSED }
var _dice_state: int = DiceState.IDLE
var _dice_result_shown: bool = false
var _dice_reroll_count: int = 0

func _ready() -> void:
	_show_dice_game()

func _show_dice_game() -> void:
	GameClockManager.pause_for_event()
	var npc := NPCManager.get_npc(npc_id)
	var cash: float = GameManager.get_cash()
	var daily_plays: int = NPCManager.get_rival_plays_today(npc_id)
	var max_plays: int = NPCManager.RIVAL_MAX_PLAYS_PER_DAY

	if _layer:
		_layer.queue_free()
		_layer = null
	_bet = 0.0
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
	panel.custom_minimum_size = Vector2(480, 520)
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

	# 타이틀
	var title := Label.new()
	title.text = npc.get("name", "알고리즘 K") + " - 주사위 대결"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_NPC)
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	vbox.add_child(title)

	# 설명
	var desc_lbl := Label.new()
	desc_lbl.text = "주사위 2개를 굴려 합계가 높은 쪽이 승리합니다."
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(desc_lbl)

	# 남은 횟수
	var remain := Label.new()
	remain.text = "남은 대결: %d/%d" % [max_plays - daily_plays, max_plays]
	remain.add_theme_font_size_override("font_size", 13)
	remain.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(remain)

	vbox.add_child(_np_spacer(4))

	# 베팅 행
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
	bet_edit.name = "DiceBetSpin"
	bet_edit.min_value = 10000
	bet_edit.max_value = mini(10000000, maxi(10000, int(cash * 0.1)))
	bet_edit.step = 10000
	bet_edit.value = clampi(int(cash * 0.05), 10000, bet_edit.max_value)
	bet_edit.custom_minimum_size = Vector2(140, 36)
	bet_edit.value_changed.connect(_on_dice_bet_changed)
	bet_hbox.add_child(bet_edit)

	var cash_label := Label.new()
	cash_label.name = "DiceCashLabel"
	cash_label.text = "보유: %s" % UIUtil._fmt_won(cash)
	cash_label.add_theme_font_size_override("font_size", 13)
	cash_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bet_hbox.add_child(cash_label)

	var bet_spacer := Control.new()
	bet_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_hbox.add_child(bet_spacer)

	vbox.add_child(_np_spacer(8))

	# 주사위 영역
	var dice_hbox := HBoxContainer.new()
	dice_hbox.name = "DiceArea"
	dice_hbox.add_theme_constant_override("separation", 24)
	dice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(dice_hbox)

	# 유저존
	var user_zone := VBoxContainer.new()
	user_zone.name = "UserZone"
	user_zone.add_theme_constant_override("separation", 4)
	user_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_hbox.add_child(user_zone)

	var user_title_lbl := Label.new()
	user_title_lbl.text = "플레이어"
	user_title_lbl.add_theme_font_size_override("font_size", 14)
	user_title_lbl.add_theme_color_override("font_color", COL_USER)
	user_zone.add_child(user_title_lbl)

	var user_dice_hbox := HBoxContainer.new()
	user_dice_hbox.name = "UserDice"
	user_dice_hbox.add_theme_constant_override("separation", 6)
	user_zone.add_child(user_dice_hbox)

	var user_dice1 := _make_dice_view(COL_USER)
	user_dice1.name = "UserDie1"
	user_dice1.visible = false
	user_dice_hbox.add_child(user_dice1)

	var user_dice2 := _make_dice_view(COL_USER)
	user_dice2.name = "UserDie2"
	user_dice2.visible = false
	user_dice_hbox.add_child(user_dice2)

	var user_total_lbl := Label.new()
	user_total_lbl.name = "UserTotal"
	user_total_lbl.text = "합계: 0"
	user_total_lbl.add_theme_font_size_override("font_size", 18)
	user_total_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	user_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		user_total_lbl.add_theme_font_override("font", pixel_font)
	user_zone.add_child(user_total_lbl)

	# VS 중앙
	var vs_zone := VBoxContainer.new()
	vs_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_hbox.add_child(vs_zone)
	var vs_lbl := Label.new()
	vs_lbl.text = "VS"
	vs_lbl.add_theme_font_size_override("font_size", 24)
	vs_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	if pixel_font:
		vs_lbl.add_theme_font_override("font", pixel_font)
	vs_zone.add_child(vs_lbl)

	# NPC존
	var npc_zone := VBoxContainer.new()
	npc_zone.name = "NpcZone"
	npc_zone.add_theme_constant_override("separation", 4)
	npc_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_hbox.add_child(npc_zone)

	var npc_title_lbl := Label.new()
	npc_title_lbl.text = npc.get("name", "알고리즘 K")
	npc_title_lbl.add_theme_font_size_override("font_size", 14)
	npc_title_lbl.add_theme_color_override("font_color", COL_NPC)
	npc_zone.add_child(npc_title_lbl)

	var npc_dice_hbox := HBoxContainer.new()
	npc_dice_hbox.name = "NpcDice"
	npc_dice_hbox.add_theme_constant_override("separation", 6)
	npc_zone.add_child(npc_dice_hbox)

	var npc_dice1 := _make_dice_view(COL_NPC)
	npc_dice1.name = "NpcDie1"
	npc_dice1.visible = false
	npc_dice_hbox.add_child(npc_dice1)

	var npc_dice2 := _make_dice_view(COL_NPC)
	npc_dice2.name = "NpcDie2"
	npc_dice2.visible = false
	npc_dice_hbox.add_child(npc_dice2)

	var npc_total_lbl := Label.new()
	npc_total_lbl.name = "NpcTotal"
	npc_total_lbl.text = "합계: ?"
	npc_total_lbl.add_theme_font_size_override("font_size", 18)
	npc_total_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	npc_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		npc_total_lbl.add_theme_font_override("font", pixel_font)
	npc_zone.add_child(npc_total_lbl)

	vbox.add_child(_np_spacer(8))

	# "대결!" 버튼
	var start_btn := Button.new()
	start_btn.name = "DiceStartBtn"
	start_btn.text = "대결!"
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.add_theme_font_size_override("font_size", 17)
	start_btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	start_btn.pressed.connect(_on_dice_start)
	vbox.add_child(start_btn)

	# 결과 라벨
	var result_lbl := Label.new()
	result_lbl.name = "DiceResultLabel"
	result_lbl.text = ""
	result_lbl.add_theme_font_size_override("font_size", 16)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		result_lbl.add_theme_font_override("font", pixel_font)
	vbox.add_child(result_lbl)

	# "닫기" 버튼
	var close_btn := Button.new()
	close_btn.name = "DiceCloseBtn"
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.visible = false
	close_btn.pressed.connect(_on_dice_close)
	vbox.add_child(close_btn)

	overlay.gui_input.connect(
		func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				_on_dice_close()
	)

	if daily_plays >= max_plays:
		start_btn.text = "대결 횟수 초과 (%d/%d)" % [max_plays, max_plays]
		start_btn.disabled = true
		bet_edit.editable = false
		close_btn.visible = true

	if cash < 10000:
		start_btn.text = "베팅금 부족 (최소 1만원 필요)"
		start_btn.disabled = true
		bet_edit.editable = false
		close_btn.visible = true
	UIAnim.pop_in(panel)


func _np_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _make_dice_view(border_col: Color = COL_BORDER) -> DiceView:
	var dv := DiceView.new()
	dv.border_color = border_col
	return dv

func _on_dice_bet_changed(_v: float) -> void:
	if _layer:
		var cash: float = GameManager.get_cash()
		var cl: Label = _layer.find_child("DiceCashLabel", true, false)
		if cl:
			cl.text = "보유: %s" % UIUtil._fmt_won(cash)

func _on_dice_start() -> void:
	if not _layer:
		return
	if _settled:
		return

	var bet_edit: SpinBox = _layer.find_child("DiceBetSpin", true, false)
	if not bet_edit:
		return
	var bet: float = bet_edit.value

	var cash: float = GameManager.get_cash()
	if bet < 10000:
		show_toast_callback.call("최소 베팅 1만원", COL_DOWN)
		return
	if cash < bet:
		show_toast_callback.call("잔액 부족", COL_DOWN)
		return

	var daily_plays: int = NPCManager.get_rival_plays_today(npc_id)
	if daily_plays >= NPCManager.RIVAL_MAX_PLAYS_PER_DAY:
		show_toast_callback.call("오늘 대결 횟수 초과", COL_DOWN)
		return

	GameManager.add_cash(-bet)
	_bet = bet
	_settled = true
	_dice_result_shown = false
	_dice_reroll_count = 0
	_dice_state = 0  # ROLLING_PLAYER

	bet_edit.editable = false

	var result_lbl: Label = _layer.find_child("DiceResultLabel", true, false)
	if result_lbl:
		result_lbl.text = ""
	var npc_total_lbl: Label = _layer.find_child("NpcTotal", true, false)
	if npc_total_lbl:
		npc_total_lbl.text = "합계: ?"
	var user_total_lbl: Label = _layer.find_child("UserTotal", true, false)
	if user_total_lbl:
		user_total_lbl.text = "합계: 0"

	var start_btn: Button = _layer.find_child("DiceStartBtn", true, false)
	if start_btn:
		start_btn.text = "멈추기"
		start_btn.disabled = true
		if start_btn.is_connected("pressed", _on_dice_start):
			start_btn.pressed.disconnect(_on_dice_start)
		if not start_btn.is_connected("pressed", _on_dice_stop):
			start_btn.pressed.connect(_on_dice_stop)

	await get_tree().create_timer(0.5).timeout
	if _dice_state != 0:
		return
	if start_btn:
		start_btn.disabled = false

	var ud1: Control = _layer.find_child("UserDie1", true, false)
	var ud2: Control = _layer.find_child("UserDie2", true, false)
	var nd1: Control = _layer.find_child("NpcDie1", true, false)
	var nd2: Control = _layer.find_child("NpcDie2", true, false)
	if ud1:
		ud1.visible = true
	if ud2:
		ud2.visible = true
	if nd1:
		nd1.visible = true
	if nd2:
		nd2.visible = true

	_run_player_rolling()

func _on_dice_stop() -> void:
	if _dice_state != 0:
		return
	if not _layer:
		return
	_dice_state = 1  # ROLLING_NPC

	var ud1: Control = _layer.find_child("UserDie1", true, false)
	var ud2: Control = _layer.find_child("UserDie2", true, false)
	var user_total: int = 0
	if ud1 and ud1 is DiceView:
		user_total += (ud1 as DiceView).get_value()
	if ud2 and ud2 is DiceView:
		user_total += (ud2 as DiceView).get_value()
	var ut_lbl: Label = _layer.find_child("UserTotal", true, false)
	if ut_lbl:
		ut_lbl.text = "합계: %d" % user_total
		UIAnim.flash_up(ut_lbl)

	var start_btn: Button = _layer.find_child("DiceStartBtn", true, false)
	if start_btn:
		start_btn.text = "알고리즘 K 굴리는 중..."
		start_btn.disabled = true

	await get_tree().create_timer(0.8).timeout
	_on_npc_dice_stop()

func _run_player_rolling() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	while _dice_state == 0 and _layer:
		var ud1: Control = _layer.find_child("UserDie1", true, false)
		var ud2: Control = _layer.find_child("UserDie2", true, false)
		var nd1: Control = _layer.find_child("NpcDie1", true, false)
		var nd2: Control = _layer.find_child("NpcDie2", true, false)
		if ud1 and ud1 is DiceView:
			(ud1 as DiceView).set_value(rng.randi_range(1, 6))
		if ud2 and ud2 is DiceView:
			(ud2 as DiceView).set_value(rng.randi_range(1, 6))
		if nd1 and nd1 is DiceView:
			(nd1 as DiceView).set_value(rng.randi_range(1, 6))
		if nd2 and nd2 is DiceView:
			(nd2 as DiceView).set_value(rng.randi_range(1, 6))
		await get_tree().create_timer(0.07).timeout

func _on_npc_dice_stop() -> void:
	if _dice_state != 1:
		return
	if not _layer:
		return
	_dice_state = 2  # RESOLVED

	var nd1: Control = _layer.find_child("NpcDie1", true, false)
	var nd2: Control = _layer.find_child("NpcDie2", true, false)
	var npc_total: int = 0
	if nd1 and nd1 is DiceView:
		npc_total += (nd1 as DiceView).get_value()
	if nd2 and nd2 is DiceView:
		npc_total += (nd2 as DiceView).get_value()
	var nt_lbl: Label = _layer.find_child("NpcTotal", true, false)
	if nt_lbl:
		nt_lbl.text = "합계: %d" % npc_total
		UIAnim.flash_up(nt_lbl)

	var ud1: Control = _layer.find_child("UserDie1", true, false)
	var ud2: Control = _layer.find_child("UserDie2", true, false)
	var user_total: int = 0
	if ud1 and ud1 is DiceView:
		user_total += (ud1 as DiceView).get_value()
	if ud2 and ud2 is DiceView:
		user_total += (ud2 as DiceView).get_value()

	await get_tree().create_timer(0.3).timeout

	if user_total == npc_total and _dice_reroll_count < 3:
		show_toast_callback.call("무승부! 재굴림!", COL_TEXT_DIM)
		_dice_reroll_count += 1
		var ut_lbl: Label = _layer.find_child("UserTotal", true, false)
		if ut_lbl:
			ut_lbl.text = "합계: 0"
		if nt_lbl:
			nt_lbl.text = "합계: ?"
		await get_tree().create_timer(0.5).timeout
		_dice_state = 0  # 다시 ROLLING_PLAYER
		var start_btn: Button = _layer.find_child("DiceStartBtn", true, false)
		if start_btn:
			start_btn.text = "멈추기"
			start_btn.disabled = false
			if start_btn.is_connected("pressed", _on_dice_start):
				start_btn.pressed.disconnect(_on_dice_start)
			if not start_btn.is_connected("pressed", _on_dice_stop):
				start_btn.pressed.connect(_on_dice_stop)
		_run_player_rolling()
		return

	_dice_settle_and_show(user_total, npc_total)

func _dice_settle_and_show(user_total: int, npc_total: int) -> void:
	if _dice_result_shown:
		return
	_dice_result_shown = true

	var won: bool = user_total > npc_total
	var tied: bool = user_total == npc_total

	var ud1: Control = _layer.find_child("UserDie1", true, false)
	var ud2: Control = _layer.find_child("UserDie2", true, false)
	var nd1: Control = _layer.find_child("NpcDie1", true, false)
	var nd2: Control = _layer.find_child("NpcDie2", true, false)
	var win_col := COL_USER
	var lose_col := COL_LOSE
	var tie_col := COL_TIE
	var border_col: Color = win_col if won else (tie_col if tied else lose_col)
	var rival_col: Color = lose_col if won else (tie_col if tied else win_col)

	if ud1 and ud1 is DiceView:
		(ud1 as DiceView).border_color = border_col
	if ud2 and ud2 is DiceView:
		(ud2 as DiceView).border_color = border_col
	if nd1 and nd1 is DiceView:
		(nd1 as DiceView).border_color = rival_col
	if nd2 and nd2 is DiceView:
		(nd2 as DiceView).border_color = rival_col

	var result_text: String
	var result_color: Color
	if won:
		result_text = "승리!"
		result_color = COL_WIN
	elif tied:
		result_text = "무승부, 베팅금 반환"
		result_color = COL_TIE
	else:
		result_text = "패배..."
		result_color = COL_LOSE

	var result_lbl: Label = _layer.find_child("DiceResultLabel", true, false)
	if result_lbl:
		result_lbl.text = result_text
		result_lbl.add_theme_color_override("font_color", result_color)

	var settle_result: Dictionary = NPCManager.dice_settle(user_total, npc_total, _bet)
	var payout: float = float(settle_result.get("payout", 0.0))

	var amt_text: String
	var amt_color: Color
	if won:
		amt_text = "+%s" % UIUtil._fmt_won(payout)
		amt_color = COL_WIN
	elif tied:
		amt_text = "0원"
		amt_color = COL_TIE
	else:
		amt_text = "-%s" % UIUtil._fmt_won(_bet)
		amt_color = COL_LOSE

	await get_tree().create_timer(0.3).timeout
	var amt_popup := Label.new()
	amt_popup.text = amt_text
	amt_popup.add_theme_font_size_override("font_size", 32)
	amt_popup.add_theme_color_override("font_color", amt_color)
	amt_popup.modulate = Color.TRANSPARENT
	if pixel_font:
		amt_popup.add_theme_font_override("font", pixel_font)
	_layer.add_child(amt_popup)
	amt_popup.set_anchors_preset(Control.PRESET_CENTER)
	var screen_center := Vector2(get_viewport().get_visible_rect().size / 2.0)
	amt_popup.position = screen_center + Vector2(0, 40)

	var at := create_tween()
	at.tween_property(amt_popup, "modulate", Color.WHITE, 0.3)
	at.tween_interval(1.0)
	at.tween_property(amt_popup, "modulate", Color.TRANSPARENT, 0.5)
	at.tween_callback(amt_popup.queue_free)

	# 기록
	NPCManager.record_rival_game_result(npc_id, won)
	var desc: String = "%s %s" % [result_text, amt_text]
	show_toast_callback.call(desc, amt_color)
	refresh_npc_callback.call()

	# 버튼 → "확인", 닫기 표시
	var start_btn: Button = _layer.find_child("DiceStartBtn", true, false)
	if start_btn:
		start_btn.text = "확인"
		start_btn.disabled = false
		if start_btn.is_connected("pressed", _on_dice_stop):
			start_btn.pressed.disconnect(_on_dice_stop)
		if not start_btn.is_connected("pressed", _on_dice_close):
			start_btn.pressed.connect(_on_dice_close)

	var close_btn: Button = _layer.find_child("DiceCloseBtn", true, false)
	if close_btn:
		close_btn.visible = true

	# 시그널 발송
	game_finished.emit({"won": won, "payout": payout, "npc_id": npc_id})

func _on_dice_close() -> void:
	if _dice_state == 0 or _dice_state == 1:
		if _bet > 0 and not _dice_result_shown:
			GameManager.add_cash(_bet)
			show_toast_callback.call("대결 중단, 베팅금 반환", COL_TEXT_DIM)
			NPCManager.record_rival_game_result(npc_id, false)
			refresh_npc_callback.call()
	GameClockManager.resume_from_event()
	queue_free()

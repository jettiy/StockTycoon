class_name BlackjackGame extends Control
## 블랙잭 미니게임 (골드버그)
## 독립 Control로 분리 — MainGame에서 add_child 후 game_finished 시그널로 결과 전달

signal game_finished(result: Dictionary)  # {won: bool, payout: float, npc_id: String}

const UIAnim := preload("res://scripts/UIAnim.gd")

# ─── 색상 상수 (MainGame 복사) ───
const COL_NPC := Color(0.91, 0.11, 0.55, 1)       # #E81C8C
const COL_WIN := Color(0.16, 0.65, 0.42, 1)        # #28A66A
const COL_LOSE := Color(0.80, 0.27, 0.27, 1)        # #CC4545
const COL_PANEL := Color(0.165, 0.165, 0.239, 1)   # #2A2A3D
const COL_PANEL_LIGHT := Color(0.212, 0.212, 0.290, 1)
const COL_BORDER := Color(0.239, 0.239, 0.333, 1)
const COL_TEXT_DIM := Color(0.55, 0.55, 0.62, 1)
const COL_TEXT_BRIGHT := Color(0.88, 0.88, 0.92, 1)
const COL_DOWN := Color(1.0, 0.44, 0.26, 1)
const COL_UP := Color(0.40, 0.73, 0.42, 1)
const COL_CARD_BG := Color(0.15, 0.15, 0.27, 1)
const COL_CARD_BORDER := Color(0.25, 0.25, 0.33, 1)
const COL_CARD_HIT_BORDER := Color(1.0, 0.28, 0.34, 1)
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
var _user_cards: Array = []
var _user_total: int = 0
var _phase: String = ""
var _result_shown: bool = false

func _ready() -> void:
	_show_blackjack_game()

func _show_blackjack_game() -> void:
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
	_phase = "bet"

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
	title.text = npc.get("name", "골드버그") + " - 블랙잭"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_NPC)
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	vbox.add_child(title)

	# 블랙잭 설명
	var desc_lbl := Label.new()
	desc_lbl.text = "21에 가까운 쪽이 승리. Hit로 카드를 더 받거나 Stand로 멈추세요."
	desc_lbl.add_theme_font_size_override("font_size", 11)
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
	bet_edit.name = "BjBetSpin"
	bet_edit.min_value = 10000
	bet_edit.max_value = mini(10000000, maxi(10000, int(cash * 0.1)))
	bet_edit.step = 10000
	bet_edit.value = clampi(int(cash * 0.05), 10000, bet_edit.max_value)
	bet_edit.custom_minimum_size = Vector2(140, 36)
	bet_edit.value_changed.connect(_on_bj_bet_changed)
	bet_hbox.add_child(bet_edit)

	var cash_label := Label.new()
	cash_label.name = "BjCashLabel"
	cash_label.text = "보유: %s" % UIUtil._fmt_won(cash)
	cash_label.add_theme_font_size_override("font_size", 13)
	cash_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bet_hbox.add_child(cash_label)

	var bet_spacer := Control.new()
	bet_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bet_hbox.add_child(bet_spacer)

	vbox.add_child(_np_spacer(8))

	# 카드 영역: 유저존 / VS / 딜러존
	var cards_hbox := HBoxContainer.new()
	cards_hbox.name = "BjCardsArea"
	cards_hbox.add_theme_constant_override("separation", 24)
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(cards_hbox)

	# 유저존
	var user_zone := VBoxContainer.new()
	user_zone.name = "UserZone"
	user_zone.add_theme_constant_override("separation", 4)
	user_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_child(user_zone)

	var user_title_lbl := Label.new()
	user_title_lbl.text = "플레이어"
	user_title_lbl.add_theme_font_size_override("font_size", 14)
	user_title_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	user_zone.add_child(user_title_lbl)

	var user_cards_hbox := HBoxContainer.new()
	user_cards_hbox.name = "UserCards"
	user_cards_hbox.add_theme_constant_override("separation", 14)
	user_zone.add_child(user_cards_hbox)

	var user_total_lbl := Label.new()
	user_total_lbl.name = "UserTotal"
	user_total_lbl.text = "합계: 0"
	user_total_lbl.add_theme_font_size_override("font_size", 18)
	user_total_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	user_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	user_zone.add_child(user_total_lbl)

	# VS 중앙
	var vs_zone := VBoxContainer.new()
	vs_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_child(vs_zone)
	var vs_lbl := Label.new()
	vs_lbl.text = "VS"
	vs_lbl.add_theme_font_size_override("font_size", 24)
	vs_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	if pixel_font:
		vs_lbl.add_theme_font_override("font", pixel_font)
	vs_zone.add_child(vs_lbl)

	# 딜러존
	var dealer_zone := VBoxContainer.new()
	dealer_zone.name = "DealerZone"
	dealer_zone.add_theme_constant_override("separation", 4)
	dealer_zone.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_child(dealer_zone)

	var dealer_title_lbl := Label.new()
	dealer_title_lbl.text = "골드버그"
	dealer_title_lbl.add_theme_font_size_override("font_size", 14)
	dealer_title_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	dealer_zone.add_child(dealer_title_lbl)

	var dealer_cards_hbox := HBoxContainer.new()
	dealer_cards_hbox.name = "DealerCards"
	dealer_cards_hbox.add_theme_constant_override("separation", 14)
	dealer_zone.add_child(dealer_cards_hbox)

	var dealer_total_lbl := Label.new()
	dealer_total_lbl.name = "DealerTotal"
	dealer_total_lbl.text = "합계: ?"
	dealer_total_lbl.add_theme_font_size_override("font_size", 18)
	dealer_total_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	dealer_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dealer_zone.add_child(dealer_total_lbl)

	vbox.add_child(_np_spacer(8))

	# 버튼 영역
	var btn_hbox := HBoxContainer.new()
	btn_hbox.name = "BjBtnArea"
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)

	var start_btn := Button.new()
	start_btn.name = "BjStartBtn"
	start_btn.text = "도전!"
	start_btn.custom_minimum_size = Vector2(0, 44)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.add_theme_font_size_override("font_size", 17)
	start_btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	start_btn.pressed.connect(_on_bj_start)
	btn_hbox.add_child(start_btn)

	var hit_btn := Button.new()
	hit_btn.name = "BjHitBtn"
	hit_btn.text = "한 장 더"
	hit_btn.custom_minimum_size = Vector2(0, 44)
	hit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hit_btn.add_theme_font_size_override("font_size", 17)
	hit_btn.add_theme_color_override("font_color", COL_UP)
	hit_btn.visible = false
	hit_btn.pressed.connect(_on_bj_hit)
	btn_hbox.add_child(hit_btn)

	var stand_btn := Button.new()
	stand_btn.name = "BjStandBtn"
	stand_btn.text = "멈추기"
	stand_btn.custom_minimum_size = Vector2(0, 44)
	stand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stand_btn.add_theme_font_size_override("font_size", 17)
	stand_btn.add_theme_color_override("font_color", COL_DOWN)
	stand_btn.visible = false
	stand_btn.pressed.connect(_on_bj_stand)
	btn_hbox.add_child(stand_btn)

	# 결과 라벨
	var result_lbl := Label.new()
	result_lbl.name = "BjResultLabel"
	result_lbl.text = ""
	result_lbl.add_theme_font_size_override("font_size", 16)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		result_lbl.add_theme_font_override("font", pixel_font)
	vbox.add_child(result_lbl)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_on_bj_close)
	vbox.add_child(close_btn)

	overlay.gui_input.connect(
		func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				_on_bj_close()
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

func _on_bj_bet_changed(_v: float) -> void:
	if _layer:
		var cash: float = GameManager.get_cash()
		var cl: Label = _layer.find_child("BjCashLabel", true, false)
		if cl:
			cl.text = "보유: %s" % UIUtil._fmt_won(cash)

func _make_card_panel(card_val: int, face_down: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(56, 80)
	var s := StyleBoxFlat.new()
	if face_down:
		s.bg_color = COL_CARD_BORDER
		s.border_color = COL_CARD_BORDER
	else:
		s.bg_color = COL_CARD_BG
		s.border_color = COL_CARD_BORDER
	s.set_border_width_all(1)
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	p.add_theme_stylebox_override("panel", s)

	var lbl := Label.new()
	if face_down:
		lbl.text = "?"
	else:
		var face: String = str(card_val)
		if card_val == 1:
			face = "A"
		elif card_val == 11:
			face = "J"
		elif card_val == 12:
			face = "Q"
		elif card_val == 13:
			face = "K"
		lbl.text = face
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	if pixel_font:
		lbl.add_theme_font_override("font", pixel_font)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(lbl)

	if face_down:
		p.modulate.a = 0.5

	return p

func _on_bj_start() -> void:
	if _settled:
		return
	if not _layer:
		return

	var bet_edit: SpinBox = _layer.find_child("BjBetSpin", true, false)
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

	# 베팅 차감
	GameManager.add_cash(-bet)
	_bet = bet
	_settled = true
	_phase = "player_turn"

	bet_edit.editable = false

	var start_btn: Button = _layer.find_child("BjStartBtn", true, false)
	if start_btn:
		start_btn.visible = false

	var hit_btn: Button = _layer.find_child("BjHitBtn", true, false)
	var stand_btn: Button = _layer.find_child("BjStandBtn", true, false)

	# 유저 초기 2장 드로우
	var deal_result: Dictionary = NPCManager.bj_deal_user_cards()
	_user_cards = deal_result.get("cards", []) as Array
	_user_total = int(deal_result.get("total", 0))

	var user_cards_hbox: HBoxContainer = _layer.find_child("UserCards", true, false)
	var user_total_lbl: Label = _layer.find_child("UserTotal", true, false)
	var result_lbl: Label = _layer.find_child("BjResultLabel", true, false)

	for ch in user_cards_hbox.get_children():
		ch.queue_free()

	var user_card_panels: Array = []
	for cdata in _user_cards:
		var card_dict: Dictionary = cdata as Dictionary
		var card_val: int = int(card_dict.get("val", 0))
		var cp := _make_card_panel(card_val, false)
		cp.visible = false
		user_cards_hbox.add_child(cp)
		user_card_panels.append(cp)

	await get_tree().create_timer(0.3).timeout
	if user_card_panels.size() >= 1:
		user_card_panels[0].visible = true
		UIAnim.card_fade_in(user_card_panels[0])
	await get_tree().create_timer(0.25).timeout
	if user_card_panels.size() >= 2:
		user_card_panels[1].visible = true
		UIAnim.card_fade_in(user_card_panels[1])

	await get_tree().create_timer(0.2).timeout
	user_total_lbl.text = "합계: %d" % _user_total
	UIAnim.flash_up(user_total_lbl)

	if _user_total == 21:
		_phase = "dealer_turn"
		await get_tree().create_timer(0.3).timeout
		_resolve_bj()
		return

	if hit_btn:
		hit_btn.visible = true
	if stand_btn:
		stand_btn.visible = true

func _on_bj_hit() -> void:
	if _phase != "player_turn":
		return
	if not _layer:
		return

	var hit_result: Dictionary = NPCManager.bj_user_hit(_user_total)
	var card_val: int = int(hit_result.get("val", 0))
	_user_total = int(hit_result.get("total", 0))
	var busted: bool = hit_result.get("busted", false) as bool

	_user_cards.append({"card": int(hit_result.get("card", 0)), "val": card_val})

	var user_cards_hbox: HBoxContainer = _layer.find_child("UserCards", true, false)
	var user_total_lbl: Label = _layer.find_child("UserTotal", true, false)

	var cp := _make_card_panel(card_val, false)
	user_cards_hbox.add_child(cp)
	UIAnim.card_fade_in(cp)

	user_total_lbl.text = "합계: %d" % _user_total
	if busted:
		UIAnim.flash_down(user_total_lbl)
		UIAnim.shake(user_total_lbl)
	else:
		UIAnim.flash_up(user_total_lbl)

	if busted:
		var hit_btn: Button = _layer.find_child("BjHitBtn", true, false)
		var stand_btn: Button = _layer.find_child("BjStandBtn", true, false)
		if hit_btn:
			hit_btn.visible = false
		if stand_btn:
			stand_btn.visible = false
		_phase = "result"
		await get_tree().create_timer(0.5).timeout
		_show_bj_result(0, 0.0, false, false, true)
		return

	if _user_total == 21:
		var hit_btn: Button = _layer.find_child("BjHitBtn", true, false)
		var stand_btn: Button = _layer.find_child("BjStandBtn", true, false)
		if hit_btn:
			hit_btn.visible = false
		if stand_btn:
			stand_btn.visible = false
		await get_tree().create_timer(0.2).timeout
		_resolve_bj()
		return

func _on_bj_stand() -> void:
	if _phase != "player_turn":
		return
	var hit_btn: Button = _layer.find_child("BjHitBtn", true, false)
	var stand_btn: Button = _layer.find_child("BjStandBtn", true, false)
	if hit_btn:
		hit_btn.visible = false
	if stand_btn:
		stand_btn.visible = false
	_resolve_bj()

func _resolve_bj() -> void:
	if not _layer:
		return
	_phase = "dealer_turn"

	var user_busted: bool = _user_total > 21
	var dealer_total: int = 0
	var dealer_cards: Array = []

	if not user_busted:
		var dealer_result: Dictionary = NPCManager.bj_play_dealer()
		dealer_cards = dealer_result.get("cards", []) as Array
		dealer_total = int(dealer_result.get("total", 0))

		var dealer_cards_hbox: HBoxContainer = _layer.find_child("DealerCards", true, false)
		var dealer_total_lbl: Label = _layer.find_child("DealerTotal", true, false)

		for ch in dealer_cards_hbox.get_children():
			ch.queue_free()

		var dealer_card_panels: Array = []
		for cdata in dealer_cards:
			var card_dict: Dictionary = cdata as Dictionary
			var card_val: int = int(card_dict.get("val", 0))
			var cp := _make_card_panel(card_val, true)
			cp.visible = false
			dealer_cards_hbox.add_child(cp)
			dealer_card_panels.append(cp)

		await get_tree().create_timer(0.3).timeout
		if dealer_card_panels.size() >= 1:
			dealer_card_panels[0].visible = true
			UIAnim.card_fade_in(dealer_card_panels[0])
		await get_tree().create_timer(0.25).timeout
		if dealer_card_panels.size() >= 2:
			dealer_card_panels[1].visible = true
			UIAnim.card_fade_in(dealer_card_panels[1])

		await get_tree().create_timer(0.45).timeout
		for i in dealer_card_panels.size():
			var dp: Panel = dealer_card_panels[i] as Panel
			dp.modulate.a = 0.0
			await get_tree().create_timer(0.12).timeout
		for i in dealer_card_panels.size():
			var dp: Panel = dealer_card_panels[i] as Panel
			var card_dict: Dictionary = dealer_cards[i] as Dictionary
			var card_val: int = int(card_dict.get("card", 0))
			var inner_lbl: Label = dp.get_child(0) as Label
			var face: String = str(card_val)
			if card_val == 1:
				face = "A"
			elif card_val == 11:
				face = "J"
			elif card_val == 12:
				face = "Q"
			elif card_val == 13:
				face = "K"
			inner_lbl.text = face
			var s := StyleBoxFlat.new()
			s.bg_color = COL_CARD_BG
			s.border_color = COL_CARD_BORDER
			s.set_border_width_all(1)
			s.corner_radius_top_left = 4
			s.corner_radius_top_right = 4
			s.corner_radius_bottom_left = 4
			s.corner_radius_bottom_right = 4
			if dealer_total > 21:
				s.border_color = COL_CARD_HIT_BORDER
			dp.add_theme_stylebox_override("panel", s)
			dp.modulate.a = 1.0

		await get_tree().create_timer(0.3).timeout
		dealer_total_lbl.text = "합계: %d" % dealer_total
		if dealer_total > 21:
			UIAnim.flash_down(dealer_total_lbl)
			UIAnim.shake(dealer_total_lbl)
		else:
			UIAnim.flash_up(dealer_total_lbl)

		if dealer_card_panels.size() >= 3:
			await get_tree().create_timer(0.2).timeout
			dealer_total_lbl.text = "합계: %d" % dealer_total

		var settle_result: Dictionary = NPCManager.bj_settle(_user_total, dealer_total, _bet)
		var won: bool = settle_result.get("won", false) as bool
		var tied: bool = settle_result.get("tie", false) as bool
		var payout: float = float(settle_result.get("payout", 0.0))

		_phase = "result"
		await get_tree().create_timer(0.5).timeout
		_show_bj_result(dealer_total, payout, won, tied, false)
	else:
		_phase = "result"
		await get_tree().create_timer(0.3).timeout
		_show_bj_result(0, 0.0, false, false, true)

func _show_bj_result(dealer_total: int, payout: float, won: bool, tied: bool, user_busted: bool) -> void:
	if not _layer:
		return
	_result_shown = true

	var result_lbl: Label = _layer.find_child("BjResultLabel", true, false)
	var dealer_total_lbl: Label = _layer.find_child("DealerTotal", true, false)

	var result_text: String
	var result_color: Color
	if won:
		result_text = "승리!"
		result_color = COL_WIN
	elif tied:
		result_text = "무승부!"
		result_color = COL_TEXT_DIM
	else:
		result_text = "패배..."
		result_color = COL_LOSE

	result_lbl.text = result_text
	result_lbl.add_theme_color_override("font_color", result_color)
	UIAnim.pop_in(result_lbl)

	await get_tree().create_timer(0.5).timeout
	if not _layer:
		return

	var amt_text: String
	if won:
		amt_text = "+%s" % UIUtil._fmt_won(payout - _bet)
	elif tied:
		amt_text = "±0원 (환불)"
	else:
		amt_text = "-%s" % UIUtil._fmt_won(_bet)

	var amt_popup := Label.new()
	amt_popup.text = amt_text
	amt_popup.add_theme_font_size_override("font_size", 32)
	amt_popup.add_theme_color_override("font_color", result_color)
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
	var desc: String
	if won:
		desc = "%s %s" % [result_text, amt_text]
	elif tied:
		desc = "%s 베팅금 환불" % result_text
	else:
		desc = "%s %s" % [result_text, amt_text]
	show_toast_callback.call(desc, COL_UP if won else (COL_TEXT_DIM if tied else COL_DOWN))
	refresh_npc_callback.call()

	# 시그널 발송
	game_finished.emit({"won": won, "payout": payout, "npc_id": npc_id})

func _on_bj_close() -> void:
	if _settled and _bet > 0 and not _result_shown:
		GameManager.add_cash(_bet)
		show_toast_callback.call("대결 중단, 베팅금 반환", COL_TEXT_DIM)
		NPCManager.record_rival_game_result(npc_id, false)
		refresh_npc_callback.call()
	GameClockManager.resume_from_event()
	queue_free()

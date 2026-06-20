extends Control
## MainGame — 메인 게임 화면
## 종목 리스트(실시간) + 카테고리 필터 + 매매 패널

# ─── 색상 (다크 트레이딩 터미널) ────────────────
const COL_BG := Color(0.063, 0.067, 0.078, 1)
const COL_PANEL := Color(0.094, 0.098, 0.110, 1)
const COL_PANEL_LIGHT := Color(0.122, 0.126, 0.138, 1)
const COL_BORDER := Color(0.18, 0.18, 0.20, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
const COL_UP := Color(0.15, 0.65, 0.39, 1)
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)
const COL_TEXT := Color(0.82, 0.82, 0.85, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
const COL_TEXT_BRIGHT := Color(0.95, 0.95, 0.97, 1)

const CATEGORY_FILTERS := ["전체", "한국", "미국", "코인"]
const CATEGORY_MAP := {"전체": "", "한국": "korea", "미국": "usa", "코인": "coin"}

# ─── UI 노드 참조 ──────────────────────────────
var _top_bar: HBoxContainer
var _tab_bar: HBoxContainer
var _stock_scroll: ScrollContainer
var _stock_list: VBoxContainer
var _trade_panel: PanelContainer
var _toast_label: Label

var _cash_label: Label
var _networth_label: Label
var _day_label: Label
var _rank_label: Label

var _current_category: String = ""
var _selected_stock: String = ""
var _stock_rows: Dictionary = {}  # stock_id -> row HBoxContainer

# 매매 패널
var _trade_stock_name: Label
var _trade_price_label: Label
var _trade_qty_edit: SpinBox
var _trade_total_label: Label
var _trade_holding_label: Label


# ═══════════════════════════════════════════════
#   초기화
# ═══════════════════════════════════════════════

func _ready() -> void:
	_build_layout()
	_refresh_all()
	_connect_signals()


func _connect_signals() -> void:
	GameManager.cash_changed.connect(_on_cash_changed)
	GameManager.net_worth_changed.connect(_on_net_worth_changed)
	MarketSim.market_tick.connect(_on_market_tick)
	MarketSim.price_changed.connect(_on_price_changed)


# ═══════════════════════════════════════════════
#   레이아웃 빌드
# ═══════════════════════════════════════════════

func _build_layout() -> void:
	# 배경
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 메인 수직 컨테이너 (top_bar | tabs | stock_list | trade_panel)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_tab_bar())

	# 종목 리스트 (스크롤 가능)
	_stock_scroll = ScrollContainer.new()
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_scroll.add_theme_stylebox_override("panel", _style_flat(COL_PANEL, 0))
	root.add_child(_stock_scroll)

	_stock_list = VBoxContainer.new()
	_stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_list.add_theme_constant_override("separation", 2)
	_stock_scroll.add_child(_stock_list)

	# 매매 패널
	root.add_child(_build_trade_panel())

	# 토스트 알림
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 80
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	_toast_label.visible = false
	_toast_label.z_index = 100
	add_child(_toast_label)

	_populate_stock_list()


func _build_top_bar() -> HBoxContainer:
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 24)

	# 캐릭터 정보
	var char_box := VBoxContainer.new()
	char_box.add_theme_constant_override("separation", 2)
	var name_label := Label.new()
	name_label.text = "  %s · %d대" % [GameManager.player["name"], GameManager.player["generation"]]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	char_box.add_child(name_label)

	_rank_label = Label.new()
	_rank_label.text = "  " + GameManager.get_rank_name()
	_rank_label.add_theme_font_size_override("font_size", 13)
	_rank_label.add_theme_color_override("font_color", COL_ACCENT)
	char_box.add_child(_rank_label)
	_top_bar.add_child(char_box)

	# 스페이서
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(spacer)

	# 현금
	_top_bar.add_child(_stat_label("현금", _fmt_won(GameManager.get_cash()), COL_UP, "cash"))

	# 순자산
	_top_bar.add_child(_stat_label("순자산", _fmt_won(GameManager.get_net_worth()), COL_ACCENT, "networth"))

	# 일차
	_day_label = Label.new()
	_day_label.text = "%d일차" % GameManager.player["day"]
	_day_label.add_theme_font_size_override("font_size", 16)
	_day_label.add_theme_color_override("font_color", COL_TEXT)
	_top_bar.add_child(_day_label)

	# 메뉴 버튼들
	var save_btn := Button.new()
	save_btn.text = "저장"
	save_btn.custom_minimum_size = Vector2(60, 30)
	save_btn.pressed.connect(_on_save)
	_top_bar.add_child(save_btn)

	var menu_btn := Button.new()
	menu_btn.text = "메뉴"
	menu_btn.custom_minimum_size = Vector2(60, 30)
	menu_btn.pressed.connect(_on_menu)
	_top_bar.add_child(menu_btn)

	return _top_bar


func _build_tab_bar() -> HBoxContainer:
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)

	for cat in CATEGORY_FILTERS:
		var btn := Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(80, 32)
		btn.add_theme_font_size_override("font_size", 14)
		btn.toggle_mode = true
		btn.set_meta("category", cat)
		btn.pressed.connect(_on_tab_pressed.bind(cat))
		_update_tab_style(btn, cat == CATEGORY_FILTERS[0])
		_tab_bar.add_child(btn)

	# 마켓 페이즈 표시
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.add_child(spacer)

	# 페이즈 라벨은 _on_market_tick에서 업데이트됨
	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "시장: 중립"
	phase_label.add_theme_font_size_override("font_size", 13)
	phase_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_tab_bar.add_child(phase_label)

	_current_category = ""
	return _tab_bar


func _build_trade_panel() -> PanelContainer:
	_trade_panel = PanelContainer.new()
	_trade_panel.add_theme_stylebox_override("panel", _style_flat(COL_PANEL_LIGHT, 6))
	_trade_panel.custom_minimum_size = Vector2(0, 100)
	_trade_panel.visible = false

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.offset_left = 16
	hbox.offset_top = 8
	hbox.offset_right = -16
	hbox.offset_bottom = -8
	_trade_panel.add_child(hbox)

	# 좌측: 종목 정보
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 4)

	_trade_stock_name = Label.new()
	_trade_stock_name.add_theme_font_size_override("font_size", 18)
	_trade_stock_name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	info_box.add_child(_trade_stock_name)

	_trade_price_label = Label.new()
	_trade_price_label.add_theme_font_size_override("font_size", 14)
	_trade_price_label.add_theme_color_override("font_color", COL_ACCENT)
	info_box.add_child(_trade_price_label)

	_trade_holding_label = Label.new()
	_trade_holding_label.add_theme_font_size_override("font_size", 12)
	_trade_holding_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	info_box.add_child(_trade_holding_label)

	hbox.add_child(info_box)

	# 중간 스페이서
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 우측: 수량 + 매수/매도
	var action_box := HBoxContainer.new()
	action_box.add_theme_constant_override("separation", 8)
	action_box.alignment = BoxContainer.ALIGNMENT_END

	var qty_label := Label.new()
	qty_label.text = "수량"
	qty_label.add_theme_font_size_override("font_size", 13)
	qty_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_box.add_child(qty_label)

	_trade_qty_edit = SpinBox.new()
	_trade_qty_edit.min_value = 1
	_trade_qty_edit.max_value = 100000
	_trade_qty_edit.value = 1
	_trade_qty_edit.custom_minimum_size = Vector2(120, 36)
	_trade_qty_edit.value_changed.connect(_on_qty_changed)
	action_box.add_child(_trade_qty_edit)

	# 총액 표시
	_trade_total_label = Label.new()
	_trade_total_label.text = "0원"
	_trade_total_label.add_theme_font_size_override("font_size", 14)
	_trade_total_label.add_theme_color_override("font_color", COL_TEXT)
	_trade_total_label.custom_minimum_size = Vector2(150, 0)
	_trade_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trade_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_box.add_child(_trade_total_label)

	# 매수 버튼
	var buy_btn := Button.new()
	buy_btn.text = "매수"
	buy_btn.custom_minimum_size = Vector2(70, 36)
	buy_btn.add_theme_font_size_override("font_size", 15)
	buy_btn.add_theme_color_override("font_color", COL_UP)
	buy_btn.pressed.connect(_on_buy)
	action_box.add_child(buy_btn)

	# 매도 버튼
	var sell_btn := Button.new()
	sell_btn.text = "매도"
	sell_btn.custom_minimum_size = Vector2(70, 36)
	sell_btn.add_theme_font_size_override("font_size", 15)
	sell_btn.add_theme_color_override("font_color", COL_DOWN)
	sell_btn.pressed.connect(_on_sell)
	action_box.add_child(sell_btn)

	# 닫기
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_close_trade_panel)
	action_box.add_child(close_btn)

	hbox.add_child(action_box)

	return _trade_panel


# ═══════════════════════════════════════════════
#   종목 리스트
# ═══════════════════════════════════════════════

func _populate_stock_list() -> void:
	for child in _stock_list.get_children():
		child.queue_free()
	_stock_rows.clear()

	for stock in MarketSim.get_all_stocks():
		var row := _create_stock_row(stock)
		_stock_list.add_child(row)
		_stock_rows[stock["id"]] = row


func _create_stock_row(stock: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
	btn.add_theme_stylebox_override("hover", _style_flat(COL_PANEL_LIGHT, 4))
	btn.add_theme_stylebox_override("pressed", _style_flat(COL_PANEL_LIGHT, 4))
	btn.set_meta("stock_id", stock["id"])
	btn.pressed.connect(_on_stock_clicked.bind(stock["id"]))

	# 행 내용은 HBox로 구성
	var hbox := HBoxContainer.new()
	hbox.offset_left = 12
	hbox.offset_top = 4
	hbox.offset_right = -12
	hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 12)
	btn.add_child(hbox)

	# 좌측: 이름 + 티커
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 1)

	var name := Label.new()
	name.text = stock["name"]
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_box.add_child(name)

	var meta := Label.new()
	meta.text = "%s · %s" % [stock.get("ticker", ""), stock.get("sector", "")]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	name_box.add_child(meta)

	hbox.add_child(name_box)

	# 카테고리 태그
	var cat_label := Label.new()
	cat_label.text = _category_tag(stock["category"])
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", _category_color(stock["category"]))
	cat_label.custom_minimum_size = Vector2(40, 0)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cat_label)

	# 스페이서
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 보유 수량
	var hold_label := Label.new()
	hold_label.name = "HoldLabel"
	hold_label.add_theme_font_size_override("font_size", 12)
	hold_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	hold_label.custom_minimum_size = Vector2(80, 0)
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hold_label)

	# 가격
	var price := Label.new()
	price.name = "PriceLabel"
	price.text = _fmt_price(stock["price"])
	price.add_theme_font_size_override("font_size", 15)
	price.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	price.custom_minimum_size = Vector2(130, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(price)

	# 등락률
	var change := Label.new()
	change.name = "ChangeLabel"
	change.text = _fmt_change(stock.get("change_pct", 0.0))
	change.add_theme_font_size_override("font_size", 14)
	change.add_theme_color_override("font_color", _change_color(stock.get("change_pct", 0.0)))
	change.custom_minimum_size = Vector2(100, 0)
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(change)

	return btn


# ═══════════════════════════════════════════════
#   이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_tab_pressed(cat: String) -> void:
	_current_category = CATEGORY_MAP[cat]
	for child in _tab_bar.get_children():
		if child is Button and child.has_meta("category"):
			_update_tab_style(child, child.get_meta("category") == cat)

	_apply_category_filter()


func _update_tab_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", COL_TEXT)
		btn.add_theme_color_override("font_hover_color", COL_TEXT_BRIGHT)


func _apply_category_filter() -> void:
	for stock_id in _stock_rows:
		var row: Control = _stock_rows[stock_id]
		if _current_category == "":
			row.visible = true
		else:
			var stock := MarketSim.get_stock(stock_id)
			row.visible = stock.get("category") == _current_category


func _on_stock_clicked(stock_id: String) -> void:
	_selected_stock = stock_id
	_open_trade_panel(stock_id)


func _open_trade_panel(stock_id: String) -> void:
	_trade_panel.visible = true
	_update_trade_panel()


func _close_trade_panel() -> void:
	_trade_panel.visible = false
	_selected_stock = ""


func _update_trade_panel() -> void:
	if _selected_stock == "":
		return
	var stock := MarketSim.get_stock(_selected_stock)
	if stock.is_empty():
		return

	_trade_stock_name.text = "%s (%s)" % [stock["name"], stock.get("ticker", "")]
	_trade_price_label.text = _fmt_price(stock["price"]) + "  " + _fmt_change(stock.get("change_pct", 0.0))
	_trade_price_label.add_theme_color_override("font_color", _change_color(stock.get("change_pct", 0.0)))

	var qty := GameManager.get_holding_quantity(_selected_stock)
	if qty > 0:
		var avg := GameManager.get_holding(_selected_stock)["avg_price"]
		_trade_holding_label.text = "보유: %d주 | 평단가 %s" % [qty, _fmt_price(avg)]
	else:
		_trade_holding_label.text = "보유 없음"

	_on_qty_changed(_trade_qty_edit.value)


func _on_qty_changed(value: float) -> void:
	if _selected_stock == "":
		return
	var stock := MarketSim.get_stock(_selected_stock)
	if stock.is_empty():
		return
	var total := stock["price"] * int(value)
	_trade_total_label.text = _fmt_won(total)


func _on_buy() -> void:
	if _selected_stock == "":
		return
	var qty := int(_trade_qty_edit.value)
	var result := GameManager.buy_stock(_selected_stock, qty)
	if result.get("success", false):
		_show_toast("매수 완료: %d주 (%s)" % [qty, _fmt_won(result["cost"])])
		_update_trade_panel()
	else:
		_show_toast("실패: " + result.get("reason", "알 수 없는 오류"))


func _on_sell() -> void:
	if _selected_stock == "":
		return
	var qty := int(_trade_qty_edit.value)
	var result := GameManager.sell_stock(_selected_stock, qty)
	if result.get("success", false):
		var profit_text := ""
		if result.has("profit"):
			var p: float = result["profit"]
			if p >= 0:
				profit_text = " (수익 +%s)" % _fmt_won(p)
			else:
				profit_text = " (손실 %s)" % _fmt_won(abs(p))
		_show_toast("매도 완료: %d주%s" % [qty, profit_text])
		_update_trade_panel()
	else:
		_show_toast("실패: " + result.get("reason", "알 수 없는 오류"))


func _on_save() -> void:
	SaveManager.save_game()
	_show_toast("저장되었습니다")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/boot.tscn")


func _on_cash_changed(cash: float) -> void:
	if _cash_label:
		_cash_label.text = _fmt_won(cash)


func _on_net_worth_changed(nw: float) -> void:
	if _networth_label:
		_networth_label.text = _fmt_won(nw)


func _on_market_tick() -> void:
	# 페이즈 표시 업데이트
	var phase_label := _tab_bar.get_node_or_null("PhaseLabel")
	if phase_label is Label:
		var cycle := MarketSim.market_cycle
		if cycle > 0.3:
			phase_label.text = "시장: 강세 ↑"
			phase_label.add_theme_color_override("font_color", COL_UP)
		elif cycle < -0.3:
			phase_label.text = "시장: 약세 ↓"
			phase_label.add_theme_color_override("font_color", COL_DOWN)
		else:
			phase_label.text = "시장: 중립"
			phase_label.add_theme_color_override("font_color", COL_TEXT_DIM)

	# 행 업데이트
	for stock_id in _stock_rows:
		_update_stock_row(stock_id)

	# 순자산 실시간 갱신
	if _networth_label:
		_networth_label.text = _fmt_won(GameManager.get_net_worth())

	# 매매 패널 열려있으면 업데이트
	if _trade_panel.visible:
		_update_trade_panel()


func _on_price_changed(_stock_id: String, _new_price: float, _change_pct: float) -> void:
	# _on_market_tick에서 일괄 업데이트하므로 여기서는 생략
	pass


func _update_stock_row(stock_id: String) -> void:
	var row: Control = _stock_rows.get(stock_id)
	if not row:
		return
	var stock := MarketSim.get_stock(stock_id)
	if stock.is_empty():
		return

	var price_label := row.get_node_or_null("PriceLabel")
	if price_label is Label:
		(price_label as Label).text = _fmt_price(stock["price"])

	var change_label := row.get_node_or_null("ChangeLabel")
	if change_label is Label:
		var pct: float = stock.get("change_pct", 0.0)
		(change_label as Label).text = _fmt_change(pct)
		(change_label as Label).add_theme_color_override("font_color", _change_color(pct))

	var hold_label := row.get_node_or_null("HoldLabel")
	if hold_label is Label:
		var qty := GameManager.get_holding_quantity(stock_id)
		if qty > 0:
			(hold_label as Label).text = "%d주" % qty
			(hold_label as Label).add_theme_color_override("font_color", COL_ACCENT)
		else:
			(hold_label as Label).text = ""


# ═══════════════════════════════════════════════
#   헬퍼
# ═══════════════════════════════════════════════

func _refresh_all() -> void:
	_on_cash_changed(GameManager.get_cash())
	_on_net_worth_changed(GameManager.get_net_worth())


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0

	# 페이드 아웃 트윈
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast_label.visible = false)


func _stat_label(title: String, value: String, color: Color, meta: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", COL_TEXT_DIM)
	box.add_child(t)

	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 16)
	v.add_theme_color_override("font_color", color)
	box.add_child(v)

	match meta:
		"cash": _cash_label = v
		"networth": _networth_label = v

	return box


func _category_tag(cat: String) -> String:
	match cat:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return cat


func _category_color(cat: String) -> Color:
	match cat:
		"korea": return Color(0.35, 0.60, 0.90, 1)
		"usa": return Color(0.75, 0.45, 0.85, 1)
		"coin": return Color(0.85, 0.70, 0.30, 1)
		_: return COL_TEXT_DIM


func _change_color(pct: float) -> Color:
	if pct > 0.01:
		return COL_UP
	elif pct < -0.01:
		return COL_DOWN
	return COL_TEXT_DIM


func _fmt_price(price: float) -> String:
	if price >= 100_000_000:
		return "%.2f억" % (price / 100_000_000)
	return "%,.0f원" % price


func _fmt_won(amount: float) -> String:
	if abs(amount) >= 100_000_000:
		return "%.2f억원" % (amount / 100_000_000)
	elif abs(amount) >= 10_000_000:
		return "%.1f천만원" % (amount / 10_000_000)
	return "%,.0f원" % amount


func _fmt_change(pct: float) -> String:
	if pct >= 0:
		return "+%.2f%%" % pct
	return "%.2f%%" % pct


func _style_flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

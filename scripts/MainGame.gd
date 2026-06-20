extends Control
## MainGame — 메인 게임 화면 (3탭: 시장 / 자동매매 / 라이프)

# ─── 색상 ──────────────────────────────────────
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
const COL_GOLD := Color(0.85, 0.70, 0.30, 1)

const CATEGORY_FILTERS := ["전체", "한국", "미국", "코인"]
const CATEGORY_MAP := {"전체": "", "한국": "korea", "미국": "usa", "코인": "coin"}
const VIEW_TABS := ["시장", "자동매매", "라이프"]

# ─── UI 노드 ────────────────────────────────────
var _top_bar: HBoxContainer
var _view_tab_bar: HBoxContainer
var _cat_tab_bar: HBoxContainer
var _content: VBoxContainer
var _toast_label: Label

var _cash_label: Label
var _networth_label: Label
var _day_label: Label

# 뷰 컨테이너
var _market_view: VBoxContainer
var _autotrade_view: VBoxContainer
var _life_view: VBoxContainer
var _current_view: String = "시장"

# 시장 뷰
var _stock_scroll: ScrollContainer
var _stock_list: VBoxContainer
var _trade_panel: PanelContainer
var _stock_rows: Dictionary = {}
var _current_category: String = ""
var _selected_stock: String = ""

# 매매 패널
var _trade_stock_name: Label
var _trade_price_label: Label
var _trade_qty_edit: SpinBox
var _trade_total_label: Label
var _trade_holding_label: Label

# 자동매매 뷰
var _autotrade_slots: Array = []

# 라이프 뷰
var _life_housing_container: VBoxContainer
var _life_vehicle_container: VBoxContainer


# ═══════════════════════════════════════════════
func _ready() -> void:
	_build_layout()
	_refresh_all()
	_connect_signals()


func _connect_signals() -> void:
	GameManager.cash_changed.connect(_on_cash_changed)
	GameManager.net_worth_changed.connect(_on_net_worth_changed)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.rank_up.connect(_on_rank_up)
	GameManager.salary_paid.connect(_on_salary_paid)
	MarketSim.market_tick.connect(_on_market_tick)
	AutoTradeManager.auto_trade_executed.connect(_on_auto_trade_executed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _show_view("시장")
			KEY_2: _show_view("자동매매")
			KEY_3: _show_view("라이프")
			KEY_SPACE: if _current_view == "시장": _on_advance_day()
			KEY_ESCAPE: _close_trade_panel()


# ═══════════════════════════════════════════════
#   레이아웃
# ═══════════════════════════════════════════════

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 8
	root.offset_right = -12
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_view_tabs())
	root.add_child(_build_cat_tabs())

	# 콘텐츠 영역
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	root.add_child(_content)

	# 3개 뷰 빌드
	_build_market_view()
	_build_autotrade_view()
	_build_life_view()

	_show_view("시장")

	# 토스트
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_top = 70
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	_toast_label.visible = false
	_toast_label.z_index = 100
	add_child(_toast_label)


func _build_top_bar() -> HBoxContainer:
	_top_bar = HBoxContainer.new()
	_top_bar.add_theme_constant_override("separation", 20)

	# 캐릭터
	var char_box := VBoxContainer.new()
	char_box.add_theme_constant_override("separation", 1)
	var name_label := Label.new()
	name_label.text = "  %s · %d대" % [GameManager.player["name"], GameManager.player["generation"]]
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	char_box.add_child(name_label)
	var rank_label := Label.new()
	rank_label.text = "  " + GameManager.get_rank_name()
	rank_label.add_theme_font_size_override("font_size", 12)
	rank_label.add_theme_color_override("font_color", COL_ACCENT)
	rank_label.name = "RankLabel"
	char_box.add_child(rank_label)
	_top_bar.add_child(char_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_bar.add_child(spacer)

	# 현금
	_top_bar.add_child(_stat_box("현금", _fmt_won(GameManager.get_cash()), COL_UP, "cash"))
	# 순자산
	_top_bar.add_child(_stat_box("순자산", _fmt_won(GameManager.get_net_worth()), COL_ACCENT, "networth"))

	# 일차
	var day_box := VBoxContainer.new()
	day_box.add_theme_constant_override("separation", 1)
	var d1 := Label.new()
	d1.text = "진행일"
	d1.add_theme_font_size_override("font_size", 11)
	d1.add_theme_color_override("font_color", COL_TEXT_DIM)
	day_box.add_child(d1)
	_day_label = Label.new()
	_day_label.text = "%d일차" % GameManager.player["day"]
	_day_label.add_theme_font_size_override("font_size", 15)
	_day_label.add_theme_color_override("font_color", COL_TEXT)
	day_box.add_child(_day_label)
	_top_bar.add_child(day_box)

	# 하루 경과 버튼
	var advance_btn := Button.new()
	advance_btn.text = "▶ 하루 경과"
	advance_btn.custom_minimum_size = Vector2(100, 40)
	advance_btn.add_theme_font_size_override("font_size", 14)
	advance_btn.add_theme_color_override("font_color", COL_GOLD)
	advance_btn.add_theme_stylebox_override("normal", _style_flat(Color(0.15, 0.12, 0.05, 1), 6))
	advance_btn.add_theme_stylebox_override("hover", _style_flat(Color(0.20, 0.16, 0.06, 1), 6))
	advance_btn.pressed.connect(_on_advance_day)
	advance_btn.name = "AdvanceButton"
	_top_bar.add_child(advance_btn)

	# 저장
	var save_btn := Button.new()
	save_btn.text = "저장"
	save_btn.custom_minimum_size = Vector2(60, 40)
	save_btn.pressed.connect(_on_save)
	_top_bar.add_child(save_btn)

	# 메뉴
	var menu_btn := Button.new()
	menu_btn.text = "메뉴"
	menu_btn.custom_minimum_size = Vector2(60, 40)
	menu_btn.pressed.connect(_on_menu)
	_top_bar.add_child(menu_btn)

	return _top_bar


func _build_view_tabs() -> HBoxContainer:
	_view_tab_bar = HBoxContainer.new()
	_view_tab_bar.add_theme_constant_override("separation", 4)

	for tab_name in VIEW_TABS:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(100, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("view", tab_name)
		btn.pressed.connect(_on_view_tab_pressed.bind(tab_name))
		_update_view_tab_style(btn, tab_name == VIEW_TABS[0])
		_view_tab_bar.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_tab_bar.add_child(spacer)

	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "시장: 중립"
	phase_label.add_theme_font_size_override("font_size", 13)
	phase_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_view_tab_bar.add_child(phase_label)

	return _view_tab_bar


func _build_cat_tabs() -> HBoxContainer:
	_cat_tab_bar = HBoxContainer.new()
	_cat_tab_bar.add_theme_constant_override("separation", 4)

	for cat in CATEGORY_FILTERS:
		var btn := Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(70, 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.set_meta("category", cat)
		btn.pressed.connect(_on_cat_pressed.bind(cat))
		_update_cat_style(btn, cat == CATEGORY_FILTERS[0])
		_cat_tab_bar.add_child(btn)

	return _cat_tab_bar


# ═══════════════════════════════════════════════
#   시장 뷰
# ═══════════════════════════════════════════════

func _build_market_view() -> void:
	_market_view = VBoxContainer.new()
	_market_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_view.visible = false
	_content.add_child(_market_view)

	# 종목 스크롤
	_stock_scroll = ScrollContainer.new()
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_scroll.add_theme_stylebox_override("panel", _style_flat(COL_PANEL, 0))
	_market_view.add_child(_stock_scroll)

	_stock_list = VBoxContainer.new()
	_stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_list.add_theme_constant_override("separation", 2)
	_stock_scroll.add_child(_stock_list)

	# 매매 패널
	_trade_panel = PanelContainer.new()
	_trade_panel.add_theme_stylebox_override("panel", _style_flat(COL_PANEL_LIGHT, 6))
	_trade_panel.custom_minimum_size = Vector2(0, 90)
	_trade_panel.visible = false
	_market_view.add_child(_trade_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.offset_left = 16
	hbox.offset_top = 8
	hbox.offset_right = -16
	hbox.offset_bottom = -8
	_trade_panel.add_child(hbox)

	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 3)
	_trade_stock_name = Label.new()
	_trade_stock_name.add_theme_font_size_override("font_size", 18)
	_trade_stock_name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	info_box.add_child(_trade_stock_name)
	_trade_price_label = Label.new()
	_trade_price_label.add_theme_font_size_override("font_size", 14)
	info_box.add_child(_trade_price_label)
	_trade_holding_label = Label.new()
	_trade_holding_label.add_theme_font_size_override("font_size", 12)
	_trade_holding_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	info_box.add_child(_trade_holding_label)
	hbox.add_child(info_box)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

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
	_trade_qty_edit.custom_minimum_size = Vector2(100, 36)
	_trade_qty_edit.value_changed.connect(_on_qty_changed)
	action_box.add_child(_trade_qty_edit)

	_trade_total_label = Label.new()
	_trade_total_label.text = "0원"
	_trade_total_label.add_theme_font_size_override("font_size", 14)
	_trade_total_label.add_theme_color_override("font_color", COL_TEXT)
	_trade_total_label.custom_minimum_size = Vector2(130, 0)
	_trade_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trade_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_box.add_child(_trade_total_label)

	var buy_btn := Button.new()
	buy_btn.text = "매수"
	buy_btn.custom_minimum_size = Vector2(70, 36)
	buy_btn.add_theme_font_size_override("font_size", 15)
	buy_btn.add_theme_color_override("font_color", COL_UP)
	buy_btn.pressed.connect(_on_buy)
	action_box.add_child(buy_btn)

	var sell_btn := Button.new()
	sell_btn.text = "매도"
	sell_btn.custom_minimum_size = Vector2(70, 36)
	sell_btn.add_theme_font_size_override("font_size", 15)
	sell_btn.add_theme_color_override("font_color", COL_DOWN)
	sell_btn.pressed.connect(_on_sell)
	action_box.add_child(sell_btn)

	var close_btn := Button.new()
	close_btn.text = "x"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_close_trade_panel)
	action_box.add_child(close_btn)

	hbox.add_child(action_box)

	_populate_stock_list()


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
	btn.custom_minimum_size = Vector2(0, 56)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
	btn.add_theme_stylebox_override("hover", _style_flat(COL_PANEL_LIGHT, 4))
	btn.add_theme_stylebox_override("pressed", _style_flat(COL_PANEL_LIGHT, 4))
	btn.set_meta("stock_id", stock["id"])
	btn.pressed.connect(_on_stock_clicked.bind(stock["id"]))

	var hbox := HBoxContainer.new()
	hbox.offset_left = 12
	hbox.offset_top = 4
	hbox.offset_right = -12
	hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	# 이름 + 티커
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
	cat_label.text = _cat_tag(stock["category"])
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", _cat_color(stock["category"]))
	cat_label.custom_minimum_size = Vector2(35, 0)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cat_label)

	# 스파크라인
	var spark_script := load("res://scripts/Sparkline.gd")
	var spark := Control.new()
	spark.set_script(spark_script)
	spark.custom_minimum_size = Vector2(80, 40)
	spark.name = "Sparkline"
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(spark)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 보유 수량
	var hold_label := Label.new()
	hold_label.name = "HoldLabel"
	hold_label.add_theme_font_size_override("font_size", 12)
	hold_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	hold_label.custom_minimum_size = Vector2(70, 0)
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hold_label)

	# 가격
	var price := Label.new()
	price.name = "PriceLabel"
	price.text = _fmt_price(stock["price"])
	price.add_theme_font_size_override("font_size", 15)
	price.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	price.custom_minimum_size = Vector2(120, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(price)

	# 등락률
	var change := Label.new()
	change.name = "ChangeLabel"
	change.text = _fmt_change(stock.get("change_pct", 0.0))
	change.add_theme_font_size_override("font_size", 14)
	change.add_theme_color_override("font_color", _change_color(stock.get("change_pct", 0.0)))
	change.custom_minimum_size = Vector2(90, 0)
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(change)

	return btn


# ═══════════════════════════════════════════════
#   자동매매 뷰
# ═══════════════════════════════════════════════

func _build_autotrade_view() -> void:
	_autotrade_view = VBoxContainer.new()
	_autotrade_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_autotrade_view.visible = false
	_content.add_child(_autotrade_view)

	# 헤더
	var header := Label.new()
	header.text = "  자동매매 슬롯 — 조건을 설정하면 자동으로 거래합니다 (오프라인에도 실행)"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", COL_TEXT_DIM)
	_autotrade_view.add_child(header)

	_autotrade_slots.clear()
	for i in AutoTradeManager.MAX_SLOTS:
		var slot_ui := _create_autotrade_slot(i)
		_autotrade_view.add_child(slot_ui)
		_autotrade_slots.append(slot_ui)

	_refresh_autotrade_view()


func _create_autotrade_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_flat(COL_PANEL, 6))
	panel.custom_minimum_size = Vector2(0, 70)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	# 슬롯 헤더 (번호 + ON/OFF)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var slot_num := Label.new()
	slot_num.text = "  슬롯 %d" % (index + 1)
	slot_num.add_theme_font_size_override("font_size", 14)
	slot_num.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	header.add_child(slot_num)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var toggle := Button.new()
	toggle.text = "OFF"
	toggle.custom_minimum_size = Vector2(60, 28)
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.set_meta("slot_index", index)
	toggle.pressed.connect(_on_autotrade_toggle.bind(index))
	toggle.name = "ToggleButton"
	header.add_child(toggle)

	outer.add_child(header)

	# 설정 행
	var config_row := HBoxContainer.new()
	config_row.add_theme_constant_override("separation", 8)
	config_row.offset_left = 16
	config_row.offset_right = -16

	# 종목 선택
	var stock_opts := OptionButton.new()
	stock_opts.add_item("종목 선택", 0)
	for s in MarketSim.get_all_stocks():
		stock_opts.add_item("%s (%s)" % [s["name"], s["ticker"]], 0)
	stock_opts.set_meta("slot_index", index)
	stock_opts.custom_minimum_size = Vector2(160, 30)
	stock_opts.item_selected.connect(_on_autotrade_stock_changed.bind(index))
	stock_opts.name = "StockOption"
	config_row.add_child(stock_opts)

	# 조건 타입
	var cond_opts := OptionButton.new()
	for key in AutoTradeManager.CONDITION_TYPES:
		cond_opts.add_item(AutoTradeManager.CONDITION_TYPES[key])
	cond_opts.set_meta("slot_index", index)
	cond_opts.custom_minimum_size = Vector2(150, 30)
	cond_opts.item_selected.connect(_on_autotrade_cond_changed.bind(index))
	cond_opts.name = "CondOption"
	config_row.add_child(cond_opts)

	# 조건값
	var cond_val := SpinBox.new()
	cond_val.min_value = 0
	cond_val.max_value = 999999999
	cond_val.step = 1000
	cond_val.value = 50000
	cond_val.custom_minimum_size = Vector2(120, 30)
	cond_val.set_meta("slot_index", index)
	cond_val.value_changed.connect(_on_autotrade_val_changed.bind(index))
	cond_val.name = "CondValue"
	config_row.add_child(cond_val)

	# 매수/매도
	var action_opts := OptionButton.new()
	action_opts.add_item("매수")
	action_opts.add_item("매도")
	action_opts.set_meta("slot_index", index)
	action_opts.custom_minimum_size = Vector2(70, 30)
	action_opts.item_selected.connect(_on_autotrade_action_changed.bind(index))
	action_opts.name = "ActionOption"
	config_row.add_child(action_opts)

	# 수량
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 100000
	qty.value = 1
	qty.custom_minimum_size = Vector2(80, 30)
	qty.set_meta("slot_index", index)
	qty.value_changed.connect(_on_autotrade_qty_changed.bind(index))
	qty.name = "QtyValue"
	config_row.add_child(qty)

	outer.add_child(config_row)
	return panel


# ═══════════════════════════════════════════════
#   라이프 뷰
# ═══════════════════════════════════════════════

func _build_life_view() -> void:
	_life_view = VBoxContainer.new()
	_life_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_life_view.visible = false
	_content.add_child(_life_view)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_theme_stylebox_override("panel", _style_flat(COL_PANEL, 0))
	_life_view.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	scroll.add_child(inner)

	# 주거 섹션
	var house_header := Label.new()
	house_header.text = "  주거"
	house_header.add_theme_font_size_override("font_size", 18)
	house_header.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(house_header)

	_life_housing_container = VBoxContainer.new()
	_life_housing_container.add_theme_constant_override("separation", 3)
	inner.add_child(_life_housing_container)

	# 차량 섹션
	var veh_header := Label.new()
	veh_header.text = "  차량"
	veh_header.add_theme_font_size_override("font_size", 18)
	veh_header.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(veh_header)
	inner.add_child(_spacer(6))

	_life_vehicle_container = VBoxContainer.new()
	_life_vehicle_container.add_theme_constant_override("separation", 3)
	inner.add_child(_life_vehicle_container)

	_refresh_life_view()


func _refresh_life_view() -> void:
	# 주거
	for child in _life_housing_container.get_children():
		child.queue_free()
	var current_house_id: String = GameManager.player["house"]
	for i in range(GameManager.get_housing_list().size()):
		var h: Dictionary = GameManager.get_housing_list()[i]
		var is_current := h["id"] == current_house_id
		var is_locked := i > 0 and GameManager.get_housing_list()[i - 1]["id"] != current_house_id and not is_current
		var row := _create_life_row(h, "house", is_current, is_locked, i)
		_life_housing_container.add_child(row)

	# 차량
	for child in _life_vehicle_container.get_children():
		child.queue_free()
	var current_veh_id: String = GameManager.player["vehicle"]
	for i in range(GameManager.get_vehicle_list().size()):
		var v: Dictionary = GameManager.get_vehicle_list()[i]
		var is_current := v["id"] == current_veh_id
		var is_locked := i > 0 and GameManager.get_vehicle_list()[i - 1]["id"] != current_veh_id and not is_current
		var row := _create_life_row(v, "vehicle", is_current, is_locked, i)
		_life_vehicle_container.add_child(row)


func _create_life_row(item: Dictionary, type: String, is_current: bool, is_locked: bool, index: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 50)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)

	if is_current:
		btn.add_theme_stylebox_override("normal", _style_flat(Color(0.10, 0.15, 0.10, 1), 4))
		btn.add_theme_color_override("font_color", COL_UP)
	elif is_locked:
		btn.add_theme_stylebox_override("normal", _style_flat(Color(0.06, 0.06, 0.07, 1), 4))
		btn.add_theme_color_override("font_color", COL_TEXT_DIM)
		btn.disabled = true
	else:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
		btn.add_theme_stylebox_override("hover", _style_flat(COL_PANEL_LIGHT, 4))
		btn.add_theme_color_override("font_color", COL_TEXT)
		btn.pressed.connect(_on_life_buy.bind(type, item["id"]))

	var hbox := HBoxContainer.new()
	hbox.offset_left = 12
	hbox.offset_top = 4
	hbox.offset_right = -12
	hbox.offset_bottom = -4
	hbox.add_theme_constant_override("separation", 12)
	btn.add_child(hbox)

	# 이름
	var name := Label.new()
	name.text = item["name"]
	name.add_theme_font_size_override("font_size", 15)
	if is_current:
		name.text += "  (현재)"
		name.add_theme_color_override("font_color", COL_UP)
	elif is_locked:
		name.add_theme_color_override("font_color", COL_TEXT_DIM)
	else:
		name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 보너스
	var bonus := Label.new()
	var bonus_text := ""
	if item.get("energy_bonus", 0) > 0:
		bonus_text += "정보력 +%d  " % item["energy_bonus"]
	if item.get("happiness", 0) > 0:
		bonus_text += "행복 +%d" % item["happiness"]
	if bonus_text == "":
		bonus_text = "보너스 없음"
	bonus.text = bonus_text
	bonus.add_theme_font_size_override("font_size", 12)
	bonus.add_theme_color_override("font_color", COL_TEXT_DIM)
	bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(bonus)

	# 가격
	var price := Label.new()
	if is_current:
		price.text = "보유"
	elif is_locked:
		price.text = "잠금 (이전 단계 필요)"
	elif item["price"] == 0:
		price.text = "기본 제공"
	else:
		price.text = _fmt_won(item["price"])
	price.add_theme_font_size_override("font_size", 14)
	price.custom_minimum_size = Vector2(160, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not is_current and not is_locked:
		price.add_theme_color_override("font_color", COL_GOLD)
	hbox.add_child(price)

	return btn


# ═══════════════════════════════════════════════
#   뷰 전환
# ═══════════════════════════════════════════════

func _show_view(view_name: String) -> void:
	_current_view = view_name
	_market_view.visible = (view_name == "시장")
	_autotrade_view.visible = (view_name == "자동매매")
	_life_view.visible = (view_name == "라이프")
	_cat_tab_bar.visible = (view_name == "시장")

	for child in _view_tab_bar.get_children():
		if child is Button and child.has_meta("view"):
			_update_view_tab_style(child, child.get_meta("view") == view_name)


func _on_view_tab_pressed(view_name: String) -> void:
	_show_view(view_name)


func _update_view_tab_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", COL_TEXT)


# ═══════════════════════════════════════════════
#   이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_cat_pressed(cat: String) -> void:
	_current_category = CATEGORY_MAP[cat]
	for child in _cat_tab_bar.get_children():
		if child is Button and child.has_meta("category"):
			_update_cat_style(child, child.get_meta("category") == cat)
	_apply_category_filter()


func _update_cat_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", COL_TEXT)


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
		var avg: float = GameManager.get_holding(_selected_stock)["avg_price"]
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
		_show_toast("실패: " + result.get("reason", ""))


func _on_sell() -> void:
	if _selected_stock == "":
		return
	var qty := int(_trade_qty_edit.value)
	var result := GameManager.sell_stock(_selected_stock, qty)
	if result.get("success", false):
		var ptext := ""
		if result.has("profit"):
			var p: float = result["profit"]
			if p >= 0:
				ptext = " (수익 +%s)" % _fmt_won(p)
			else:
				ptext = " (손실 %s)" % _fmt_won(abs(p))
		_show_toast("매도 완료: %d주%s" % [qty, ptext])
		_update_trade_panel()
	else:
		_show_toast("실패: " + result.get("reason", ""))


func _on_advance_day() -> void:
	var result := GameManager.advance_day()
	MarketSim.advance_day()

	var msg := "%d일차 경과" % result["day"]
	if result.get("salary", 0.0) > 0:
		msg += " | 월급 +%s" % _fmt_won(result["salary"])
	if result.get("rank_up", "") != "":
		msg += " | 승진! → %s" % result["rank_up"]
		var rl := _top_bar.get_node_or_null("RankLabel")
		if rl is Label:
			(rl as Label).text = "  " + GameManager.get_rank_name()
	if result.has("bailout"):
		msg += " | 파산방지 지원금 +%s" % _fmt_won(result["bailout"])

	_day_label.text = "%d일차" % result["day"]
	_show_toast(msg)


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


func _on_day_advanced(day: int) -> void:
	_day_label.text = "%d일차" % day


func _on_rank_up(new_rank: String) -> void:
	var rl := _top_bar.get_node_or_null("RankLabel")
	if rl is Label:
		(rl as Label).text = "  " + new_rank
	_show_toast("승진! → %s" % new_rank)


func _on_salary_paid(amount: float) -> void:
	_show_toast("월급 지급: +%s" % _fmt_won(amount))


func _on_auto_trade_executed(slot: Dictionary, result: Dictionary) -> void:
	var stock := MarketSim.get_stock(slot["stock_id"])
	var action_text := "매수" if slot["action"] == "buy" else "매도"
	_show_toast("자동매매: %s %s %d주" % [stock.get("name", ""), action_text, slot["quantity"]])


# ═══════════════════════════════════════════════
#   자동매매 이벤트
# ═══════════════════════════════════════════════

func _on_autotrade_toggle(index: int) -> void:
	AutoTradeManager.toggle_slot(index)
	_refresh_autotrade_view()


func _on_autotrade_stock_changed(index: int) -> void:
	var panel: PanelContainer = _autotrade_slots[index]
	var opt: OptionButton = panel.get_node("StockOption")
	var sel := opt.selected
	if sel == 0:
		return
	var stock := MarketSim.get_all_stocks()[sel - 1]
	var slot := AutoTradeManager.get_slot(index)
	slot["stock_id"] = stock["id"]
	AutoTradeManager.set_slot(index, slot)


func _on_autotrade_cond_changed(index: int) -> void:
	var panel: PanelContainer = _autotrade_slots[index]
	var opt: OptionButton = panel.get_node("CondOption")
	var keys := AutoTradeManager.CONDITION_TYPES.keys()
	var sel_key: String = keys[opt.selected]
	var slot := AutoTradeManager.get_slot(index)
	slot["condition_type"] = sel_key
	AutoTradeManager.set_slot(index, slot)


func _on_autotrade_val_changed(value: float, index: int) -> void:
	var slot := AutoTradeManager.get_slot(index)
	slot["condition_value"] = value
	AutoTradeManager.set_slot(index, slot)


func _on_autotrade_action_changed(index: int) -> void:
	var panel: PanelContainer = _autotrade_slots[index]
	var opt: OptionButton = panel.get_node("ActionOption")
	var slot := AutoTradeManager.get_slot(index)
	slot["action"] = "buy" if opt.selected == 0 else "sell"
	AutoTradeManager.set_slot(index, slot)


func _on_autotrade_qty_changed(value: float, index: int) -> void:
	var slot := AutoTradeManager.get_slot(index)
	slot["quantity"] = int(value)
	AutoTradeManager.set_slot(index, slot)


func _on_life_buy(type: String, item_id: String) -> void:
	var result: Dictionary
	if type == "house":
		result = GameManager.buy_house(item_id)
	else:
		result = GameManager.buy_vehicle(item_id)

	if result.get("success", false):
		var name_text: String = result.get(type, {}).get("name", "")
		_show_toast("구매 완료: %s" % name_text)
		_refresh_life_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


func _refresh_autotrade_view() -> void:
	for i in AutoTradeManager.MAX_SLOTS:
		if i >= _autotrade_slots.size():
			break
		var panel: PanelContainer = _autotrade_slots[i]
		var slot := AutoTradeManager.get_slot(i)
		var toggle: Button = panel.get_node("ToggleButton")
		if slot["active"]:
			toggle.text = "ON"
			toggle.add_theme_color_override("font_color", COL_UP)
			toggle.add_theme_stylebox_override("normal", _style_flat(Color(0.10, 0.15, 0.10, 1), 4))
		else:
			toggle.text = "OFF"
			toggle.add_theme_color_override("font_color", COL_TEXT_DIM)
			toggle.add_theme_stylebox_override("normal", _style_flat(COL_PANEL, 4))


# ═══════════════════════════════════════════════
#   마켓 틱
# ═══════════════════════════════════════════════

func _on_market_tick() -> void:
	# 페이즈 표시
	var phase_label := _view_tab_bar.get_node_or_null("PhaseLabel")
	if phase_label is Label:
		var cycle := MarketSim.market_cycle
		if cycle > 0.3:
			(phase_label as Label).text = "시장: 강세 ↑"
			(phase_label as Label).add_theme_color_override("font_color", COL_UP)
		elif cycle < -0.3:
			(phase_label as Label).text = "시장: 약세 ↓"
			(phase_label as Label).add_theme_color_override("font_color", COL_DOWN)
		else:
			(phase_label as Label).text = "시장: 중립"
			(phase_label as Label).add_theme_color_override("font_color", COL_TEXT_DIM)

	# 행 업데이트
	for stock_id in _stock_rows:
		_update_stock_row(stock_id)

	# 순자산 갱신
	if _networth_label:
		_networth_label.text = _fmt_won(GameManager.get_net_worth())

	# 매매 패널
	if _trade_panel.visible:
		_update_trade_panel()

	# 자동매매 체크
	AutoTradeManager.check_and_execute()


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

	# 스파크라인 업데이트
	var spark := row.get_node_or_null("Sparkline")
	if spark and stock["history"].size() >= 2:
		var is_up: bool = stock.get("change_pct", 0.0) >= 0
		spark.set_data(stock["history"], is_up)


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
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast_label.visible = false)


func _stat_box(title: String, value: String, color: Color, meta: String) -> VBoxContainer:
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


func _cat_tag(cat: String) -> String:
	match cat:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return cat


func _cat_color(cat: String) -> Color:
	match cat:
		"korea": return Color(0.35, 0.60, 0.90, 1)
		"usa": return Color(0.75, 0.45, 0.85, 1)
		"coin": return COL_GOLD
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
	var abs_amount := absf(amount)
	if abs_amount >= 100_000_000:
		return "%.2f억원" % (amount / 100_000_000)
	elif abs_amount >= 10_000_000:
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


func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

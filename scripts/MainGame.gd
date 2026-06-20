extends Control
## MainGame — 메인 게임 화면
## 씬 에디터 기반: 정적 UI는 main.tscn에 정의, 동적 데이터만 코드에서 생성

const UIAnim := preload("res://scripts/UIAnim.gd")

# 색상 (Theme과 별도로 코드에서 직접 사용하는 색)
const COL_UP := Color(0.15, 0.65, 0.39, 1)
const COL_DOWN := Color(0.80, 0.27, 0.27, 1)
const COL_ACCENT := Color(0.20, 0.56, 0.85, 1)
const COL_GOLD := Color(0.85, 0.70, 0.30, 1)
const COL_TEXT_DIM := Color(0.50, 0.50, 0.55, 1)
const COL_TEXT_BRIGHT := Color(0.95, 0.95, 0.97, 1)
const COL_PANEL := Color(0.094, 0.098, 0.110, 1)
const COL_PANEL_LIGHT := Color(0.122, 0.126, 0.138, 1)

const CATEGORY_FILTERS := ["전체", "한국", "미국", "코인"]
const CATEGORY_MAP := {"전체": "", "한국": "korea", "미국": "usa", "코인": "coin"}
const VIEW_TABS := ["시장", "자동매매", "라이프", "NPC", "이벤트"]

# ─── 씬 노드 참조 (@onready로 씬 트리에서 자동 연결) ───
@onready var _rank_label: Label = %RankLabel
@onready var _cash_label: Label = %CashLabel
@onready var _networth_label: Label = %NetWorthLabel
@onready var _day_label: Label = %DayLabel
@onready var _advance_btn: Button = %AdvanceButton
@onready var _view_tabs: HBoxContainer = %ViewTabs
@onready var _cat_tabs: HBoxContainer = %CatTabs
@onready var _content: VBoxContainer = %ContentArea
@onready var _toast: Label = %ToastLabel

# 동적 생성되는 뷰
var _market_view: VBoxContainer
var _autotrade_view: VBoxContainer
var _life_view: VBoxContainer
var _current_view: String = "시장"

# 시장 뷰 내부
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

# 자동매매
var _autotrade_slots: Array = []

# 라이프
var _life_housing_container: VBoxContainer
var _life_vehicle_container: VBoxContainer

# NPC 뷰
var _npc_view: VBoxContainer
var _npc_container: VBoxContainer

# 이벤트 뷰
var _event_view: VBoxContainer
var _event_container: VBoxContainer

# 세대교체 버튼
var _gen_button: Button


# ═══════════════════════════════════════════════
func _ready() -> void:
	_init_static_ui()
	_build_market_view()
	_build_autotrade_view()
	_build_life_view()
	_build_npc_view()
	_build_event_view()
	_show_view("시장")
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
	_advance_btn.pressed.connect(_on_advance_day)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _show_view("시장")
			KEY_2: _show_view("자동매매")
			KEY_3: _show_view("라이프")
			KEY_4: _show_view("NPC")
			KEY_5: _show_view("이벤트")
			KEY_SPACE: if _current_view == "시장": _on_advance_day()
			KEY_ESCAPE: _close_trade_panel()


# ═══════════════════════════════════════════════
#   정적 UI 초기화 (씬에서 이미 생성된 노드에 이벤트 연결)
# ═══════════════════════════════════════════════

func _init_static_ui() -> void:
	_rank_label.text = "  " + GameManager.get_rank_name()
	_day_label.text = "%d일차" % GameManager.player["day"]

	# View 탭 버튼들 생성
	for tab_name in VIEW_TABS:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(100, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("view", tab_name)
		btn.pressed.connect(_on_view_tab_pressed.bind(tab_name))
		_update_view_tab_style(btn, tab_name == VIEW_TABS[0])
		_view_tabs.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_tabs.add_child(spacer)

	var phase_label := Label.new()
	phase_label.name = "PhaseLabel"
	phase_label.text = "시장: 중립"
	phase_label.add_theme_font_size_override("font_size", 13)
	phase_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_view_tabs.add_child(phase_label)

	# 카테고리 탭 버튼들
	for cat in CATEGORY_FILTERS:
		var btn := Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(70, 28)
		btn.add_theme_font_size_override("font_size", 13)
		btn.set_meta("category", cat)
		btn.pressed.connect(_on_cat_pressed.bind(cat))
		_update_cat_style(btn, cat == CATEGORY_FILTERS[0])
		_cat_tabs.add_child(btn)

	# 저장/메뉴 버튼
	var save_btn := _content.get_parent().get_node("TopBar/SaveButton") as Button
	save_btn.pressed.connect(_on_save)
	var menu_btn := _content.get_parent().get_node("TopBar/MenuButton") as Button
	menu_btn.pressed.connect(_on_menu)


# ═══════════════════════════════════════════════
#   시장 뷰
# ═══════════════════════════════════════════════

func _build_market_view() -> void:
	_market_view = VBoxContainer.new()
	_market_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_view.visible = false
	_content.add_child(_market_view)

	_stock_scroll = ScrollContainer.new()
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_scroll.add_theme_stylebox_override("panel", _flat(COL_PANEL, 0))
	_market_view.add_child(_stock_scroll)

	_stock_list = VBoxContainer.new()
	_stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_list.add_theme_constant_override("separation", 2)
	_stock_scroll.add_child(_stock_list)

	_build_trade_panel()
	_populate_stock_list()


func _build_trade_panel() -> void:
	_trade_panel = PanelContainer.new()
	_trade_panel.add_theme_stylebox_override("panel", _flat(COL_PANEL_LIGHT, 6))
	_trade_panel.custom_minimum_size = Vector2(0, 90)
	_trade_panel.visible = false
	_market_view.add_child(_trade_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	_trade_panel.add_child(hbox)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	_trade_stock_name = Label.new()
	_trade_stock_name.add_theme_font_size_override("font_size", 18)
	_trade_stock_name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	info.add_child(_trade_stock_name)
	_trade_price_label = Label.new()
	_trade_price_label.add_theme_font_size_override("font_size", 14)
	info.add_child(_trade_price_label)
	_trade_holding_label = Label.new()
	_trade_holding_label.add_theme_font_size_override("font_size", 12)
	_trade_holding_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	info.add_child(_trade_holding_label)
	hbox.add_child(info)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 8)
	act.alignment = BoxContainer.ALIGNMENT_END

	var ql := Label.new()
	ql.text = "수량"
	ql.add_theme_font_size_override("font_size", 13)
	ql.add_theme_color_override("font_color", COL_TEXT_DIM)
	ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	act.add_child(ql)

	_trade_qty_edit = SpinBox.new()
	_trade_qty_edit.min_value = 1
	_trade_qty_edit.max_value = 100000
	_trade_qty_edit.value = 1
	_trade_qty_edit.custom_minimum_size = Vector2(100, 36)
	_trade_qty_edit.value_changed.connect(_on_qty_changed)
	act.add_child(_trade_qty_edit)

	_trade_total_label = Label.new()
	_trade_total_label.text = "0원"
	_trade_total_label.add_theme_font_size_override("font_size", 14)
	_trade_total_label.custom_minimum_size = Vector2(130, 0)
	_trade_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trade_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	act.add_child(_trade_total_label)

	var buy := Button.new()
	buy.text = "매수"
	buy.custom_minimum_size = Vector2(70, 36)
	buy.add_theme_font_size_override("font_size", 15)
	buy.add_theme_color_override("font_color", COL_UP)
	buy.pressed.connect(_on_buy)
	act.add_child(buy)

	var sell := Button.new()
	sell.text = "매도"
	sell.custom_minimum_size = Vector2(70, 36)
	sell.add_theme_font_size_override("font_size", 15)
	sell.add_theme_color_override("font_color", COL_DOWN)
	sell.pressed.connect(_on_sell)
	act.add_child(sell)

	var close := Button.new()
	close.text = "x"
	close.custom_minimum_size = Vector2(36, 36)
	close.pressed.connect(_close_trade_panel)
	act.add_child(close)

	hbox.add_child(act)


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
	btn.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
	btn.add_theme_stylebox_override("hover", _flat(COL_PANEL_LIGHT, 4))
	btn.pressed.connect(_on_stock_clicked.bind(stock["id"]))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	btn.add_child(hbox)

	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 1)
	var name := Label.new()
	name.text = stock["name"]
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	nb.add_child(name)
	var meta := Label.new()
	meta.text = "%s · %s" % [stock.get("ticker", ""), stock.get("sector", "")]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	nb.add_child(meta)
	hbox.add_child(nb)

	var cat := Label.new()
	cat.text = _cat_tag(stock["category"])
	cat.add_theme_font_size_override("font_size", 11)
	cat.add_theme_color_override("font_color", _cat_color(stock["category"]))
	cat.custom_minimum_size = Vector2(35, 0)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cat)

	var spark_script := load("res://scripts/Sparkline.gd")
	var spark := Control.new()
	spark.set_script(spark_script)
	spark.custom_minimum_size = Vector2(80, 40)
	spark.name = "Sparkline"
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(spark)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	var hl := Label.new()
	hl.name = "HoldLabel"
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", COL_TEXT_DIM)
	hl.custom_minimum_size = Vector2(70, 0)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hl)

	var pl := Label.new()
	pl.name = "PriceLabel"
	pl.text = _fmt_price(stock["price"])
	pl.add_theme_font_size_override("font_size", 15)
	pl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	pl.custom_minimum_size = Vector2(120, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(pl)

	var cl := Label.new()
	cl.name = "ChangeLabel"
	cl.text = _fmt_change(stock.get("change_pct", 0.0))
	cl.add_theme_font_size_override("font_size", 14)
	cl.add_theme_color_override("font_color", _chg_color(stock.get("change_pct", 0.0)))
	cl.custom_minimum_size = Vector2(90, 0)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cl)

	return btn


# ═══════════════════════════════════════════════
#   자동매매 뷰
# ═══════════════════════════════════════════════

func _build_autotrade_view() -> void:
	_autotrade_view = VBoxContainer.new()
	_autotrade_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_autotrade_view.visible = false
	_content.add_child(_autotrade_view)

	var hdr := Label.new()
	hdr.text = "  자동매매 슬롯 — 조건 설정 시 자동 거래 (오프라인에도 실행)"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", COL_TEXT_DIM)
	_autotrade_view.add_child(hdr)

	_autotrade_slots.clear()
	for i in AutoTradeManager.MAX_SLOTS:
		var slot := _create_at_slot(i)
		_autotrade_view.add_child(slot)
		_autotrade_slots.append(slot)
	_refresh_at_view()


func _create_at_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 6))
	panel.custom_minimum_size = Vector2(0, 70)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	var num := Label.new()
	num.text = "  슬롯 %d" % (index + 1)
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	hdr.add_child(num)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var tog := Button.new()
	tog.text = "OFF"
	tog.custom_minimum_size = Vector2(60, 28)
	tog.name = "ToggleButton"
	tog.pressed.connect(_on_at_toggle.bind(index))
	hdr.add_child(tog)
	outer.add_child(hdr)

	var cfg := HBoxContainer.new()
	cfg.add_theme_constant_override("separation", 8)

	var stock_opt := OptionButton.new()
	stock_opt.add_item("종목 선택", 0)
	for s in MarketSim.get_all_stocks():
		stock_opt.add_item("%s (%s)" % [s["name"], s["ticker"]])
	stock_opt.name = "StockOption"
	stock_opt.custom_minimum_size = Vector2(160, 30)
	stock_opt.item_selected.connect(_on_at_stock.bind(index))
	cfg.add_child(stock_opt)

	var cond_opt := OptionButton.new()
	for key in AutoTradeManager.CONDITION_TYPES:
		cond_opt.add_item(AutoTradeManager.CONDITION_TYPES[key])
	cond_opt.name = "CondOption"
	cond_opt.custom_minimum_size = Vector2(150, 30)
	cond_opt.item_selected.connect(_on_at_cond.bind(index))
	cfg.add_child(cond_opt)

	var cv := SpinBox.new()
	cv.min_value = 0
	cv.max_value = 999999999
	cv.step = 1000
	cv.value = 50000
	cv.name = "CondValue"
	cv.custom_minimum_size = Vector2(120, 30)
	cv.value_changed.connect(_on_at_val.bind(index))
	cfg.add_child(cv)

	var act_opt := OptionButton.new()
	act_opt.add_item("매수")
	act_opt.add_item("매도")
	act_opt.name = "ActionOption"
	act_opt.custom_minimum_size = Vector2(70, 30)
	act_opt.item_selected.connect(_on_at_action.bind(index))
	cfg.add_child(act_opt)

	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 100000
	qty.value = 1
	qty.name = "QtyValue"
	qty.custom_minimum_size = Vector2(80, 30)
	qty.value_changed.connect(_on_at_qty.bind(index))
	cfg.add_child(qty)

	outer.add_child(cfg)
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
	_life_view.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	scroll.add_child(inner)

	var hh := Label.new()
	hh.text = "  주거"
	hh.add_theme_font_size_override("font_size", 18)
	hh.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(hh)

	_life_housing_container = VBoxContainer.new()
	_life_housing_container.add_theme_constant_override("separation", 3)
	inner.add_child(_life_housing_container)

	var vh := Label.new()
	vh.text = "  차량"
	vh.add_theme_font_size_override("font_size", 18)
	vh.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(vh)

	_life_vehicle_container = VBoxContainer.new()
	_life_vehicle_container.add_theme_constant_override("separation", 3)
	inner.add_child(_life_vehicle_container)

	_refresh_life_view()


func _refresh_life_view() -> void:
	for c in _life_housing_container.get_children():
		c.queue_free()
	var cur_house: String = GameManager.player["house"]
	for i in range(GameManager.get_housing_list().size()):
		var h: Dictionary = GameManager.get_housing_list()[i]
		var is_cur: bool = h["id"] == cur_house
		var locked: bool = i > 0 and GameManager.get_housing_list()[i - 1]["id"] != cur_house and not is_cur
		_life_housing_container.add_child(_life_row(h, "house", is_cur, locked, i))

	for c in _life_vehicle_container.get_children():
		c.queue_free()
	var cur_veh: String = GameManager.player["vehicle"]
	for i in range(GameManager.get_vehicle_list().size()):
		var v: Dictionary = GameManager.get_vehicle_list()[i]
		var is_cur: bool = v["id"] == cur_veh
		var locked: bool = i > 0 and GameManager.get_vehicle_list()[i - 1]["id"] != cur_veh and not is_cur
		_life_vehicle_container.add_child(_life_row(v, "vehicle", is_cur, locked, i))


func _life_row(item: Dictionary, type: String, is_cur: bool, locked: bool, _idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 50)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)

	if is_cur:
		btn.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.15, 0.10, 1), 4))
		btn.add_theme_color_override("font_color", COL_UP)
	elif locked:
		btn.add_theme_stylebox_override("normal", _flat(Color(0.06, 0.06, 0.07, 1), 4))
		btn.add_theme_color_override("font_color", COL_TEXT_DIM)
		btn.disabled = true
	else:
		btn.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
		btn.add_theme_stylebox_override("hover", _flat(COL_PANEL_LIGHT, 4))
		btn.pressed.connect(_on_life_buy.bind(type, item["id"]))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	btn.add_child(hbox)

	var name := Label.new()
	name.text = item["name"]
	name.add_theme_font_size_override("font_size", 15)
	if is_cur:
		name.text += "  (현재)"
		name.add_theme_color_override("font_color", COL_UP)
	elif locked:
		name.add_theme_color_override("font_color", COL_TEXT_DIM)
	else:
		name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	var bonus := Label.new()
	var bt := ""
	if item.get("energy_bonus", 0) > 0:
		bt += "정보력 +%d  " % item["energy_bonus"]
	if item.get("happiness", 0) > 0:
		bt += "행복 +%d" % item["happiness"]
	if bt == "":
		bt = "보너스 없음"
	bonus.text = bt
	bonus.add_theme_font_size_override("font_size", 12)
	bonus.add_theme_color_override("font_color", COL_TEXT_DIM)
	bonus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(bonus)

	var price := Label.new()
	if is_cur:
		price.text = "보유"
	elif locked:
		price.text = "잠금"
	elif item["price"] == 0:
		price.text = "기본"
	else:
		price.text = _fmt_won(item["price"])
	price.add_theme_font_size_override("font_size", 14)
	price.custom_minimum_size = Vector2(160, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not is_cur and not locked:
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
	_npc_view.visible = (view_name == "NPC")
	_event_view.visible = (view_name == "이벤트")
	_cat_tabs.visible = (view_name == "시장")
	for child in _view_tabs.get_children():
		if child is Button and child.has_meta("view"):
			_update_view_tab_style(child, child.get_meta("view") == view_name)
	# 뷰 진입 시 새로고침
	match view_name:
		"NPC": _refresh_npc_view()
		"이벤트": _refresh_event_view()


func _on_view_tab_pressed(vn: String) -> void:
	_show_view(vn)


func _update_view_tab_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85, 1))


# ═══════════════════════════════════════════════
#   이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_cat_pressed(cat: String) -> void:
	_current_category = CATEGORY_MAP[cat]
	for child in _cat_tabs.get_children():
		if child is Button and child.has_meta("category"):
			_update_cat_style(child, child.get_meta("category") == cat)
	_apply_cat_filter()


func _update_cat_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85, 1))


func _apply_cat_filter() -> void:
	for sid in _stock_rows:
		var row: Control = _stock_rows[sid]
		if _current_category == "":
			row.visible = true
		else:
			var s: Dictionary = MarketSim.get_stock(sid)
			row.visible = s.get("category") == _current_category


func _on_stock_clicked(sid: String) -> void:
	_selected_stock = sid
	_trade_panel.visible = true
	UIAnim.slide_in_from_bottom(_trade_panel, 20.0, 0.2)
	_update_trade_panel()


func _close_trade_panel() -> void:
	_trade_panel.visible = false
	_selected_stock = ""


func _update_trade_panel() -> void:
	if _selected_stock == "":
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	_trade_stock_name.text = "%s (%s)" % [s["name"], s.get("ticker", "")]
	_trade_price_label.text = _fmt_price(s["price"]) + "  " + _fmt_change(s.get("change_pct", 0.0))
	_trade_price_label.add_theme_color_override("font_color", _chg_color(s.get("change_pct", 0.0)))
	var q: int = GameManager.get_holding_quantity(_selected_stock)
	if q > 0:
		var avg: float = GameManager.get_holding(_selected_stock)["avg_price"]
		_trade_holding_label.text = "보유: %d주 | 평단가 %s" % [q, _fmt_price(avg)]
	else:
		_trade_holding_label.text = "보유 없음"
	_on_qty_changed(_trade_qty_edit.value)


func _on_qty_changed(value: float) -> void:
	if _selected_stock == "":
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	_trade_total_label.text = _fmt_won(s["price"] * int(value))


func _on_buy() -> void:
	if _selected_stock == "":
		return
	var qty := int(_trade_qty_edit.value)
	var r := GameManager.buy_stock(_selected_stock, qty)
	if r.get("success"):
		AudioManager.play_buy()
		UIAnim.pulse(_trade_panel)
		_show_toast("매수 완료: %d주 (%s)" % [qty, _fmt_won(r["cost"])])
		_update_trade_panel()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))


func _on_sell() -> void:
	if _selected_stock == "":
		return
	var qty := int(_trade_qty_edit.value)
	var r := GameManager.sell_stock(_selected_stock, qty)
	if r.get("success"):
		AudioManager.play_sell()
		UIAnim.pulse(_trade_panel)
		var pt := ""
		if r.has("profit"):
			var p: float = r["profit"]
			pt = " (수익 +%s)" % _fmt_won(p) if p >= 0 else " (손실 %s)" % _fmt_won(abs(p))
		_show_toast("매도 완료: %d주%s" % [qty, pt])
		_update_trade_panel()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))


func _on_advance_day() -> void:
	var r := GameManager.advance_day()
	MarketSim.advance_day()
	AudioManager.play_day_advance()
	var msg := "%d일차" % r["day"]
	if r.get("salary", 0.0) > 0:
		msg += " | 월급 +%s" % _fmt_won(r["salary"])
	if r.get("rank_up", "") != "":
		msg += " | 승진! -> %s" % r["rank_up"]
		_rank_label.text = "  " + GameManager.get_rank_name()
		AudioManager.play_rank_up()
		UIAnim.pop_in(_rank_label)
	if r.has("bailout"):
		msg += " | 파산방지 +%s" % _fmt_won(r["bailout"])
	_day_label.text = "%d일차" % r["day"]
	_show_toast(msg)

	# 일일 이벤트 발생
	var events := EventManager.roll_daily_events()
	for event in events:
		var etype: String = event.get("type", "")
		var etitle: String = event.get("title", "")
		var extra := ""
		if event.has("reward"):
			var rw: float = event["reward"]
			extra = " (%+.0f원)" % rw
		elif event.has("loss") and float(event["loss"]) > 0:
			extra = " (-%.0f원 손실)" % float(event["loss"])
		_show_toast("[이벤트] %s%s" % [etitle, extra])
		# 이벤트 사운드
		match etype:
			"news": AudioManager.play_event_news()
			"crypto_risk": AudioManager.play_event_bad()
			"life":
				if event.get("reward", 0.0) >= 0:
					AudioManager.play_event_news()
				else:
					AudioManager.play_event_bad()
	# 오래된 이벤트 정리
	EventManager.clear_old_events()


func _on_save() -> void:
	SaveManager.save_game()
	_show_toast("저장되었습니다")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/boot.tscn")


func _on_cash_changed(c: float) -> void:
	if _cash_label:
		_cash_label.text = _fmt_won(c)


func _on_net_worth_changed(nw: float) -> void:
	if _networth_label:
		_networth_label.text = _fmt_won(nw)


func _on_day_advanced(d: int) -> void:
	_day_label.text = "%d일차" % d


func _on_rank_up(nr: String) -> void:
	_rank_label.text = "  " + nr
	_show_toast("승진! → %s" % nr)


func _on_salary_paid(a: float) -> void:
	_show_toast("월급: +%s" % _fmt_won(a))


func _on_auto_trade_executed(slot: Dictionary, _r: Dictionary) -> void:
	var s: Dictionary = MarketSim.get_stock(slot["stock_id"])
	var act := "매수" if slot["action"] == "buy" else "매도"
	AudioManager.play_auto_trade()
	_show_toast("자동매매: %s %s %d주" % [s.get("name", ""), act, slot["quantity"]])


# 자동매매 이벤트
func _on_at_toggle(i: int) -> void:
	AutoTradeManager.toggle_slot(i)
	_refresh_at_view()


func _on_at_stock(i: int) -> void:
	var p: PanelContainer = _autotrade_slots[i]
	var opt: OptionButton = p.find_child("StockOption", true, false)
	if opt.selected == 0:
		return
	var s = MarketSim.get_all_stocks()[opt.selected - 1]
	var slot: Dictionary = AutoTradeManager.get_slot(i)
	slot["stock_id"] = s["id"]
	AutoTradeManager.set_slot(i, slot)


func _on_at_cond(i: int) -> void:
	var p: PanelContainer = _autotrade_slots[i]
	var opt: OptionButton = p.find_child("CondOption", true, false)
	var keys := AutoTradeManager.CONDITION_TYPES.keys()
	var slot: Dictionary = AutoTradeManager.get_slot(i)
	slot["condition_type"] = keys[opt.selected]
	AutoTradeManager.set_slot(i, slot)


func _on_at_val(v: float, i: int) -> void:
	var slot: Dictionary = AutoTradeManager.get_slot(i)
	slot["condition_value"] = v
	AutoTradeManager.set_slot(i, slot)


func _on_at_action(i: int) -> void:
	var p: PanelContainer = _autotrade_slots[i]
	var opt: OptionButton = p.find_child("ActionOption", true, false)
	var slot: Dictionary = AutoTradeManager.get_slot(i)
	slot["action"] = "buy" if opt.selected == 0 else "sell"
	AutoTradeManager.set_slot(i, slot)


func _on_at_qty(v: float, i: int) -> void:
	var slot: Dictionary = AutoTradeManager.get_slot(i)
	slot["quantity"] = int(v)
	AutoTradeManager.set_slot(i, slot)


func _on_life_buy(type: String, id: String) -> void:
	var r: Dictionary
	if type == "house":
		r = GameManager.buy_house(id)
	else:
		r = GameManager.buy_vehicle(id)
	if r.get("success"):
		_show_toast("구매 완료: %s" % r.get(type, {}).get("name", ""))
		_refresh_life_view()
	else:
		_show_toast("실패: " + r.get("reason", ""))


func _refresh_at_view() -> void:
	for i in AutoTradeManager.MAX_SLOTS:
		if i >= _autotrade_slots.size():
			break
		var p: PanelContainer = _autotrade_slots[i]
		var slot: Dictionary = AutoTradeManager.get_slot(i)
		var tog: Button = p.find_child("ToggleButton", true, false)
		if slot["active"]:
			tog.text = "ON"
			tog.add_theme_color_override("font_color", COL_UP)
			tog.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.15, 0.10, 1), 4))
		else:
			tog.text = "OFF"
			tog.add_theme_color_override("font_color", COL_TEXT_DIM)
			tog.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))


# ═══════════════════════════════════════════════
#   마켓 틱
# ═══════════════════════════════════════════════

func _on_market_tick() -> void:
	var pl := _view_tabs.get_node_or_null("PhaseLabel")
	if pl is Label:
		var c := MarketSim.market_cycle
		if c > 0.3:
			(pl as Label).text = "시장: 강세 ↑"
			(pl as Label).add_theme_color_override("font_color", COL_UP)
		elif c < -0.3:
			(pl as Label).text = "시장: 약세 ↓"
			(pl as Label).add_theme_color_override("font_color", COL_DOWN)
		else:
			(pl as Label).text = "시장: 중립"
			(pl as Label).add_theme_color_override("font_color", COL_TEXT_DIM)

	for sid in _stock_rows:
		_update_stock_row(sid)

	if _networth_label:
		_networth_label.text = _fmt_won(GameManager.get_net_worth())

	if _trade_panel.visible:
		_update_trade_panel()

	AutoTradeManager.check_and_execute()


func _update_stock_row(sid: String) -> void:
	var row: Control = _stock_rows.get(sid)
	if not row:
		return
	var s: Dictionary = MarketSim.get_stock(sid)
	if s.is_empty():
		return

	var pl := row.get_node_or_null("PriceLabel")
	if pl is Label:
		(pl as Label).text = _fmt_price(s["price"])

	var cl := row.get_node_or_null("ChangeLabel")
	if cl is Label:
		var pct: float = s.get("change_pct", 0.0)
		(cl as Label).text = _fmt_change(pct)
		(cl as Label).add_theme_color_override("font_color", _chg_color(pct))

	var hl := row.get_node_or_null("HoldLabel")
	if hl is Label:
		var q: int = GameManager.get_holding_quantity(sid)
		if q > 0:
			(hl as Label).text = "%d주" % q
			(hl as Label).add_theme_color_override("font_color", COL_ACCENT)
		else:
			(hl as Label).text = ""

	var spark := row.get_node_or_null("Sparkline")
	if spark and s["history"].size() >= 2:
		spark.set_data(s["history"], s.get("change_pct", 0.0) >= 0)


# ═══════════════════════════════════════════════
#   NPC 뷰
# ═══════════════════════════════════════════════

func _build_npc_view() -> void:
	_npc_view = VBoxContainer.new()
	_npc_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_npc_view.visible = false
	_content.add_child(_npc_view)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_npc_view.add_child(scroll)

	_npc_container = VBoxContainer.new()
	_npc_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_npc_container)

	# 세대교체 버튼 (결혼한 경우만)
	_gen_button = Button.new()
	_gen_button.text = "세대교체 (New Game+)"
	_gen_button.custom_minimum_size = Vector2(0, 44)
	_gen_button.add_theme_font_size_override("font_size", 15)
	_gen_button.add_theme_color_override("font_color", COL_GOLD)
	_gen_button.pressed.connect(_on_generation_advance)
	_npc_view.add_child(_gen_button)


func _refresh_npc_view() -> void:
	for c in _npc_container.get_children():
		c.queue_free()

	# 결혼 상태 표시
	var spouse_id := NPCManager.get_spouse_id()
	if spouse_id != "":
		var spouse := NPCManager.get_spouse()
		var sbox := _npc_section_label("결혼 중: %s (%s)" % [spouse.get("name", ""), spouse.get("role", "")])
		_npc_container.add_child(sbox)
		# 버프 표시
		var buff_label := Label.new()
		buff_label.text = "  버프: %s | 디버프: %s" % [spouse.get("buff", "-"), spouse.get("debuff", "-")]
		buff_label.add_theme_font_size_override("font_size", 12)
		buff_label.add_theme_color_override("font_color", COL_UP)
		_npc_container.add_child(buff_label)
		_npc_container.add_child(_spacer(8))

	# 라이벌 섹션
	_npc_container.add_child(_npc_section_label("라이벌"))
	for npc in NPCManager.get_npcs_by_category("rivals"):
		_npc_container.add_child(_create_npc_row(npc, "rival"))
	_npc_container.add_child(_spacer(8))

	# 도움 NPC 섹션
	_npc_container.add_child(_npc_section_label("도움 NPC"))
	for npc in NPCManager.get_npcs_by_category("helpers"):
		_npc_container.add_child(_create_npc_row(npc, "helper"))
	_npc_container.add_child(_spacer(8))

	# 결혼 대상 섹션
	_npc_container.add_child(_npc_section_label("결혼 대상"))
	for npc in NPCManager.get_npcs_by_category("marriage_targets"):
		_npc_container.add_child(_create_npc_row(npc, "marriage"))

	# 세대교체 버튼 가시성
	_gen_button.visible = NPCManager.is_married()


func _npc_section_label(text: String) -> Label:
	var l := Label.new()
	l.text = "  " + text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", COL_ACCENT)
	return l


func _create_npc_row(npc: Dictionary, type: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 6))
	panel.custom_minimum_size = Vector2(0, 80)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# 이름 + 역할
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 1)

	var name := Label.new()
	name.text = "  " + npc.get("name", "")
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_box.add_child(name)

	var role := Label.new()
	role.text = "  " + npc.get("role", "")
	role.add_theme_font_size_override("font_size", 11)
	role.add_theme_color_override("font_color", COL_TEXT_DIM)
	name_box.add_child(role)
	hbox.add_child(name_box)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	# 호감도
	var aff := NPCManager.get_affinity(npc["id"])
	var aff_label := Label.new()
	aff_label.text = "%s (%d)" % [NPCManager.get_affinity_level(npc["id"]), aff]
	aff_label.add_theme_font_size_override("font_size", 13)
	aff_label.custom_minimum_size = Vector2(100, 0)
	aff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	aff_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if aff >= 50:
		aff_label.add_theme_color_override("font_color", COL_UP)
	elif aff < 0:
		aff_label.add_theme_color_override("font_color", COL_DOWN)
	else:
		aff_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	hbox.add_child(aff_label)

	vbox.add_child(hbox)

	# 설명 + 액션 버튼
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_box_offset(action_row)

	var desc := Label.new()
	desc.text = "  " + npc.get("desc", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", COL_TEXT_DIM)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(desc)

	# 타입별 액션 버튼
	match type:
		"rival":
			var btn := Button.new()
			btn.text = "대결"
			btn.custom_minimum_size = Vector2(60, 28)
			btn.add_theme_font_size_override("font_size", 12)
			btn.add_theme_color_override("font_color", COL_DOWN)
			btn.pressed.connect(_on_rival_challenge.bind(npc["id"]))
			action_row.add_child(btn)

			# 전적
			var record := NPCManager.get_rival_record(npc["id"])
			var rec_label := Label.new()
			rec_label.text = "W%d/L%d" % [record.get("wins", 0), record.get("losses", 0)]
			rec_label.add_theme_font_size_override("font_size", 11)
			rec_label.add_theme_color_override("font_color", COL_TEXT_DIM)
			action_row.add_child(rec_label)

		"helper":
			var svc_btn := Button.new()
			var cost: float = float(npc.get("service_cost", 0))
			svc_btn.text = "서비스" + (" (%.0f만)" % (cost / 10000) if cost > 0 else "")
			svc_btn.custom_minimum_size = Vector2(90, 28)
			svc_btn.add_theme_font_size_override("font_size", 12)
			svc_btn.pressed.connect(_on_helper_service.bind(npc["id"]))
			action_row.add_child(svc_btn)

		"marriage":
			if NPCManager.get_spouse_id() == npc["id"]:
				var cur := Label.new()
				cur.text = "배우자"
				cur.add_theme_font_size_override("font_size", 13)
				cur.add_theme_color_override("font_color", COL_UP)
				action_row.add_child(cur)
			elif not NPCManager.is_married():
				var gift_btn := Button.new()
				gift_btn.text = "선물 (100만)"
				gift_btn.custom_minimum_size = Vector2(90, 28)
				gift_btn.add_theme_font_size_override("font_size", 12)
				gift_btn.add_theme_color_override("font_color", COL_ACCENT)
				gift_btn.pressed.connect(_on_give_gift.bind(npc["id"], 1000000))
				action_row.add_child(gift_btn)

				var req: int = int(npc.get("required_affinity", 80))
				if NPCManager.get_affinity(npc["id"]) >= req:
					var marry_btn := Button.new()
					marry_btn.text = "프로포즈"
					marry_btn.custom_minimum_size = Vector2(80, 28)
					marry_btn.add_theme_font_size_override("font_size", 12)
					marry_btn.add_theme_color_override("font_color", COL_UP)
					marry_btn.pressed.connect(_on_marry.bind(npc["id"]))
					action_row.add_child(marry_btn)

	vbox.add_child(action_row)
	return panel


func action_box_offset(row: HBoxContainer) -> void:
	row.offset_left = 16
	row.offset_right = -16


# ═══════════════════════════════════════════════
#   이벤트 뷰
# ═══════════════════════════════════════════════

func _build_event_view() -> void:
	_event_view = VBoxContainer.new()
	_event_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_view.visible = false
	_content.add_child(_event_view)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_event_view.add_child(scroll)

	_event_container = VBoxContainer.new()
	_event_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_event_container)


func _refresh_event_view() -> void:
	for c in _event_container.get_children():
		c.queue_free()

	var events := EventManager.get_active_events()
	if events.is_empty():
		var empty := Label.new()
		empty.text = "  진행 중인 이벤트가 없습니다"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", COL_TEXT_DIM)
		_event_container.add_child(empty)
		return

	# 최신순 정렬
	events.reverse()

	for event in events:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 4))
		panel.custom_minimum_size = Vector2(0, 60)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		# 타입 아이콘 (텍스트)
		var type_text := ""
		var type_color: Color = COL_TEXT_DIM
		match event.get("type", ""):
			"news":
				type_text = "[뉴스]"
				type_color = COL_ACCENT
			"crypto_risk":
				type_text = "[코인리스크]"
				type_color = COL_DOWN
			"life":
				type_text = "[생활]"
				type_color = COL_UP

		var tag := Label.new()
		tag.text = "  " + type_text
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", type_color)
		hbox.add_child(tag)

		var day := Label.new()
		day.text = "%d일차" % event.get("day", 0)
		day.add_theme_font_size_override("font_size", 11)
		day.add_theme_color_override("font_color", COL_TEXT_DIM)
		hbox.add_child(day)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(sp)

		# 손익 표시
		if event.has("reward"):
			var reward: float = event["reward"]
			var r_label := Label.new()
			if reward >= 0:
				r_label.text = "+%.0f원" % reward
				r_label.add_theme_color_override("font_color", COL_UP)
			else:
				r_label.text = "%.0f원" % reward
				r_label.add_theme_color_override("font_color", COL_DOWN)
			r_label.add_theme_font_size_override("font_size", 13)
			hbox.add_child(r_label)
		elif event.has("loss") and float(event["loss"]) > 0:
			var l_label := Label.new()
			l_label.text = "-%.0f원 손실" % float(event["loss"])
			l_label.add_theme_font_size_override("font_size", 13)
			l_label.add_theme_color_override("font_color", COL_DOWN)
			hbox.add_child(l_label)

		vbox.add_child(hbox)

		# 제목 + 설명
		var title := Label.new()
		title.text = "  " + event.get("title", "")
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
		vbox.add_child(title)

		var desc := Label.new()
		desc.text = "  " + event.get("desc", "")
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(desc)

		_event_container.add_child(panel)


# ═══════════════════════════════════════════════
#   NPC 이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_rival_challenge(npc_id: String) -> void:
	var result := NPCManager.challenge_rival(npc_id)
	if result.get("success"):
		if result.get("won"):
			_show_toast("승리! 보상 +%s" % _fmt_won(result["reward"]))
		else:
			_show_toast("패배... -%s" % _fmt_won(result["penalty"]))
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


func _on_helper_service(npc_id: String) -> void:
	var result := NPCManager.use_helper_service(npc_id)
	if result.get("success"):
		_show_toast(result.get("desc", "서비스 완료"))
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


func _on_give_gift(npc_id: String, amount: float) -> void:
	var result := NPCManager.give_gift(npc_id, amount)
	if result.get("success"):
		_show_toast("호감도 +%d → %d" % [result["gain"], result["affinity"]])
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


func _on_marry(npc_id: String) -> void:
	var result := NPCManager.marry(npc_id)
	if result.get("success"):
		var npc: Dictionary = result["npc"]
		AudioManager.play_marriage()
		_show_toast("결혼! %s와(과) 결혼했습니다" % npc.get("name", ""))
		_refresh_npc_view()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + result.get("reason", ""))


func _on_generation_advance() -> void:
	var result := NPCManager.start_new_generation()
	if result.get("success"):
		_show_toast("세대교체! %d대 — 상속 %s" % [result["new_generation"], _fmt_won(result["inherited_cash"])])
		_refresh_npc_view()
		_refresh_all()
		_refresh_life_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


# ═══════════════════════════════════════════════
#   헬퍼
# ═══════════════════════════════════════════════

func _refresh_all() -> void:
	_on_cash_changed(GameManager.get_cash())
	_on_net_worth_changed(GameManager.get_net_worth())


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.position.y = 70
	# 슬라이드 인 + 페이드 아웃
	var tw := create_tween()
	tw.tween_property(_toast, "position:y", 60, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(1.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _toast.visible = false)


func _cat_tag(c: String) -> String:
	match c:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return c


func _cat_color(c: String) -> Color:
	match c:
		"korea": return Color(0.35, 0.60, 0.90, 1)
		"usa": return Color(0.75, 0.45, 0.85, 1)
		"coin": return COL_GOLD
		_: return COL_TEXT_DIM


func _chg_color(p: float) -> Color:
	if p > 0.01: return COL_UP
	if p < -0.01: return COL_DOWN
	return COL_TEXT_DIM


func _fmt_price(p: float) -> String:
	if p >= 100_000_000:
		return "%.2f억" % (p / 100_000_000)
	return "%.0f" % int(p) + "원"


func _fmt_won(a: float) -> String:
	var ab := absf(a)
	if ab >= 100_000_000:
		return "%.2f억원" % (a / 100_000_000)
	elif ab >= 10_000_000:
		return "%.1f천만원" % (a / 10_000_000)
	return "%.0f" % a + "원"


func _fmt_change(p: float) -> String:
	var sign := "+" if p >= 0 else ""
	return sign + "%.2f" % p + "%"



func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s

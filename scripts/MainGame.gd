extends Control
## MainGame — 메인 게임 화면
## 씬 에디터 기반: 정적 UI는 main.tscn에 정의, 동적 데이터만 코드에서 생성

const UIAnim := preload("res://scripts/UIAnim.gd")
const IconGenerator := preload("res://scripts/IconGenerator.gd")

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
const VIEW_TABS := ["시장", "자동매매", "자산", "NPC", "진행"]

# ─── 씬 노드 참조 (@onready로 씬 트리에서 자동 연결) ───
@onready var _rank_label: Label = %RankLabel
@onready var _cash_label: Label = %CashLabel
@onready var _networth_label: Label = %NetWorthLabel
@onready var _day_label: Label = %DayLabel
@onready var _day_progress: ProgressBar = %DayProgress
@onready var _passive_label: Label = %PassiveLabel
@onready var _pause_btn: Button = %PauseButton
@onready var _speed1_btn: Button = %Speed1x
@onready var _speed2_btn: Button = %Speed2x
@onready var _speed4_btn: Button = %Speed4x
@onready var _view_tabs: HBoxContainer = %ViewTabs
@onready var _cat_tabs: HBoxContainer = %CatTabs
@onready var _content: VBoxContainer = %ContentArea
@onready var _toast: Label = %ToastLabel

# 동적 생성되는 뷰
var _market_view: HBoxContainer
var _autotrade_view: VBoxContainer
var _asset_view: VBoxContainer
var _current_view: String = "시장"

# 시장 뷰 내부
var _stock_scroll: ScrollContainer
var _stock_list: VBoxContainer
var _detail_panel: PanelContainer  # 오른쪽 상세 패널 (기존 _trade_panel 대체)
var _stock_rows: Dictionary = {}
var _current_category: String = ""
var _selected_stock: String = ""

# 상세 패널 위젯
var _detail_name: Label
var _detail_ticker: Label
var _detail_price: Label
var _detail_change: Label
var _detail_meta: Label
var _detail_holding: Label
var _detail_avg_price: Label
var _detail_eval_amount: Label
var _detail_eval_pnl: Label
var _detail_sparkline: Control
var _trade_qty_edit: SpinBox
var _trade_total_label: Label

# 자동매매
var _autotrade_slots: Array = []

# 라이프
var _asset_housing_container: VBoxContainer
var _asset_vehicle_container: VBoxContainer

# NPC 뷰
var _npc_view: VBoxContainer
var _npc_container: VBoxContainer

# 이벤트 뷰
var _progress_view: VBoxContainer
var _progress_subtabs: HBoxContainer
var _progress_content: VBoxContainer
var _progress_subtab: String = "뉴스"
var _event_container: VBoxContainer
var _quest_container: VBoxContainer
var _achievement_container: VBoxContainer
var _story_container: VBoxContainer
var _tutorial_container: VBoxContainer
var _cutscene_popup: PanelContainer
var _achievement_cat_filter: String = ""

# 사업 뷰
var _asset_business_container: VBoxContainer
var _asset_breakdown_container: VBoxContainer
var _business_cat_filter: String = ""

# 세대교체 버튼
var _gen_button: Button


# ═══════════════════════════════════════════════
func _ready() -> void:
	_init_static_ui()
	_build_market_view()
	_build_autotrade_view()
	_build_asset_view()
	_build_npc_view()
	_build_progress_view()
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
	# 시간 컨트롤 버튼
	_pause_btn.pressed.connect(_on_pause_toggle)
	# 자동 시간 흐름 시그널
	GameClockManager.day_advanced.connect(_on_clock_day_advanced)
	GameClockManager.time_changed.connect(_on_time_changed)
	GameClockManager.phase_changed.connect(_on_phase_changed)
	GameClockManager.pre_market_started.connect(_on_pre_market_started)
	GameClockManager.market_opened.connect(_on_market_opened)
	GameClockManager.market_closed.connect(_on_market_closed)
	GameClockManager.hourly_price_update.connect(_on_hourly_price_update)
	# 퀘스트/업적/스토리 알림
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.achievement_unlocked.connect(_on_achievement_unlocked)
	StoryManager.chapter_started.connect(_on_story_chapter_started)
	StoryManager.story_event.connect(_on_story_event)
	# 시간 컨트롤 버튼
	_pause_btn.pressed.connect(_on_pause_toggle)
	_speed1_btn.pressed.connect(_on_speed_change.bind(1.0))
	_speed2_btn.pressed.connect(_on_speed_change.bind(2.0))
	_speed4_btn.pressed.connect(_on_speed_change.bind(4.0))
	_update_speed_button_styles()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _show_view("시장")
			KEY_2: _show_view("자동매매")
			KEY_3: _show_view("자산")
			KEY_4: _show_view("NPC")
			KEY_5: _show_view("진행")
			KEY_ESCAPE: _close_trade_panel()
			KEY_F11:
				var mode := DisplayServer.window_get_mode()
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ═══════════════════════════════════════════════
#   정적 UI 초기화 (씬에서 이미 생성된 노드에 이벤트 연결)
# ═══════════════════════════════════════════════

func _init_static_ui() -> void:
	_rank_label.text = "  " + GameManager.get_rank_name()
	_day_label.text = "%d일차 %s" % [GameManager.player["day"], GameClockManager.get_time_string()]
	if _day_progress:
		_day_progress.value = 0.0

	# View 탭 버튼들 생성
	for tab_name in VIEW_TABS:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(120, 42)
		btn.add_theme_font_size_override("font_size", 17)
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
	phase_label.add_theme_font_size_override("font_size", 16)
	phase_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	_view_tabs.add_child(phase_label)

	# 카테고리 탭 버튼들
	for cat in CATEGORY_FILTERS:
		var btn := Button.new()
		btn.text = cat
		btn.custom_minimum_size = Vector2(80, 34)
		btn.add_theme_font_size_override("font_size", 15)
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
	_market_view = HBoxContainer.new()
	_market_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market_view.visible = false
	_market_view.add_theme_constant_override("separation", 8)
	_content.add_child(_market_view)

	# ── 왼쪽: 종목 리스트 ──
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.3
	_market_view.add_child(left_col)

	_stock_scroll = ScrollContainer.new()
	_stock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stock_scroll.add_theme_stylebox_override("panel", _flat(COL_PANEL, 0))
	left_col.add_child(_stock_scroll)

	_stock_list = VBoxContainer.new()
	_stock_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stock_list.add_theme_constant_override("separation", 4)
	_stock_scroll.add_child(_stock_list)

	# ── 오른쪽: 상세 패널 ──
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0
	_market_view.add_child(right_col)

	_build_detail_panel(right_col)
	_populate_stock_list()


func _build_detail_panel(parent: VBoxContainer) -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", _flat(COL_PANEL_LIGHT, 6))
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_detail_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.offset_left = 16
	vbox.offset_top = 12
	vbox.offset_right = -16
	vbox.offset_bottom = -12
	_detail_panel.add_child(vbox)

	# 종목명
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	vbox.add_child(_detail_name)

	# 티커 / 메타
	_detail_ticker = Label.new()
	_detail_ticker.add_theme_font_size_override("font_size", 14)
	_detail_ticker.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(_detail_ticker)

	_detail_meta = Label.new()
	_detail_meta.add_theme_font_size_override("font_size", 14)
	_detail_meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(_detail_meta)

	# 스파크라인
	var spark_script := load("res://scripts/Sparkline.gd")
	_detail_sparkline = Control.new()
	_detail_sparkline.set_script(spark_script)
	_detail_sparkline.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(_detail_sparkline)

	# 현재가 + 등락률
	_detail_price = Label.new()
	_detail_price.add_theme_font_size_override("font_size", 24)
	_detail_price.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	vbox.add_child(_detail_price)

	_detail_change = Label.new()
	_detail_change.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_detail_change)

	# 보유 정보
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	_detail_holding = Label.new()
	_detail_holding.add_theme_font_size_override("font_size", 15)
	_detail_holding.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(_detail_holding)

	_detail_avg_price = Label.new()
	_detail_avg_price.add_theme_font_size_override("font_size", 15)
	_detail_avg_price.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(_detail_avg_price)

	_detail_eval_amount = Label.new()
	_detail_eval_amount.add_theme_font_size_override("font_size", 15)
	_detail_eval_amount.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(_detail_eval_amount)

	_detail_eval_pnl = Label.new()
	_detail_eval_pnl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_detail_eval_pnl)

	# 매수/매도 영역
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var trade_hbox := HBoxContainer.new()
	trade_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(trade_hbox)

	var ql := Label.new()
	ql.text = "수량"
	ql.add_theme_font_size_override("font_size", 15)
	ql.add_theme_color_override("font_color", COL_TEXT_DIM)
	ql.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trade_hbox.add_child(ql)

	_trade_qty_edit = SpinBox.new()
	_trade_qty_edit.min_value = 1
	_trade_qty_edit.max_value = 100000
	_trade_qty_edit.value = 1
	_trade_qty_edit.custom_minimum_size = Vector2(120, 42)
	_trade_qty_edit.value_changed.connect(_on_qty_changed)
	trade_hbox.add_child(_trade_qty_edit)

	_trade_total_label = Label.new()
	_trade_total_label.text = "0원"
	_trade_total_label.add_theme_font_size_override("font_size", 17)
	_trade_total_label.custom_minimum_size = Vector2(140, 0)
	_trade_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trade_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trade_hbox.add_child(_trade_total_label)

	# 빠른 수량 버튼
	var qty_row := HBoxContainer.new()
	qtyRow_add_buttons(qty_row)
	vbox.add_child(qty_row)

	# 매수/매도 버튼
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var buy := Button.new()
	buy.text = "매수"
	buy.custom_minimum_size = Vector2(0, 44)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_font_size_override("font_size", 18)
	buy.add_theme_color_override("font_color", COL_UP)
	buy.pressed.connect(_on_buy)
	btn_row.add_child(buy)

	var sell := Button.new()
	sell.text = "매도"
	sell.custom_minimum_size = Vector2(0, 44)
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.add_theme_font_size_override("font_size", 18)
	sell.add_theme_color_override("font_color", COL_DOWN)
	sell.pressed.connect(_on_sell)
	btn_row.add_child(sell)

# SpinBox 빠른 수량 버튼 추가
func qtyRow_add_buttons(row: HBoxContainer) -> void:
	row.add_theme_constant_override("separation", 6)
	var labels := ["+1", "+10", "+100", "최대"]
	for lbl in labels:
		var btn := Button.new()
		btn.text = lbl
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", COL_TEXT_DIM)
		match lbl:
			"+1": btn.pressed.connect(func(): _trade_qty_edit.value += 1)
			"+10": btn.pressed.connect(func(): _trade_qty_edit.value += 10)
			"+100": btn.pressed.connect(func(): _trade_qty_edit.value += 100)
			"최대":
				btn.pressed.connect(func():
					if _selected_stock != "":
						var s := MarketSim.get_stock(_selected_stock)
						if not s.is_empty():
							var cash := GameManager.get_cash()
							var max_qty := int(cash / float(s["price"]))
							if max_qty < 1:
								max_qty = 1
							_trade_qty_edit.value = max_qty
				)
		row.add_child(btn)


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
	btn.custom_minimum_size = Vector2(0, 72)
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
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	nb.add_child(name)
	var meta := Label.new()
	meta.text = "%s · %s" % [stock.get("ticker", ""), stock.get("sector", "")]
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	nb.add_child(meta)
	hbox.add_child(nb)

	var cat := Label.new()
	cat.text = _cat_tag(stock["category"])
	cat.add_theme_font_size_override("font_size", 14)
	cat.add_theme_color_override("font_color", _cat_color(stock["category"]))
	cat.custom_minimum_size = Vector2(35, 0)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cat)

	var spark_script := load("res://scripts/Sparkline.gd")
	var spark := Control.new()
	spark.set_script(spark_script)
	spark.custom_minimum_size = Vector2(100, 50)
	spark.name = "Sparkline"
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(spark)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(sp)

	var hl := Label.new()
	hl.name = "HoldLabel"
	hl.add_theme_font_size_override("font_size", 14)
	hl.add_theme_color_override("font_color", COL_TEXT_DIM)
	hl.custom_minimum_size = Vector2(70, 0)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hl)

	var pl := Label.new()
	pl.name = "PriceLabel"
	pl.text = _fmt_price(stock["price"])
	pl.add_theme_font_size_override("font_size", 18)
	pl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	pl.custom_minimum_size = Vector2(140, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(pl)

	var cl := Label.new()
	cl.name = "ChangeLabel"
	cl.text = _fmt_change(stock.get("change_pct", 0.0))
	cl.add_theme_font_size_override("font_size", 17)
	cl.add_theme_color_override("font_color", _chg_color(stock.get("change_pct", 0.0)))
	cl.custom_minimum_size = Vector2(100, 0)
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
	hdr.add_theme_font_size_override("font_size", 16)
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
	panel.custom_minimum_size = Vector2(0, 80)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	panel.add_child(outer)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	var num := Label.new()
	num.text = "  슬롯 %d" % (index + 1)
	num.add_theme_font_size_override("font_size", 16)
	num.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	hdr.add_child(num)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var tog := Button.new()
	tog.text = "OFF"
	tog.custom_minimum_size = Vector2(70, 34)
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
	stock_opt.custom_minimum_size = Vector2(180, 36)
	stock_opt.item_selected.connect(_on_at_stock.bind(index))
	cfg.add_child(stock_opt)

	var cond_opt := OptionButton.new()
	for key in AutoTradeManager.CONDITION_TYPES:
		cond_opt.add_item(AutoTradeManager.CONDITION_TYPES[key])
	cond_opt.name = "CondOption"
	cond_opt.custom_minimum_size = Vector2(170, 36)
	cond_opt.item_selected.connect(_on_at_cond.bind(index))
	cfg.add_child(cond_opt)

	var cv := SpinBox.new()
	cv.min_value = 0
	cv.max_value = 999999999
	cv.step = 1000
	cv.value = 50000
	cv.name = "CondValue"
	cv.custom_minimum_size = Vector2(140, 36)
	cv.value_changed.connect(_on_at_val.bind(index))
	cfg.add_child(cv)

	var act_opt := OptionButton.new()
	act_opt.add_item("매수")
	act_opt.add_item("매도")
	act_opt.name = "ActionOption"
	act_opt.custom_minimum_size = Vector2(80, 36)
	act_opt.item_selected.connect(_on_at_action.bind(index))
	cfg.add_child(act_opt)

	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = 100000
	qty.value = 1
	qty.name = "QtyValue"
	qty.custom_minimum_size = Vector2(90, 36)
	qty.value_changed.connect(_on_at_qty.bind(index))
	cfg.add_child(qty)

	outer.add_child(cfg)
	return panel


# ═══════════════════════════════════════════════
#   라이프 뷰
# ═══════════════════════════════════════════════

func _build_asset_view() -> void:
	_asset_view = VBoxContainer.new()
	_asset_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_view.visible = false
	_content.add_child(_asset_view)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_view.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	# ── 자동수익 분석 카드 ──
	var bd_header := Label.new()
	bd_header.text = "  자동수익 분석"
	bd_header.add_theme_font_size_override("font_size", 20)
	bd_header.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(bd_header)

	_asset_breakdown_container = VBoxContainer.new()
	_asset_breakdown_container.add_theme_constant_override("separation", 2)
	inner.add_child(_asset_breakdown_container)

	# ── 주거 ──
	var hh := Label.new()
	hh.text = "  주거"
	hh.add_theme_font_size_override("font_size", 20)
	hh.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(hh)

	_asset_housing_container = VBoxContainer.new()
	_asset_housing_container.add_theme_constant_override("separation", 3)
	inner.add_child(_asset_housing_container)

	# ── 차량 ──
	var vh := Label.new()
	vh.text = "  차량"
	vh.add_theme_font_size_override("font_size", 20)
	vh.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(vh)

	_asset_vehicle_container = VBoxContainer.new()
	_asset_vehicle_container.add_theme_constant_override("separation", 3)
	inner.add_child(_asset_vehicle_container)

	# ── 사업 운영 ──
	var bh := Label.new()
	bh.text = "  사업 운영"
	bh.add_theme_font_size_override("font_size", 20)
	bh.add_theme_color_override("font_color", COL_ACCENT)
	inner.add_child(bh)

	_asset_business_container = VBoxContainer.new()
	_asset_business_container.add_theme_constant_override("separation", 4)
	inner.add_child(_asset_business_container)

	_refresh_asset_view()


func _refresh_asset_view() -> void:
	# 주거
	for c in _asset_housing_container.get_children():
		c.queue_free()
	var cur_house: String = GameManager.player["house"]
	for i in range(GameManager.get_housing_list().size()):
		var h: Dictionary = GameManager.get_housing_list()[i]
		var is_cur: bool = h["id"] == cur_house
		var locked: bool = i > 0 and GameManager.get_housing_list()[i - 1]["id"] != cur_house and not is_cur
		_asset_housing_container.add_child(_life_row(h, "house", is_cur, locked, i))

	# 차량
	for c in _asset_vehicle_container.get_children():
		c.queue_free()
	var cur_veh: String = GameManager.player["vehicle"]
	for i in range(GameManager.get_vehicle_list().size()):
		var v: Dictionary = GameManager.get_vehicle_list()[i]
		var is_cur: bool = v["id"] == cur_veh
		var locked: bool = i > 0 and GameManager.get_vehicle_list()[i - 1]["id"] != cur_veh and not is_cur
		_asset_vehicle_container.add_child(_life_row(v, "vehicle", is_cur, locked, i))

	# 사업
	_refresh_business_view()
	# 자동수익 분석
	_refresh_breakdown()


## 자동수익 분석 카드 갱신
func _refresh_breakdown() -> void:
	for c in _asset_breakdown_container.get_children():
		c.queue_free()

	var bd: Dictionary = PassiveIncomeManager.get_projected_breakdown()
	var biz_per_sec: float = BusinessManager.calc_tick_revenue() / PassiveIncomeManager._tick_interval

	var items := [
		["배당", bd.get("dividend", 0.0), COL_UP],
		["임대", bd.get("rental", 0.0), COL_ACCENT],
		["이자", bd.get("interest", 0.0), COL_TEXT_DIM],
		["사업", biz_per_sec, COL_GOLD],
	]
	var total: float = 0.0
	for item in items:
		total += item[1]

	for item in items:
		var row := HBoxContainer.new()
		_asset_breakdown_container.add_child(row)

		var nl := Label.new()
		nl.text = "  %s" % item[0]
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", COL_TEXT_DIM)
		nl.custom_minimum_size = Vector2(80, 0)
		row.add_child(nl)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)

		var vl := Label.new()
		vl.text = "+%s/초" % _fmt_won_short(item[1])
		vl.add_theme_font_size_override("font_size", 15)
		vl.add_theme_color_override("font_color", item[2])
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vl.custom_minimum_size = Vector2(120, 0)
		row.add_child(vl)

	# 총합
	var sep := HSeparator.new()
	_asset_breakdown_container.add_child(sep)

	var total_row := HBoxContainer.new()
	_asset_breakdown_container.add_child(total_row)

	var tl := Label.new()
	tl.text = "  총합"
	tl.add_theme_font_size_override("font_size", 17)
	tl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	tl.custom_minimum_size = Vector2(80, 0)
	total_row.add_child(tl)

	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(tsp)

	var tvl := Label.new()
	tvl.text = "+%s/초" % _fmt_won_short(total)
	tvl.add_theme_font_size_override("font_size", 17)
	tvl.add_theme_color_override("font_color", COL_GOLD)
	tvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tvl.custom_minimum_size = Vector2(120, 0)
	total_row.add_child(tvl)


## 사업 목록 갱신
func _refresh_business_view() -> void:
	for c in _asset_business_container.get_children():
		c.queue_free()

	var defs: Array = BusinessManager.get_all_defs()
	for def in defs:
		var card := _create_business_card(def)
		_asset_business_container.add_child(card)


## 사업 카드 생성
func _create_business_card(def: Dictionary) -> Control:
	var owned: Dictionary = BusinessManager.get_owned()
	var is_owned: bool = owned.has(def.get("id", ""))
	var entry: Dictionary = owned.get(def.get("id", ""), {})

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(COL_PANEL if not is_owned else Color(0.10, 0.15, 0.12, 1), 6))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	panel.add_child(vbox)

	# 이름 + 카테고리
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = def.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT if is_owned else COL_TEXT_DIM)
	top_row.add_child(name_lbl)

	var cat_lbl := Label.new()
	cat_lbl.text = _biz_cat_name(def.get("category", ""))
	cat_lbl.add_theme_font_size_override("font_size", 13)
	cat_lbl.add_theme_color_override("font_color", COL_ACCENT)
	top_row.add_child(cat_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp)

	# 보유 상태
	if is_owned:
		var lvl_lbl := Label.new()
		lvl_lbl.text = "Lv.%d" % int(entry.get("level", 1))
		lvl_lbl.add_theme_font_size_override("font_size", 15)
		lvl_lbl.add_theme_color_override("font_color", COL_GOLD)
		top_row.add_child(lvl_lbl)

	# 정보 라인
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	vbox.add_child(info_row)

	var daily_rev: float = 0.0
	if is_owned:
		daily_rev = BusinessManager._calc_business_daily_revenue(def.get("id", ""))
	var per_sec: float = daily_rev / 10.0 if daily_rev > 0 else 0.0

	_info_label(info_row, "수익/일", _fmt_won_short(daily_rev), COL_UP if daily_rev > 0 else COL_TEXT_DIM)
	_info_label(info_row, "수익/초", _fmt_won_short(per_sec), COL_GOLD if per_sec > 0 else COL_TEXT_DIM)
	if is_owned:
		_info_label(info_row, "직원", "%d/5" % int(entry.get("employees", 0)), COL_TEXT_DIM)
		var ev_mult: float = float(entry.get("event_multiplier", 1.0))
		if ev_mult != 1.0:
			var ev_text := "호황" if ev_mult > 1.0 else "불황"
			_info_label(info_row, "이벤트", ev_text, COL_UP if ev_mult > 1.0 else COL_DOWN)
	else:
		_info_label(info_row, "가격", _fmt_won_short(float(def.get("purchase_price", 0))), COL_GOLD)

	# 버튼 영역
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	if is_owned:
		# 업그레이드 버튼
		var up_cost: float = BusinessManager.get_upgrade_cost(def.get("id", ""))
		var up_btn := Button.new()
		up_btn.text = "업그레이드 (%s)" % _fmt_won_short(up_cost)
		up_btn.custom_minimum_size = Vector2(0, 36)
		up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		up_btn.add_theme_font_size_override("font_size", 14)
		var max_level: int = 10
		if int(entry.get("level", 1)) >= max_level:
			up_btn.text = "최대 레벨"
			up_btn.disabled = true
		elif not GameManager.can_afford(up_cost):
			up_btn.disabled = true
		up_btn.pressed.connect(_on_business_upgrade.bind(def.get("id", "")))
		btn_row.add_child(up_btn)

		# 직원 고용 버튼
		var emp_btn := Button.new()
		var emp_count: int = int(entry.get("employees", 0))
		emp_btn.text = "직원 고용 (%d/5)" % emp_count
		emp_btn.custom_minimum_size = Vector2(0, 36)
		emp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		emp_btn.add_theme_font_size_override("font_size", 14)
		if emp_count >= 5:
			emp_btn.disabled = true
		emp_btn.pressed.connect(_on_business_hire.bind(def.get("id", "")))
		btn_row.add_child(emp_btn)
	else:
		# 구매 버튼
		var price: float = float(def.get("purchase_price", 0))
		var buy_btn := Button.new()
		buy_btn.text = "구매 (%s)" % _fmt_won_short(price)
		buy_btn.custom_minimum_size = Vector2(0, 36)
		buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_btn.add_theme_font_size_override("font_size", 14)
		buy_btn.add_theme_color_override("font_color", COL_UP)
		# 카테고리 제한 확인
		var cat_count: int = BusinessManager._count_category(def.get("category", ""))
		if cat_count >= 2:
			buy_btn.text = "카테고리 한도 (2/2)"
			buy_btn.disabled = true
		elif not GameManager.can_afford(price):
			buy_btn.disabled = true
		buy_btn.pressed.connect(_on_business_purchase.bind(def.get("id", "")))
		btn_row.add_child(buy_btn)

	return panel


func _info_label(parent: HBoxContainer, key: String, val: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = "%s: %s" % [key, val]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)


func _biz_cat_name(cat: String) -> String:
	match cat:
		"food": return "요식업"
		"it": return "IT"
		"retail": return "소매/서비스"
		"realestate": return "부동산"
		_: return cat


## 사업 이벤트 핸들러
func _on_business_purchase(bid: String) -> void:
	var r := BusinessManager.purchase(bid)
	if r.get("success"):
		AudioManager.play_buy()
		_show_toast("사업 구매: %s" % r.get("business", {}).get("name", ""))
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))
	_refresh_asset_view()


func _on_business_upgrade(bid: String) -> void:
	var r := BusinessManager.upgrade(bid)
	if r.get("success"):
		AudioManager.play_buy()
		_show_toast("업그레이드: Lv.%d" % r.get("new_level", 1))
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))
	_refresh_asset_view()


func _on_business_hire(bid: String) -> void:
	var r := BusinessManager.hire_employee(bid)
	if r.get("success"):
		_show_toast("직원 고용: %d/5" % r.get("employees", 0))
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))
	_refresh_asset_view()


## 시간 컨트롤 핸들러
func _on_pause_toggle() -> void:
	GameClockManager.toggle_pause()
	if GameClockManager.is_paused:
		_pause_btn.text = ">"
	else:
		_pause_btn.text = "||"
	_update_speed_button_styles()


func _on_speed_change(mult: float) -> void:
	GameClockManager.set_speed(mult)
	if GameClockManager.is_paused:
		GameClockManager.is_paused = false
		_pause_btn.text = "||"
	_update_speed_button_styles()


func _update_speed_button_styles() -> void:
	var cur_speed := GameClockManager.speed_multiplier
	var cur_paused := GameClockManager.is_paused
	_speed1_btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT if cur_speed == 1.0 and not cur_paused else COL_PANEL, 4))
	_speed2_btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT if cur_speed == 2.0 and not cur_paused else COL_PANEL, 4))
	_speed4_btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT if cur_speed == 4.0 and not cur_paused else COL_PANEL, 4))
	_speed1_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 1.0 and not cur_paused else COL_TEXT_DIM)
	_speed2_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 2.0 and not cur_paused else COL_TEXT_DIM)
	_speed4_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 4.0 and not cur_paused else COL_TEXT_DIM)


func _life_row(item: Dictionary, type: String, is_cur: bool, locked: bool, _idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
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
	bonus.add_theme_font_size_override("font_size", 14)
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
	price.add_theme_font_size_override("font_size", 16)
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
	_asset_view.visible = (view_name == "자산")
	_npc_view.visible = (view_name == "NPC")
	_progress_view.visible = (view_name == "진행")
	_cat_tabs.visible = (view_name == "시장")
	for child in _view_tabs.get_children():
		if child is Button and child.has_meta("view"):
			_update_view_tab_style(child, child.get_meta("view") == view_name)
	# 뷰 진입 시 새로고침
	match view_name:
		"시장":
			# 첫 종목 자동 선택
			if _selected_stock == "" and _stock_rows.size() > 0:
				_selected_stock = _stock_rows.keys()[0]
			_update_row_selection()
			_update_detail_panel()
		"자산": _refresh_asset_view()
		"NPC": _refresh_npc_view()
		"진행": _refresh_progress_view()


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
	_update_row_selection()
	_update_detail_panel()


func _close_trade_panel() -> void:
	# 상세 패널은 항상 보이므로 선택만 해제
	_selected_stock = ""
	_update_row_selection()
	_update_detail_panel()


func _update_detail_panel() -> void:
	if _selected_stock == "":
		_detail_name.text = "종목을 선택하세요"
		_detail_ticker.text = ""
		_detail_meta.text = ""
		_detail_price.text = ""
		_detail_change.text = ""
		_detail_holding.text = ""
		_detail_avg_price.text = ""
		_detail_eval_amount.text = ""
		_detail_eval_pnl.text = ""
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	_detail_name.text = s["name"]
	_detail_ticker.text = s.get("ticker", "")
	_detail_meta.text = "%s / %s" % [_cat_tag_kr(s.get("category", "")), s.get("sector", "")]
	_detail_price.text = _fmt_price(s["price"])
	var pct: float = s.get("change_pct", 0.0)
	_detail_change.text = _fmt_change(pct)
	_detail_change.add_theme_color_override("font_color", _chg_color(pct))
	_detail_price.add_theme_color_override("font_color", _chg_color(pct) if abs(pct) > 0.1 else COL_TEXT_BRIGHT)
	var q: int = GameManager.get_holding_quantity(_selected_stock)
	if q > 0:
		var avg: float = float(GameManager.get_holding(_selected_stock).get("avg_price", 0))
		var eval_amount: float = float(s["price"]) * q
		var pnl: float = eval_amount - avg * q
		_detail_holding.text = "보유: %d주" % q
		_detail_avg_price.text = "평단가: %s" % _fmt_price(avg)
		_detail_eval_amount.text = "평가금액: %s" % _fmt_price(eval_amount)
		_detail_eval_pnl.text = "평가손익: %s%s" % ["+" if pnl >= 0 else "", _fmt_won(pnl)]
		_detail_eval_pnl.add_theme_color_override("font_color", COL_UP if pnl >= 0 else COL_DOWN)
	else:
		_detail_holding.text = "보유 없음"
		_detail_avg_price.text = ""
		_detail_eval_amount.text = ""
		_detail_eval_pnl.text = ""
	if _detail_sparkline and s.get("history", []).size() >= 2:
		_detail_sparkline.set_data(s["history"], pct >= 0)
	_on_qty_changed(_trade_qty_edit.value)

func _cat_tag_kr(cat: String) -> String:
	match cat:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return cat

func _update_row_selection() -> void:
	for sid in _stock_rows:
		var row: Control = _stock_rows[sid]
		if sid == _selected_stock:
			row.add_theme_stylebox_override("normal", _flat(COL_PANEL_LIGHT, 4))
		else:
			row.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))


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
		_show_toast("매수 완료: %d주 (%s)" % [qty, _fmt_won(r["cost"])])
		_update_detail_panel()
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
		UIAnim.pulse(_detail_panel)
		var pt := ""
		if r.has("profit"):
			var p: float = r["profit"]
			pt = " (수익 +%s)" % _fmt_won(p) if p >= 0 else " (손실 %s)" % _fmt_won(abs(p))
		_show_toast("매도 완료: %d주%s" % [qty, pt])
		_update_detail_panel()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))


func _on_clock_day_advanced(day: int, r: Dictionary) -> void:
	AudioManager.play_day_advance()
	var msg := "%d일차 시작" % day
	_refresh_asset_view()
	if r.get("salary", 0.0) > 0:
		msg += " | 월급 +%s" % _fmt_won(r["salary"])
	if r.get("rank_up", "") != "":
		msg += " | 승진! -> %s" % r["rank_up"]
		_rank_label.text = "  " + GameManager.get_rank_name()
		AudioManager.play_rank_up()
		UIAnim.pop_in(_rank_label)
	if r.has("bailout"):
		msg += " | 파산방지 +%s" % _fmt_won(r["bailout"])
	_day_label.text = "%d일차 %s" % [day, GameClockManager.get_time_string()]
	_show_toast(msg)

	# 이벤트 발생 (r에 이미 events가 포함됨)
	var events: Array = r.get("events", [])
	for event in events:
		var etitle: String = event.get("title", "")
		var extra := ""
		if event.has("reward"):
			extra = " (%+.0f원)" % float(event["reward"])
		elif event.has("loss") and float(event["loss"]) > 0:
			extra = " (-%.0f원 손실)" % float(event["loss"])
		_show_toast("[이벤트] %s%s" % [etitle, extra])
	_refresh_progress_view()


## 시간 변화 핸들러
func _on_time_changed(hour: int, minute: int, phase: int) -> void:
	if _day_label:
		var day: int = GameManager.player.get("day", 1)
		_day_label.text = "%d일차 %02d:%02d" % [day, hour, minute]
	if _day_progress:
		_day_progress.value = GameClockManager.get_phase_progress()
	# 장중에만 주가 UI 갱신
	if phase == GameClockManager.Phase.MARKET:
		for sid in _stock_rows:
			_update_stock_row(sid)


## 페이즈 변화 핸들러
func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	if new_phase == GameClockManager.Phase.PRE_MARKET:
		_show_toast("장전 - 브리핑 확인", COL_ACCENT)
	elif new_phase == GameClockManager.Phase.MARKET:
		_show_toast("장 개시", COL_UP)
	elif new_phase == GameClockManager.Phase.AFTER_HOURS:
		_show_toast("장 마감 - 외부 활동 가능", COL_GOLD)
	_show_next_day_button_if_after_hours()


## 장전 시작 — 신문 팝업
func _on_pre_market_started() -> void:
	if not GameClockManager.pre_market_news_shown:
		_show_newspaper_popup()
		GameClockManager.pre_market_news_shown = true


## 장 개시
func _on_market_opened() -> void:
	_show_toast("개장 - 주식 거래 가능", COL_UP)


## 장 마감
func _on_market_closed() -> void:
	# 장마감 시 보유 종목 UI 갱신
	for sid in _stock_rows:
		_update_stock_row(sid)


## 장중 1시간 경과 — 주가 갱신
func _on_hourly_price_update(hour: int) -> void:
	MarketSim.on_hourly_update()
	for sid in _stock_rows:
		_update_stock_row(sid)
	if _selected_stock != "":
		_update_detail_panel()


## 장마감 "다음날로" 버튼 표시
func _show_next_day_button_if_after_hours() -> void:
	# 기존 버튼이 있으면 제거
	var existing := get_node_or_null("NextDayButton")
	if existing:
		existing.queue_free()
	# 장마감이 아니면 표시 안 함
	if GameClockManager.current_phase != GameClockManager.Phase.AFTER_HOURS:
		return
	# "다음날로" 버튼 추가
	var btn := Button.new()
	btn.name = "NextDayButton"
	btn.text = "다음날로"
	btn.custom_minimum_size = Vector2(120, 46)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", COL_GOLD)
	btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	btn.offset_top = 60
	btn.z_index = 50
	btn.pressed.connect(_on_next_day)
	add_child(btn)


func _on_next_day() -> void:
	var btn := get_node_or_null("NextDayButton")
	if btn:
		btn.queue_free()
	GameClockManager.advance_to_next_day()


## 신문 팝업 — 장전 브리핑
func _show_newspaper_popup() -> void:
	GameClockManager.pause_for_event()

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	add_child(overlay)

	var popup := PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(620, 520)
	popup.add_theme_stylebox_override("panel", _flat(Color(0.094, 0.092, 0.085, 1), 4))
	popup.z_index = 71
	add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.offset_left = 24
	vbox.offset_top = 20
	vbox.offset_right = -24
	vbox.offset_bottom = -20
	popup.add_child(vbox)

	# 신문 헤더
	var header := Label.new()
	var day: int = GameManager.player.get("day", 1)
	header.text = "=== %d일차 데일리 증권 브리핑 ===" % day
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", COL_GOLD)
	vbox.add_child(header)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# 오늘의 시장 전망
	var stocks: Array = MarketSim.get_all_stocks()
	# 상승/하락 종목 집계
	var up_count: int = 0
	var down_count: int = 0
	for s in stocks:
		if float(s.get("change_pct", 0.0)) > 0:
			up_count += 1
		elif float(s.get("change_pct", 0.0)) < 0:
			down_count += 1

	var outlook_lbl := Label.new()
	outlook_lbl.text = "전일 시장 요약: 상승 %d종목 | 하락 %d종목 | 보합 %d종목" % [up_count, down_count, stocks.size() - up_count - down_count]
	outlook_lbl.add_theme_font_size_override("font_size", 14)
	outlook_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(outlook_lbl)

	# 주요 뉴스
	var news_header := Label.new()
	news_header.text = "[ 주요 뉴스 ]"
	news_header.add_theme_font_size_override("font_size", 16)
	news_header.add_theme_color_override("font_color", COL_ACCENT)
	vbox.add_child(news_header)

	# 활성 이벤트를 뉴스로 표시
	var events := EventManager.get_active_events()
	if events.is_empty():
		var no_news := Label.new()
		no_news.text = "  오늘은 특별한 뉴스가 없습니다."
		no_news.add_theme_font_size_override("font_size", 14)
		no_news.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(no_news)
	else:
		for event in events:
			var news_row := HBoxContainer.new()
			news_row.add_theme_constant_override("separation", 8)
			vbox.add_child(news_row)

			var type_text := "[뉴스]"
			var type_color: Color = COL_ACCENT
			match event.get("type", ""):
				"crypto_risk":
					type_text = "[리스크]"
					type_color = COL_DOWN
				"life":
					type_text = "[생활]"
					type_color = COL_UP

			var tag := Label.new()
			tag.text = type_text
			tag.add_theme_font_size_override("font_size", 13)
			tag.add_theme_color_override("font_color", type_color)
			tag.custom_minimum_size = Vector2(70, 0)
			news_row.add_child(tag)

			var title := Label.new()
			title.text = event.get("title", "")
			title.add_theme_font_size_override("font_size", 14)
			title.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			news_row.add_child(title)

	# 마켓 사이클 정보
	var cycle_lbl := Label.new()
	var mc: float = MarketSim.market_cycle
	var cycle_text := "시장 분위기: 중립"
	var cycle_color: Color = COL_TEXT_DIM
	if mc > 0.3:
		cycle_text = "시장 분위기: 강세 우위"
		cycle_color = COL_UP
	elif mc < -0.3:
		cycle_text = "시장 분위기: 약세 우위"
		cycle_color = COL_DOWN
	cycle_lbl.text = cycle_text
	cycle_lbl.add_theme_font_size_override("font_size", 14)
	cycle_lbl.add_theme_color_override("font_color", cycle_color)
	vbox.add_child(cycle_lbl)

	vbox.add_child(_spacer(20))

	# 확인 버튼
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "확인"
	ok_btn.custom_minimum_size = Vector2(120, 42)
	ok_btn.add_theme_font_size_override("font_size", 17)
	ok_btn.add_theme_color_override("font_color", COL_ACCENT)
	ok_btn.pressed.connect(
		func():
			# 장전 뉴스 효과 미리 반영
			MarketSim.apply_pre_market_effects()
			overlay.queue_free()
			popup.queue_free()
			GameClockManager.resume_from_event()
	)
	btn_row.add_child(ok_btn)


## 퀘스트 완료 알림
func _on_quest_completed(quest_id: String, reward: Dictionary) -> void:
	AudioManager.play_quest_complete()
	var msg := "[퀘스트 완료] %s" % reward.get("name", quest_id)
	if reward.get("cash", 0.0) > 0:
		msg += " +%s" % _fmt_won(reward["cash"])
	_show_toast(msg, COL_GOLD)
	if _current_view == "진행":
		_refresh_quest_section()


## 업적 달성 알림
func _on_achievement_unlocked(ach_id: String, name: String) -> void:
	AudioManager.play_achievement_unlock()
	_show_toast("[업적 달성] %s" % name, COL_GOLD)
	if _current_view == "진행":
		_refresh_achievement_section()


## 스토리 챕터 시작 알림
func _on_story_chapter_started(chapter_id: String) -> void:
	AudioManager.play_story_unlock()
	_show_toast("[스토리] 새 챕터 시작", COL_ACCENT)
	if _current_view == "진행":
		_refresh_story_section()


## 스토리 이벤트 (컷신)
func _on_story_event(text: String) -> void:
	var scene_info: Dictionary = StoryManager.get_current_scene_info()
	_show_cutscene_popup(scene_info)


## 컷신 팝업 표시
func _show_cutscene_popup(scene_info: Dictionary) -> void:
	if _cutscene_popup and is_instance_valid(_cutscene_popup):
		_cutscene_popup.queue_free()

	# 오버레이
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.80)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	add_child(overlay)

	# 팝업 패널
	_cutscene_popup = PanelContainer.new()
	_cutscene_popup.set_anchors_preset(Control.PRESET_CENTER)
	_cutscene_popup.custom_minimum_size = Vector2(560, 280)
	_cutscene_popup.add_theme_stylebox_override("panel", _flat(COL_PANEL_LIGHT, 8))
	_cutscene_popup.z_index = 61
	add_child(_cutscene_popup)

	# 메인 HBox: 초상화 | 대사
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.offset_left = 20
	main_hbox.offset_top = 20
	main_hbox.offset_right = -20
	main_hbox.offset_bottom = -20
	_cutscene_popup.add_child(main_hbox)

	# 초상화 영역
	var portrait_type: String = scene_info.get("portrait", "narration")
	var portrait_tex := _get_portrait_texture(portrait_type)
	if portrait_tex:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait_tex
		portrait_rect.custom_minimum_size = Vector2(96, 96)
		portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main_hbox.add_child(portrait_rect)

	# 대사 영역
	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content_vbox)

	# 챕터 제목
	var chapter_title: String = scene_info.get("chapter_title", "")
	if chapter_title != "":
		var ch_lbl := Label.new()
		ch_lbl.text = "[ " + chapter_title + " ]"
		ch_lbl.add_theme_font_size_override("font_size", 13)
		ch_lbl.add_theme_color_override("font_color", COL_ACCENT)
		content_vbox.add_child(ch_lbl)

	# 화자명
	var speaker: String = scene_info.get("speaker", "")
	if speaker != "":
		var speaker_lbl := Label.new()
		speaker_lbl.text = speaker
		speaker_lbl.add_theme_font_size_override("font_size", 18)
		speaker_lbl.add_theme_color_override("font_color", COL_GOLD)
		content_vbox.add_child(speaker_lbl)

	# 대사 텍스트
	var text_content: String = scene_info.get("text", scene_info.get("formatted", ""))
	if text_content == "":
		text_content = str(scene_info)
	var text_lbl := Label.new()
	text_lbl.text = text_content
	text_lbl.add_theme_font_size_override("font_size", 16)
	text_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(text_lbl)

	# 진행도 표시
	var scene_idx: int = int(scene_info.get("scene_idx", 0))
	var total_scenes: int = int(scene_info.get("total_scenes", 1))
	var prog_lbl := Label.new()
	prog_lbl.text = "%d / %d" % [scene_idx + 1, total_scenes]
	prog_lbl.add_theme_font_size_override("font_size", 12)
	prog_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_vbox.add_child(prog_lbl)

	# 버튼 행
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(btn_row)

	# 다음 버튼
	var next_btn := Button.new()
	next_btn.text = "다음"
	next_btn.custom_minimum_size = Vector2(90, 38)
	next_btn.add_theme_font_size_override("font_size", 15)
	next_btn.add_theme_color_override("font_color", COL_ACCENT)
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	next_btn.pressed.connect(
		func():
			StoryManager.advance_scene()
			overlay.queue_free()
			_cutscene_popup.queue_free()
			_cutscene_popup = null
			# 다음 컷신이 있으면 표시
			if StoryManager.is_playing():
				var next_info: Dictionary = StoryManager.get_current_scene_info()
				if not next_info.is_empty():
					_show_cutscene_popup(next_info)
	)
	btn_row.add_child(next_btn)

	# 스킵 버튼
	var skip_btn := Button.new()
	skip_btn.text = "스킵"
	skip_btn.custom_minimum_size = Vector2(90, 38)
	skip_btn.add_theme_font_size_override("font_size", 15)
	skip_btn.add_theme_color_override("font_color", COL_TEXT_DIM)
	skip_btn.pressed.connect(
		func():
			StoryManager.skip_chapter()
			overlay.queue_free()
			_cutscene_popup.queue_free()
			_cutscene_popup = null
	)
	btn_row.add_child(skip_btn)


## 초상화 텍스처 생성
func _get_portrait_texture(portrait_type: String) -> Texture2D:
	var icon_gen := IconGenerator.new()
	match portrait_type:
		"player":
			return icon_gen.make_character_portrait(GameManager.player.get("generation", 1), 96)
		"boss":
			return icon_gen.make_npc_avatar("#D9B34D", 96)
		"rival1", "rival3":
			return icon_gen.make_npc_avatar("#CC4545", 96)
		"helper1":
			return icon_gen.make_npc_avatar("#3390D4", 96)
		"spouse":
			return icon_gen.make_npc_avatar("#E8E8E8", 96)
		"child":
			return icon_gen.make_npc_avatar("#28A66A", 96)
		"news":
			return icon_gen.make_npc_avatar("#8A8D96", 96)
		"narration", _:
			return null


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
	_day_label.text = "%d일차 %s" % [d, GameClockManager.get_time_string()]


func _on_time_changed(hour: int, minute: int, phase: int) -> void:
	if _day_label:
		var day: int = GameManager.player.get("day", 1)
		_day_label.text = "%d일차 %02d:%02d" % [day, hour, minute]
	if _day_progress:
		_day_progress.value = GameClockManager.get_phase_progress()


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
		_refresh_asset_view()
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

	# 자동 수익/초 표시
	if _passive_label:
		var pps := PassiveIncomeManager.get_projected_per_second()
		if pps > 0:
			_passive_label.text = "+" + _fmt_won_short(pps) + "/초"
			_passive_label.add_theme_color_override("font_color", COL_GOLD)
		else:
			_passive_label.text = "0원/초"
			_passive_label.add_theme_color_override("font_color", COL_TEXT_DIM)

	if _selected_stock != "":
		_update_detail_panel()

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
	_gen_button.custom_minimum_size = Vector2(0, 52)
	_gen_button.add_theme_font_size_override("font_size", 18)
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
	name.add_theme_font_size_override("font_size", 18)
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

func _build_progress_view() -> void:
	_progress_view = VBoxContainer.new()
	_progress_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_progress_view.visible = false
	_content.add_child(_progress_view)

	# 서브탭 버튼
	_progress_subtabs = HBoxContainer.new()
	_progress_subtabs.add_theme_constant_override("separation", 4)
	_progress_view.add_child(_progress_subtabs)

	for tab_name in ["뉴스", "퀘스트", "업적", "스토리"]:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(90, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("subtab", tab_name)
		btn.pressed.connect(_on_progress_subtab.bind(tab_name))
		_progress_subtabs.add_child(btn)
	_update_subtab_styles()

	# 스크롤 콘텐츠 영역
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_progress_view.add_child(scroll)

	_progress_content = VBoxContainer.new()
	_progress_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_progress_content)

	# 각 섹션 컨테이너
	_event_container = VBoxContainer.new()
	_event_container.add_theme_constant_override("separation", 4)
	_progress_content.add_child(_event_container)

	_quest_container = VBoxContainer.new()
	_quest_container.add_theme_constant_override("separation", 4)
	_progress_content.add_child(_quest_container)

	_achievement_container = VBoxContainer.new()
	_achievement_container.add_theme_constant_override("separation", 4)
	_progress_content.add_child(_achievement_container)

	_story_container = VBoxContainer.new()
	_story_container.add_theme_constant_override("separation", 4)
	_progress_content.add_child(_story_container)

	# 초반 목표 카드 (항상 상단)
	_tutorial_container = VBoxContainer.new()
	_tutorial_container.add_theme_constant_override("separation", 4)
	_progress_content.add_child(_tutorial_container)
	# tutorial은 맨 앞으로 이동
	_progress_content.move_child(_tutorial_container, 0)

	_show_progress_subtab("뉴스")


func _on_progress_subtab(tab_name: String) -> void:
	_show_progress_subtab(tab_name)


func _show_progress_subtab(tab_name: String) -> void:
	_progress_subtab = tab_name
	_event_container.visible = (tab_name == "뉴스")
	_quest_container.visible = (tab_name == "퀘스트")
	_achievement_container.visible = (tab_name == "업적")
	_story_container.visible = (tab_name == "스토리")
	# 초반 목표는 뉴스와 퀘스트 탭에서만 표시
	_tutorial_container.visible = (tab_name == "뉴스" or tab_name == "퀘스트")
	_update_subtab_styles()
	_refresh_progress_view()


func _update_subtab_styles() -> void:
	for child in _progress_subtabs.get_children():
		if child is Button and child.has_meta("subtab"):
			var active: bool = child.get_meta("subtab") == _progress_subtab
			if active:
				child.add_theme_stylebox_override("normal", _flat(COL_ACCENT, 4))
				child.add_theme_color_override("font_color", Color.WHITE)
			else:
				child.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
				child.add_theme_color_override("font_color", COL_TEXT_DIM)


func _refresh_progress_view() -> void:
	_refresh_news_section()
	_refresh_quest_section()
	_refresh_achievement_section()
	_refresh_story_section()
	_refresh_tutorial_card()


## 뉴스 섹션 (기존 _refresh_event_view와 동일)
func _refresh_news_section() -> void:
	for c in _event_container.get_children():
		c.queue_free()

	var events := EventManager.get_active_events()
	if events.is_empty():
		var empty := Label.new()
		empty.text = "  진행 중인 뉴스가 없습니다"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", COL_TEXT_DIM)
		_event_container.add_child(empty)
		return

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
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", type_color)
		hbox.add_child(tag)

		var day := Label.new()
		day.text = "%d일차" % event.get("day", 0)
		day.add_theme_font_size_override("font_size", 12)
		day.add_theme_color_override("font_color", COL_TEXT_DIM)
		hbox.add_child(day)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(sp)

		if event.has("reward"):
			var reward: float = event["reward"]
			var r_label := Label.new()
			if reward >= 0:
				r_label.text = "+%.0f원" % reward
				r_label.add_theme_color_override("font_color", COL_UP)
			else:
				r_label.text = "%.0f원" % reward
				r_label.add_theme_color_override("font_color", COL_DOWN)
			r_label.add_theme_font_size_override("font_size", 14)
			hbox.add_child(r_label)
		elif event.has("loss") and float(event["loss"]) > 0:
			var l_label := Label.new()
			l_label.text = "-%.0f원 손실" % float(event["loss"])
			l_label.add_theme_font_size_override("font_size", 14)
			l_label.add_theme_color_override("font_color", COL_DOWN)
			hbox.add_child(l_label)

		vbox.add_child(hbox)

		var title := Label.new()
		title.text = "  " + event.get("title", "")
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
		vbox.add_child(title)

		var desc := Label.new()
		desc.text = "  " + event.get("desc", "")
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(desc)

		_event_container.add_child(panel)


## 퀘스트 섹션
func _refresh_quest_section() -> void:
	for c in _quest_container.get_children():
		c.queue_free()

	_build_quest_header("일일 퀘스트", QuestManager.get_daily_quests())
	_build_quest_header("주간 퀘스트", QuestManager.get_weekly_quests())
	_build_quest_header("월간 퀘스트", QuestManager.get_monthly_quests())


func _build_quest_header(title: String, quests: Array) -> void:
	var header := Label.new()
	header.text = "  " + title
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", COL_ACCENT)
	_quest_container.add_child(header)

	if quests.is_empty():
		var empty := Label.new()
		empty.text = "    없음"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", COL_TEXT_DIM)
		_quest_container.add_child(empty)
		return

	for q in quests:
		var panel := PanelContainer.new()
		var claimed: bool = q.get("claimed", false)
		var complete: bool = q.get("progress", 0) >= q.get("target", 1)
		if claimed:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.10, 0.15, 0.10, 1), 4))
		elif complete:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.14, 0.10, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 4))
		_quest_container.add_child(panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = "  " + q.get("name", "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		if claimed:
			name_lbl.add_theme_color_override("font_color", COL_UP)
		elif complete:
			name_lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "    " + q.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		info.add_child(desc_lbl)

		# 진행도 바
		var prog_row := HBoxContainer.new()
		progRow_quest(prog_row, q)
		info.add_child(prog_row)


func progRow_quest(row: HBoxContainer, q: Dictionary) -> void:
	row.add_theme_constant_override("separation", 6)
	var prog: int = int(q.get("progress", 0))
	var target: int = int(q.get("target", 1))

	var prog_lbl := Label.new()
	prog_lbl.text = "    %d / %d" % [prog, target]
	prog_lbl.add_theme_font_size_override("font_size", 14)
	prog_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	row.add_child(prog_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = float(max(target, 1))
	bar.value = float(prog)
	bar.custom_minimum_size = Vector2(100, 10)
	bar.show_percentage = false
	row.add_child(bar)

	var status_lbl := Label.new()
	if q.get("claimed", false):
		status_lbl.text = "완료됨"
		status_lbl.add_theme_color_override("font_color", COL_UP)
	elif prog >= target:
		status_lbl.text = "보상 지급 완료"
		status_lbl.add_theme_color_override("font_color", COL_GOLD)
	else:
		status_lbl.text = "진행 중"
		status_lbl.add_theme_color_override("font_color", COL_ACCENT)
	status_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(status_lbl)


## 업적 섹션
func _refresh_achievement_section() -> void:
	for c in _achievement_container.get_children():
		c.queue_free()

	var unlocked: int = QuestManager.get_unlocked_achievement_count()
	var total: int = QuestManager.get_total_achievement_count()

	# 달성률 헤더
	var rate_header := Label.new()
	rate_header.text = "  업적 달성률: %d / %d" % [unlocked, total]
	rate_header.add_theme_font_size_override("font_size", 18)
	rate_header.add_theme_color_override("font_color", COL_GOLD)
	_achievement_container.add_child(rate_header)

	# 진행률 바
	var rate_bar := ProgressBar.new()
	rate_bar.min_value = 0
	rate_bar.max_value = float(max(total, 1))
	rate_bar.value = float(unlocked)
	rate_bar.custom_minimum_size = Vector2(0, 14)
	rate_bar.show_percentage = false
	_achievement_container.add_child(rate_bar)

	# 카테고리 필터 버튼
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	_achievement_container.add_child(filter_row)

	var cat_filters := ["전체", "거래", "자산", "라이프", "수익", "사업", "특수"]
	for cat_label in cat_filters:
		var btn := Button.new()
		btn.text = cat_label
		btn.custom_minimum_size = Vector2(60, 28)
		btn.add_theme_font_size_override("font_size", 13)
		var active: bool = (_ach_cat_name_reverse(cat_label) == _achievement_cat_filter) or (cat_label == "전체" and _achievement_cat_filter == "")
		if active:
			btn.add_theme_stylebox_override("normal", _flat(COL_ACCENT, 4))
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.add_theme_stylebox_override("normal", _flat(COL_PANEL, 4))
			btn.add_theme_color_override("font_color", COL_TEXT_DIM)
		btn.pressed.connect(_on_achievement_cat_filter.bind(_ach_cat_name_reverse(cat_label) if cat_label != "전체" else ""))
		filter_row.add_child(btn)

	var achs: Array = QuestManager.get_achievements()
	for ach in achs:
		# 필터링
		if _achievement_cat_filter != "" and ach.get("category", "") != _achievement_cat_filter:
			continue

		var panel := PanelContainer.new()
		var is_unlocked: bool = ach.get("unlocked", false)
		if is_unlocked:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.10, 0.05, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 4))
		_achievement_container.add_child(panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = "  " + ach.get("name", "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		if is_unlocked:
			name_lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			name_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = "    " + ach.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		info.add_child(desc_lbl)

		# 카테고리 + 상태
		var cat_lbl := Label.new()
		var cat_name := _ach_cat_name(ach.get("category", ""))
		cat_lbl.text = "    [%s]" % cat_name
		cat_lbl.add_theme_font_size_override("font_size", 12)
		cat_lbl.add_theme_color_override("font_color", COL_ACCENT if is_unlocked else COL_TEXT_DIM)
		info.add_child(cat_lbl)

		var status_lbl := Label.new()
		if is_unlocked:
			status_lbl.text = "달성"
			status_lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			status_lbl.text = "미달성"
			status_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		status_lbl.add_theme_font_size_override("font_size", 14)
		status_lbl.custom_minimum_size = Vector2(50, 0)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(status_lbl)


func _ach_cat_name(cat: String) -> String:
	match cat:
		"trading": return "거래"
		"wealth": return "자산"
		"life": return "라이프"
		"income": return "수익"
		"business": return "사업"
		"special": return "특수"
		_: return cat


func _ach_cat_name_reverse(kr: String) -> String:
	match kr:
		"거래": return "trading"
		"자산": return "wealth"
		"라이프": return "life"
		"수익": return "income"
		"사업": return "business"
		"특수": return "special"
		_: return ""


func _on_achievement_cat_filter(cat: String) -> void:
	_achievement_cat_filter = cat
	_refresh_achievement_section()


## 스토리 섹션
func _refresh_story_section() -> void:
	for c in _story_container.get_children():
		c.queue_free()

	var completed: Array = StoryManager.get_completed_chapters()
	var total_ch: int = StoryManager.get_chapter_count()

	# 진행률 헤더
	var header := Label.new()
	header.text = "  스토리 진행: %d / %d 챕터" % [completed.size(), total_ch]
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", COL_ACCENT)
	_story_container.add_child(header)

	# 챕터 목록 — data/story.json에서 읽기
	var story_data = load_json("res://data/story.json")
	if story_data == null or not story_data.has("chapters"):
		return
	var chapters: Array = story_data["chapters"]

	for i in range(chapters.size()):
		var ch: Dictionary = chapters[i]
		var ch_id: String = ch.get("id", "")
		var is_done: bool = completed.has(ch_id)

		var panel := PanelContainer.new()
		if is_done:
			panel.add_theme_stylebox_override("panel", _flat(Color(0.10, 0.15, 0.10, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", _flat(COL_PANEL, 4))
		_story_container.add_child(panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		var num_lbl := Label.new()
		num_lbl.text = "  Ch.%d" % (i + 1)
		num_lbl.add_theme_font_size_override("font_size", 15)
		num_lbl.add_theme_color_override("font_color", COL_GOLD if is_done else COL_TEXT_DIM)
		num_lbl.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(num_lbl)

		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = ch.get("title", "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT if is_done else COL_TEXT_DIM)
		info.add_child(name_lbl)

		# 트리거 조건 표시
		var trigger: Dictionary = ch.get("trigger", {})
		var trig_text := _trigger_desc(trigger)
		var trig_lbl := Label.new()
		trig_lbl.text = "    조건: " + trig_text
		trig_lbl.add_theme_font_size_override("font_size", 13)
		trig_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		info.add_child(trig_lbl)

		var status_lbl := Label.new()
		if is_done:
			status_lbl.text = "완료"
			status_lbl.add_theme_color_override("font_color", COL_UP)
		else:
			status_lbl.text = "미달성"
			status_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		status_lbl.add_theme_font_size_override("font_size", 14)
		status_lbl.custom_minimum_size = Vector2(50, 0)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(status_lbl)


func _trigger_desc(trigger: Dictionary) -> String:
	var type: String = trigger.get("type", "")
	match type:
		"start": return "게임 시작"
		"net_worth": return "순자산 %s" % _fmt_won(float(trigger.get("value", 0)))
		"rank_index": return "직급 달성"
		"married_days": return "결혼 후 %d일" % int(trigger.get("value", 0))
		_: return type


## 초반 목표 카드
func _refresh_tutorial_card() -> void:
	for c in _tutorial_container.get_children():
		c.queue_free()

	var header := Label.new()
	header.text = "  초반 목표"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", COL_ACCENT)
	_tutorial_container.add_child(header)

	var goals := [
		["첫 주식 매수", GameManager.player.get("trade_count", 0) > 0],
		["첫 매도 (수익 실현)", GameManager.player.get("winning_trades", 0) > 0],
		["자동매매 슬롯 설정", AutoTradeManager.get_active_count() > 0],
		["첫 사업 구매", BusinessManager.get_owned().size() > 0],
		["순자산 5천만원 달성", GameManager.get_net_worth() >= 50000000],
	]

	for goal in goals:
		var done: bool = goal[1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_tutorial_container.add_child(row)

		var check := Label.new()
		check.text = "[v]" if done else "[ ]"
		check.add_theme_font_size_override("font_size", 15)
		check.add_theme_color_override("font_color", COL_UP if done else COL_TEXT_DIM)
		check.custom_minimum_size = Vector2(30, 0)
		row.add_child(check)

		var lbl := Label.new()
		lbl.text = goal[0]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", COL_UP if done else COL_TEXT_BRIGHT)
		row.add_child(lbl)


func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _refresh_event_view() -> void:
	_refresh_progress_view()


# ═══════════════════════════════════════════════
#   NPC 이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_rival_challenge(npc_id: String) -> void:
	GameClockManager.pause_for_event()
	var result := NPCManager.challenge_rival(npc_id)
	if result.get("success"):
		if result.get("won"):
			_show_toast("승리! 보상 +%s" % _fmt_won(result["reward"]))
		else:
			_show_toast("패배... -%s" % _fmt_won(result["penalty"]))
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))
	GameClockManager.resume_from_event()


func _on_helper_service(npc_id: String) -> void:
	GameClockManager.pause_for_event()
	var result := NPCManager.use_helper_service(npc_id)
	if result.get("success"):
		_show_toast(result.get("desc", "서비스 완료"))
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))
	GameClockManager.resume_from_event()


func _on_give_gift(npc_id: String, amount: float) -> void:
	GameClockManager.pause_for_event()
	var result := NPCManager.give_gift(npc_id, amount)
	if result.get("success"):
		_show_toast("호감도 +%d → %d" % [result["gain"], result["affinity"]])
		_refresh_npc_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))
	GameClockManager.resume_from_event()


func _on_marry(npc_id: String) -> void:
	GameClockManager.pause_for_event()
	var result := NPCManager.marry(npc_id)
	if result.get("success"):
		var npc: Dictionary = result["npc"]
		AudioManager.play_marriage()
		_show_toast("결혼! %s와(과) 결혼했습니다" % npc.get("name", ""))
		_refresh_npc_view()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + result.get("reason", ""))
	GameClockManager.resume_from_event()


func _on_generation_advance() -> void:
	var result := NPCManager.start_new_generation()
	if result.get("success"):
		_show_toast("세대교체! %d대 — 상속 %s" % [result["new_generation"], _fmt_won(result["inherited_cash"])])
		_refresh_npc_view()
		_refresh_all()
		_refresh_asset_view()
	else:
		_show_toast("실패: " + result.get("reason", ""))


# ═══════════════════════════════════════════════
#   헬퍼
# ═══════════════════════════════════════════════

func _refresh_all() -> void:
	_on_cash_changed(GameManager.get_cash())
	_on_net_worth_changed(GameManager.get_net_worth())


var _toast_queue: Array = []
var _toast_showing: bool = false

func _show_toast(msg: String, color: Color = COL_TEXT_BRIGHT) -> void:
	_toast_queue.append({"msg": msg, "color": color})
	if not _toast_showing:
		_process_toast_queue()


func _process_toast_queue() -> void:
	if _toast_queue.is_empty():
		_toast_showing = false
		return
	_toast_showing = true
	var item: Dictionary = _toast_queue.pop_front()
	_toast.text = item["msg"]
	_toast.add_theme_color_override("font_color", item["color"])
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.position.y = 80
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_property(_toast, "position:y", 60, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(1.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		_toast.visible = false
		_process_toast_queue()
	)


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
	# 주가 표시: 단위별 가변 (원/만원/억)
	var ap := absf(p)
	if ap >= 100_000_000:
		return "%.2f억" % (p / 100_000_000)
	elif ap >= 10_000_000:
		return "%.1f천만" % (p / 10_000_000)
	elif ap >= 1_000_000:
		return "%d만" % int(p / 10_000)
	elif ap >= 10_000:
		return "%.1f만" % (p / 10_000)
	elif ap >= 1_000:
		return "%d" % int(p)
	return "%.0f" % p


func _fmt_won(a: float) -> String:
	# 통화 표시: 단위별 가변 (원/만원/천만원/억)
	var ab := absf(a)
	var sign := "-" if a < 0 else ""
	if ab >= 1_000_000_000_000:
		return "%s%.2f조원" % [sign, ab / 1_000_000_000_000]
	elif ab >= 100_000_000:
		return "%s%.2f억원" % [sign, ab / 100_000_000]
	elif ab >= 10_000_000:
		return "%s%.1f천만원" % [sign, ab / 10_000_000]
	elif ab >= 1_000_000:
		return "%s%d만원" % [sign, int(ab / 10_000)]
	elif ab >= 10_000:
		return "%s%.1f만원" % [sign, ab / 10_000]
	return "%s%.0f원" % [sign, ab]


func _fmt_won_short(a: float) -> String:
	# 축약 표시 (초당 수익 등): 조/억/만/천/원
	var ab := absf(a)
	var sign := "-" if a < 0 else ""
	if ab >= 1_000_000_000_000:
		return "%s%.1f조" % [sign, ab / 1_000_000_000_000]
	elif ab >= 100_000_000:
		return "%s%.1f억" % [sign, ab / 100_000_000]
	elif ab >= 10_000_000:
		return "%s%.0f천만" % [sign, ab / 10_000_000]
	elif ab >= 1_000_000:
		return "%s%d만" % [sign, int(ab / 10_000)]
	elif ab >= 10_000:
		return "%s%.1f만" % [sign, ab / 10_000]
	elif ab >= 1_000:
		return "%s%d천" % [sign, int(ab / 1_000)]
	return "%s%d" % [sign, int(ab)]


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

extends Control
## MainGame — 메인 게임 화면
## 씬 에디터 기반: 정적 UI는 main.tscn에 정의, 동적 데이터만 코드에서 생성

const UIAnim := preload("res://scripts/UIAnim.gd")
const IconGenerator := preload("res://scripts/IconGenerator.gd")

# 색상 — 다크 도트 타이쿤 (밝은 톤)
const COL_UP := Color(0.40, 0.73, 0.42, 1)       # #66BB6A
const COL_DOWN := Color(1.0, 0.44, 0.26, 1)       # #FF7043
const COL_ACCENT := Color(0.15, 0.78, 0.85, 1)    # #26C6DA
const COL_GOLD := Color(1.0, 0.84, 0.31, 1)       # #FFD54F
const COL_TEXT_DIM := Color(0.55, 0.55, 0.62, 1)  # #8C8C9E
const COL_TEXT_BRIGHT := Color(0.88, 0.88, 0.92, 1) # #E0E0EB
const COL_PANEL := Color(0.165, 0.165, 0.239, 1)  # #2A2A3D
const COL_PANEL_LIGHT := Color(0.212, 0.212, 0.290, 1) # #36364A

# 디버그 로그 플래그 (기본 OFF, 필요시 true로 전환)
const DEBUG_PRICE_SYNC := false
const DEBUG_BRIEFING := false
const COL_BG := Color(0.118, 0.118, 0.180, 1)     # #1E1E2E
const COL_BORDER := Color(0.239, 0.239, 0.333, 1) # #3D3D55
# 미니게임 공통 색상
const COL_NPC := Color(0.91, 0.11, 0.55, 1)       # #E81C8C — 핑크 (NPC/미니게임 타이틀)
const COL_USER := Color(0.13, 0.78, 0.85, 1)      # #21C7D9 — 시안 (플레이어)
const COL_WIN := Color(0.16, 0.65, 0.42, 1)        # #28A66A — 승리
const COL_LOSE := Color(0.80, 0.27, 0.27, 1)       # #CC4545 — 패배
const COL_TIE := Color(0.85, 0.70, 0.30, 1)        # #D9B34D — 무승부
const COL_CARD_BG := Color(0.15, 0.15, 0.27, 1)    # 블랙잭 카드 배경
const COL_CARD_BORDER := Color(0.25, 0.25, 0.33, 1) # 블랙잭 카드 테두리
const COL_CARD_HIT_BORDER := Color(1.0, 0.28, 0.34, 1) # 블랙잭 히트 카드 테두리
const OVERLAY_ALPHA := 0.75                         # 모든 팝업 오버레이 알파

# 글로벌 폰트 (둥근모꼴)
var _pixel_font: FontFile = null

const CATEGORY_FILTERS := ["전체", "한국", "미국", "코인"]
const CATEGORY_MAP := {"한국": "korea", "미국": "usa", "코인": "coin"}
const VIEW_TABS := ["시장", "포트폴리오", "자산", "NPC", "진행"]

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
@onready var _bgm_btn: TextureButton  # set in _init_static_ui
var _bgm_on: bool = true

# 동적 생성되는 뷰
var _market_view: HBoxContainer
var _portfolio_view: VBoxContainer
var _asset_view: VBoxContainer
var _current_view: String = "시장"

# 시장 뷰 내부
var _stock_scroll: ScrollContainer
var _stock_list: VBoxContainer
var _detail_panel: PanelContainer  # 오른쪽 상세 패널 (기존 _trade_panel 대체)
var _stock_rows: Dictionary = {}
var _stock_sparklines: Dictionary = {}  # stock_id -> Sparkline Control
var _stock_price_labels: Dictionary = {}  # stock_id -> PriceLabel
var _stock_change_labels: Dictionary = {}  # stock_id -> ChangeLabel
var _current_category: String = "korea"
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
var _detail_logo: TextureRect
var _detail_dwmy_labels: Dictionary = {}  # "D","W","M","Y" -> Label
var _trade_qty_edit: SpinBox
var _trade_total_label: Label

# 자동매매
var _autotrade_slots: Array = []

# 라이프
var _asset_subtab: String = "주거"
var _asset_subtabs: HBoxContainer
var _asset_housing_container: VBoxContainer
var _asset_vehicle_container: VBoxContainer
var _asset_detail_panel: PanelContainer
var _asset_detail_icon: TextureRect
var _asset_detail_name: Label
var _asset_detail_desc: Label
var _asset_detail_effects: Label
var _asset_detail_price: Label
var _asset_detail_buy_btn: Button
var _selected_life_type: String = ""
var _selected_life_id: String = ""

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
var _biz_cat_tabs: HBoxContainer  # 사업 카테고리 하위 탭

# 세대교체 버튼
var _gen_button: Button


# ═══════════════════════════════════════════════
func _ready() -> void:
	_load_pixel_font()
	_apply_theme()
	_init_static_ui()
	AudioManager.play_bgm()
	_build_market_view()
	_build_portfolio_view()
	_build_asset_view()
	_build_npc_view()
	_build_progress_view()
	_show_view("시장")
	_refresh_all()
	_connect_signals()
	_check_offline_reward()


func _check_offline_reward() -> void:
	var now: float = float(Time.get_unix_time_from_system())
	var last: float = float(GameManager.player.get("last_save_time", now))
	var elapsed_hours: float = (now - last) / 3600.0
	if elapsed_hours < 0.02:  # 1분 미만이면 스킵
		return
	
	# 오프라인 시뮬레이션
	var offline_seconds: float = now - last
	
	# 자동매매 시뮬레이션
	var auto_trade_manager = get_node_or_null("/root/Main/AutoTradeManager")
	if auto_trade_manager and auto_trade_manager.has_method("simulate_offline"):
		auto_trade_manager.simulate_offline(offline_seconds)
	
	# 사업 일일수익 (간단히 days 기준)
	var days_passed: int = int(offline_seconds / (86400.0 / 30.0))  # game_accel=30
	var biz_revenue: float = 0.0
	for d in range(days_passed):
		var rev_result: Dictionary = BusinessManager.pay_daily_revenue()
		biz_revenue += float(rev_result.get("total", 0.0))
	
	_show_offline_summary_popup(elapsed_hours, biz_revenue)


func _show_offline_summary_popup(hours: float, revenue: float) -> void:
	GameClockManager.pause_for_event()
	# 오버레이
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	add_child(overlay)
	# 팝업 — 화면 중앙 배치
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(400, 260)
	popup.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL_LIGHT, 8))
	popup.z_index = 71
	popup.set_anchor(SIDE_LEFT, 0.5)
	popup.set_anchor(SIDE_RIGHT, 0.5)
	popup.set_anchor(SIDE_TOP, 0.5)
	popup.set_anchor(SIDE_BOTTOM, 0.5)
	popup.set_offset(SIDE_LEFT, -200)
	popup.set_offset(SIDE_RIGHT, 200)
	popup.set_offset(SIDE_TOP, -130)
	popup.set_offset(SIDE_BOTTOM, 130)
	add_child(popup)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.offset_left = 24
	vbox.offset_top = 24
	vbox.offset_right = -24
	vbox.offset_bottom = -24
	popup.add_child(vbox)
	
	var title := Label.new()
	title.text = "돌아오신 것을 환영합니다!"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var info := Label.new()
	info.text = "부재 시간: 약 %.1f시간\n사업 수익: +%s" % [hours, UIUtil._fmt_won(revenue)]
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", COL_UP)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)
	
	var ok_btn := Button.new()
	ok_btn.text = "확인"
	ok_btn.custom_minimum_size = Vector2(120, 42)
	ok_btn.add_theme_font_size_override("font_size", 18)
	ok_btn.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	ok_btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 6))
	ok_btn.pressed.connect(func():
		overlay.queue_free()
		popup.queue_free()
		GameClockManager.resume_from_event()
	)
	vbox.add_child(ok_btn)


## 둥근모꼴 폰트 로드
func _load_pixel_font() -> void:
	var font_path := "res://assets/fonts/neodgm.ttf"
	if FileAccess.file_exists(font_path):
		var loaded: Variant = load(font_path)
		if loaded is FontFile:
			_pixel_font = loaded
		else:
			_pixel_font = null


## 글로벌 테마 적용 — 폰트 + 배경색
func _apply_theme() -> void:
	if _pixel_font:
		# Theme 생성하여 글로벌 폰트 설정
		var theme := Theme.new()
		theme.set_font("font", "Label", _pixel_font)
		theme.set_font("font", "Button", _pixel_font)
		theme.set_font("font", "LineEdit", _pixel_font)
		theme.set_font("font", "SpinBox", _pixel_font)
		theme.set_font("font", "ProgressBar", _pixel_font)
		theme.set_font("font", "AcceptDialog", _pixel_font)
		theme.set_font("font", "OptionButton", _pixel_font)
		# 둥근모꼴은 크기가 작게 보이므로 약간 키움
		theme.default_font_size = 15
		self.theme = theme
	# 배경색
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COL_BG
	self.add_theme_stylebox_override("panel", bg_style)
	# 자식 컨테이너에도 배경 전파
	modulate = Color(1, 1, 1, 1)


func _connect_signals() -> void:
	GameManager.cash_changed.connect(_on_cash_changed)
	GameManager.net_worth_changed.connect(_on_net_worth_changed)
	GameManager.day_advanced.connect(_on_day_advanced)
	GameManager.rank_up.connect(_on_rank_up)
	GameManager.salary_paid.connect(_on_salary_paid)
	MarketSim.market_tick.connect(_on_market_tick)
	AutoTradeManager.auto_trade_executed.connect(_on_auto_trade_executed)
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

	# 첫날 브리핑 — 시그널 연결 후 시그널 발생 (씬 전환 전에 emit된 시그널은 수신 불가)
	# 다음 틱에 실행하여 UI가 완전히 구성된 후 팝업
	call_deferred("_trigger_first_briefing")


func _trigger_first_briefing() -> void:
	GameClockManager.trigger_first_briefing()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _show_view("시장")
			KEY_2: _show_view("포트폴리오")
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

	# BGM 토글 버튼 (TopBar — 직업 라벨 옆)
	_bgm_btn = TextureButton.new()
	var bgm_tex_on: ImageTexture = AudioManager.get_icon_on()
	if bgm_tex_on:
		_bgm_btn.texture_normal = bgm_tex_on
	_bgm_btn.custom_minimum_size = Vector2(32, 32)
	_bgm_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bgm_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_bgm_btn.pressed.connect(_on_bgm_toggle)
	# TopBar HBoxContainer에 추가 → 직업 라벨 옆에 자동 배치
	var top_bar := _content.get_parent().get_node("TopBar") as HBoxContainer
	if top_bar:
		# 직업 라벨과 날짜 라벨 사이에 삽입 (RankLabel 다음)
		var rank_idx: int = _rank_label.get_index()
		top_bar.add_child(_bgm_btn)
		top_bar.move_child(_bgm_btn, rank_idx + 1)
	else:
		add_child(_bgm_btn)

func _on_bgm_toggle() -> void:
	_bgm_on = AudioManager.toggle_bgm()
	var tex: ImageTexture = AudioManager.get_icon_on() if _bgm_on else AudioManager.get_icon_off()
	if tex:
		_bgm_btn.texture_normal = tex

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
	_stock_scroll.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 0))
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
	_detail_panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL_LIGHT, 0))
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_detail_panel)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 12)
	_detail_panel.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.name = "DetailScroll"
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── 1. 상단 헤더: 로고 + 종목명/티커 ──
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	vbox.add_child(top_row)

	_detail_logo = TextureRect.new()
	_detail_logo.custom_minimum_size = Vector2(56, 56)
	_detail_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_detail_logo)

	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 2)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(name_box)

	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name_box.add_child(_detail_name)

	_detail_ticker = Label.new()
	_detail_ticker.add_theme_font_size_override("font_size", 14)
	_detail_ticker.add_theme_color_override("font_color", COL_TEXT_DIM)
	name_box.add_child(_detail_ticker)

	_detail_meta = Label.new()
	_detail_meta.add_theme_font_size_override("font_size", 13)
	_detail_meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	name_box.add_child(_detail_meta)

	# ── 2. 대형 차트 영역 (확대) ──
	var spark_script := load("res://scripts/Sparkline.gd")
	_detail_sparkline = Control.new()
	_detail_sparkline.set_script(spark_script)
	_detail_sparkline.custom_minimum_size = Vector2(0, 140)
	_detail_sparkline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_detail_sparkline)

	# ── 3. 가격 정보 영역 (차트 아래, 별도 카드) ──
	var info_panel := PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel", UIUtil._flat(Color(0.094, 0.110, 0.133, 1), 0))
	vbox.add_child(info_panel)

	var info_grid := GridContainer.new()
	info_grid.columns = 3
	info_grid.add_theme_constant_override("h_separation", 16)
	info_grid.add_theme_constant_override("v_separation", 6)
	info_panel.add_child(info_grid)

	_detail_price = Label.new()
	_detail_price.add_theme_font_size_override("font_size", 20)
	_detail_price.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	info_grid.add_child(_detail_price)

	_detail_change = Label.new()
	_detail_change.add_theme_font_size_override("font_size", 18)
	info_grid.add_child(_detail_change)

	var spacer_cell := Label.new()
	spacer_cell.text = ""
	info_grid.add_child(spacer_cell)

	_detail_holding = Label.new()
	_detail_holding.add_theme_font_size_override("font_size", 14)
	_detail_holding.add_theme_color_override("font_color", COL_TEXT_DIM)
	info_grid.add_child(_detail_holding)

	_detail_avg_price = Label.new()
	_detail_avg_price.add_theme_font_size_override("font_size", 14)
	_detail_avg_price.add_theme_color_override("font_color", COL_TEXT_DIM)
	info_grid.add_child(_detail_avg_price)

	_detail_eval_amount = Label.new()
	_detail_eval_amount.add_theme_font_size_override("font_size", 14)
	_detail_eval_amount.add_theme_color_override("font_color", COL_TEXT_DIM)
	info_grid.add_child(_detail_eval_amount)

	_detail_eval_pnl = Label.new()
	_detail_eval_pnl.add_theme_font_size_override("font_size", 15)
	info_grid.add_child(_detail_eval_pnl)

	# ── D/W/M/Y 수익률 행 ──
	var dwmy_row := HBoxContainer.new()
	dwmy_row.add_theme_constant_override("separation", 12)
	vbox.add_child(dwmy_row)

	for key in ["D", "W", "M", "Y"]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		lbl.custom_minimum_size = Vector2(70, 0)
		dwmy_row.add_child(lbl)
		_detail_dwmy_labels[key] = lbl

	# ── 4. 매수/매도 입력 영역 ──
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

	# % 비율 버튼 (매수: 자산 %, 매도: 보유 %)
	var pct_row := HBoxContainer.new()
	pct_row.add_theme_constant_override("separation", 4)
	vbox.add_child(pct_row)

	var buy_lbl := Label.new()
	buy_lbl.text = "자산%"
	buy_lbl.add_theme_font_size_override("font_size", 11)
	buy_lbl.add_theme_color_override("font_color", COL_UP)
	buy_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buy_lbl.custom_minimum_size = Vector2(48, 0)
	pct_row.add_child(buy_lbl)

	for pct in [10, 25, 50, 100]:
		var btn := Button.new()
		btn.text = "%d%%" % pct
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", COL_UP)
		btn.pressed.connect(_on_buy_pct.bind(pct))
		pct_row.add_child(btn)

	var pct_row2 := HBoxContainer.new()
	pct_row2.add_theme_constant_override("separation", 4)
	vbox.add_child(pct_row2)

	var sell_lbl := Label.new()
	sell_lbl.text = "보유%"
	sell_lbl.add_theme_font_size_override("font_size", 11)
	sell_lbl.add_theme_color_override("font_color", COL_DOWN)
	sell_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sell_lbl.custom_minimum_size = Vector2(48, 0)
	pct_row2.add_child(sell_lbl)

	for pct in [10, 25, 50, 100]:
		var btn := Button.new()
		btn.text = "%d%%" % pct
		btn.custom_minimum_size = Vector2(0, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", COL_DOWN)
		btn.pressed.connect(_on_sell_pct.bind(pct))
		pct_row2.add_child(btn)

	# ── 5. 매수/매도 버튼 ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	var buy := Button.new()
	buy.text = "매수"
	buy.name = "BuyButton"
	buy.custom_minimum_size = Vector2(0, 44)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_font_size_override("font_size", 18)
	buy.add_theme_color_override("font_color", COL_UP)
	buy.pressed.connect(_on_buy)
	btn_row.add_child(buy)

	var sell := Button.new()
	sell.text = "매도"
	sell.name = "SellButton"
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
	_stock_sparklines.clear()
	_stock_price_labels.clear()
	_stock_change_labels.clear()
	for stock in MarketSim.get_all_stocks():
		var row := _create_stock_row(stock)
		_stock_list.add_child(row)
		_stock_rows[stock["id"]] = row
		# 시작 직후 스파크라인 초기 데이터 설정
		_update_stock_row(stock["id"])


func _create_stock_row(stock: Dictionary) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", UIUtil._flat(Color(0.094, 0.110, 0.133, 1), 0))
	btn.add_theme_stylebox_override("hover", UIUtil._flat(Color(0.141, 0.157, 0.220, 1), 0))
	btn.add_theme_stylebox_override("pressed", UIUtil._flat(Color(0.141, 0.157, 0.220, 1), 0))
	btn.pressed.connect(_on_stock_clicked.bind(stock["id"]))
	btn.name = "Row_" + stock["id"]

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	btn.add_child(hbox)

	# ── 컬럼 1: 로고 (고정 56px) ──
	var logo_tex := _get_stock_icon(stock["id"])
	if logo_tex:
		var logo_rect := TextureRect.new()
		logo_rect.texture = logo_tex
		logo_rect.custom_minimum_size = Vector2(48, 48)
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(logo_rect)
	else:
		var spacer1 := Control.new()
		spacer1.custom_minimum_size = Vector2(56, 0)
		hbox.add_child(spacer1)

	# ── 컬럼 2: 종목명 + 티커/섹터 (고정 220px) ──
	var nb := VBoxContainer.new()
	nb.add_theme_constant_override("separation", 1)
	nb.custom_minimum_size = Vector2(200, 0)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Label.new()
	name.text = stock["name"]
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nb.add_child(name)
	var meta := Label.new()
	meta.text = "%s · %s" % [stock.get("ticker", ""), stock.get("sector", "")]
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", COL_TEXT_DIM)
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nb.add_child(meta)
	hbox.add_child(nb)

	# ── 컬럼 3: 국가 배지 (고정 50px) ──
	var cat := Label.new()
	cat.text = UIUtil._cat_tag(stock["category"])
	cat.add_theme_font_size_override("font_size", 13)
	cat.add_theme_color_override("font_color", UIUtil._cat_color(stock["category"]))
	cat.custom_minimum_size = Vector2(50, 0)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cat)

	# ── 컬럼 4: 스파크라인 (고정 160px x 48px) ──
	var spark_script := load("res://scripts/Sparkline.gd")
	var spark := Control.new()
	spark.set_script(spark_script)
	spark.custom_minimum_size = Vector2(160, 48)
	spark.name = "Sparkline"
	spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(spark)
	# Sparkline 참조 저장 (find_child 없이 직접 접근)
	_stock_sparklines[stock["id"]] = spark

	# ── 컬럼 5: 보유 수량 (고정 60px, 오른쪽 정렬) ──
	var hl := Label.new()
	hl.name = "HoldLabel"
	hl.add_theme_font_size_override("font_size", 13)
	hl.add_theme_color_override("font_color", COL_TEXT_DIM)
	hl.custom_minimum_size = Vector2(60, 0)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(hl)

	# ── 컬럼 6: 현재가 (고정 110px, 오른쪽 정렬 + 여백) ──
	var pl := Label.new()
	pl.name = "PriceLabel"
	pl.text = UIUtil._fmt_price(stock["price"])
	pl.add_theme_font_size_override("font_size", 16)
	pl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	pl.custom_minimum_size = Vector2(110, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(pl)
	# PriceLabel 참조 저장 (find_child 없이 직접 접근)
	_stock_price_labels[stock["id"]] = pl

	# ── 컬럼 7: 등락률 (고정 95px, 오른쪽 정렬 + 여백) ──
	var cl := Label.new()
	cl.name = "ChangeLabel"
	cl.text = UIUtil._fmt_change(stock.get("change_pct", 0.0))
	cl.add_theme_font_size_override("font_size", 15)
	cl.add_theme_color_override("font_color", UIUtil._chg_color(stock.get("change_pct", 0.0)))
	cl.custom_minimum_size = Vector2(95, 0)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(cl)
	# ChangeLabel 참조 저장
	_stock_change_labels[stock["id"]] = cl

	# 오른쪽 여백 확보 (스크롤바와 겹침 방지)
	var rpad := Control.new()
	rpad.custom_minimum_size = Vector2(14, 0)
	hbox.add_child(rpad)

	return btn


# ═══════════════════════════════════════════════
#   포트폴리오 뷰
# ═══════════════════════════════════════════════

func _build_portfolio_view() -> void:
	_portfolio_view = VBoxContainer.new()
	_portfolio_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portfolio_view.visible = false
	_content.add_child(_portfolio_view)

	# ScrollContainer로 감싸기
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portfolio_view.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	# 요약 분석 컨테이너 (구 자산 탭 요약에서 이동)
	_asset_breakdown_container = VBoxContainer.new()
	_asset_breakdown_container.add_theme_constant_override("separation", 4)
	inner.add_child(_asset_breakdown_container)


func _create_at_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 6))
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

	# 문장형 미리보기 라벨
	var preview := Label.new()
	preview.name = "PreviewLabel"
	preview.text = "종목 미선택"
	preview.add_theme_font_size_override("font_size", 13)
	preview.add_theme_color_override("font_color", COL_TEXT_DIM)
	outer.add_child(preview)

	return panel


# ═══════════════════════════════════════════════
#   라이프 뷰
# ═══════════════════════════════════════════════

func _build_asset_view() -> void:
	_asset_view = VBoxContainer.new()
	_asset_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_view.visible = false
	_content.add_child(_asset_view)

	# 서브탭 버튼
	_asset_subtabs = HBoxContainer.new()
	_asset_subtabs.add_theme_constant_override("separation", 4)
	_asset_view.add_child(_asset_subtabs)

	for tab_name in ["주거", "차량", "사업"]:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(90, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.set_meta("subtab", tab_name)
		btn.pressed.connect(_on_asset_subtab.bind(tab_name))
		_asset_subtabs.add_child(btn)
	_update_asset_subtab_styles()

	# 사업 카테고리 하위 탭
	_biz_cat_tabs = HBoxContainer.new()
	_biz_cat_tabs.add_theme_constant_override("separation", 4)
	_biz_cat_tabs.visible = false  # 사업 서브탭일 때만 표시
	_asset_view.add_child(_biz_cat_tabs)

	for cat_name in ["전체", "요식업", "IT", "소매/서비스", "부동산"]:
		var btn := Button.new()
		btn.text = cat_name
		btn.custom_minimum_size = Vector2(70, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.set_meta("biz_cat", cat_name)
		btn.pressed.connect(_on_biz_cat_tab.bind(cat_name))
		_biz_cat_tabs.add_child(btn)

	# 스크롤 콘텐츠
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_view.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	scroll.add_child(inner)

	# 각 섹션 컨테이너 (서브탭으로 show/hide)
	_asset_housing_container = VBoxContainer.new()
	_asset_housing_container.add_theme_constant_override("separation", 4)
	inner.add_child(_asset_housing_container)

	_asset_vehicle_container = VBoxContainer.new()
	_asset_vehicle_container.add_theme_constant_override("separation", 4)
	inner.add_child(_asset_vehicle_container)

	_asset_business_container = VBoxContainer.new()
	_asset_business_container.add_theme_constant_override("separation", 4)
	inner.add_child(_asset_business_container)

	_show_asset_subtab("주거")


func _on_asset_subtab(tab_name: String) -> void:
	_show_asset_subtab(tab_name)

func _on_biz_cat_tab(cat_name: String) -> void:
	_business_cat_filter = cat_name
	_update_biz_cat_tab_styles()
	_refresh_business_view()

func _show_asset_subtab(tab_name: String) -> void:
	_asset_subtab = tab_name
	_asset_housing_container.visible = (tab_name == "주거")
	_asset_vehicle_container.visible = (tab_name == "차량")
	_asset_business_container.visible = (tab_name == "사업")
	_biz_cat_tabs.visible = (tab_name == "사업")
	_update_asset_subtab_styles()
	_refresh_asset_view()


func _update_asset_subtab_styles() -> void:
	for child in _asset_subtabs.get_children():
		if child is Button and child.has_meta("subtab"):
			var active: bool = child.get_meta("subtab") == _asset_subtab
			if active:
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
				child.add_theme_color_override("font_color", Color.WHITE)
			else:
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
				child.add_theme_color_override("font_color", COL_TEXT_DIM)

func _update_biz_cat_tab_styles() -> void:
	for child in _biz_cat_tabs.get_children():
		if child is Button and child.has_meta("biz_cat"):
			var active: bool = child.get_meta("biz_cat") == _business_cat_filter
			if active:
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
				child.add_theme_color_override("font_color", Color.WHITE)
			else:
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
				child.add_theme_color_override("font_color", COL_TEXT_DIM)

func _refresh_asset_view() -> void:
	# 주거
	for c in _asset_housing_container.get_children():
		c.queue_free()
	if _asset_subtab == "주거":
		var hh := Label.new()
		hh.text = "  주거"
		hh.add_theme_font_size_override("font_size", 20)
		hh.add_theme_color_override("font_color", COL_ACCENT)
		_asset_housing_container.add_child(hh)
	var cur_house: String = GameManager.player["house"]
	for i in range(GameManager.get_housing_list().size()):
		var h: Dictionary = GameManager.get_housing_list()[i]
		var is_cur: bool = h["id"] == cur_house
		var locked: bool = i > 0 and GameManager.get_housing_list()[i - 1]["id"] != cur_house and not is_cur
		_asset_housing_container.add_child(_life_row(h, "house", is_cur, locked, i))

	# 차량
	for c in _asset_vehicle_container.get_children():
		c.queue_free()
	if _asset_subtab == "차량":
		var vh := Label.new()
		vh.text = "  차량"
		vh.add_theme_font_size_override("font_size", 20)
		vh.add_theme_color_override("font_color", COL_ACCENT)
		_asset_vehicle_container.add_child(vh)
	var cur_veh: String = GameManager.player["vehicle"]
	for i in range(GameManager.get_vehicle_list().size()):
		var v: Dictionary = GameManager.get_vehicle_list()[i]
		var is_cur: bool = v["id"] == cur_veh
		var locked: bool = i > 0 and GameManager.get_vehicle_list()[i - 1]["id"] != cur_veh and not is_cur
		_asset_vehicle_container.add_child(_life_row(v, "vehicle", is_cur, locked, i))

	# 사업
	if _asset_subtab == "사업":
		_refresh_business_view()


## 포트폴리오 카드 갱신
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
		vl.text = "+%s/초" % UIUtil._fmt_won_short(item[1])
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
	tvl.text = "+%s/초" % UIUtil._fmt_won_short(total)
	tvl.add_theme_font_size_override("font_size", 17)
	tvl.add_theme_color_override("font_color", COL_GOLD)
	tvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tvl.custom_minimum_size = Vector2(120, 0)
	total_row.add_child(tvl)

	# ── 보유 자산 요약 카드 ──
	var asset_sep2 := HSeparator.new()
	_asset_breakdown_container.add_child(asset_sep2)

	var ah := Label.new()
	ah.text = "  보유 자산"
	ah.add_theme_font_size_override("font_size", 18)
	ah.add_theme_color_override("font_color", COL_ACCENT)
	_asset_breakdown_container.add_child(ah)

	# 현재 주거
	var cur_house: Dictionary = GameManager.get_current_house()
	if not cur_house.is_empty() and cur_house.get("id", "") != "gosiwon":
		_add_asset_summary_card(cur_house, "house", UIUtil._fmt_won(cur_house.get("price", 0)))

	# 현재 차량
	var cur_veh: Dictionary = GameManager.get_current_vehicle()
	if not cur_veh.is_empty() and cur_veh.get("id", "") != "bicycle":
		_add_asset_summary_card(cur_veh, "vehicle", UIUtil._fmt_won(cur_veh.get("price", 0)))

	# 보유 사업
	var owned_biz: Dictionary = BusinessManager.get_owned()
	for bid in owned_biz:
		var bdef: Dictionary = BusinessManager.get_def(bid)
		if not bdef.is_empty():
			_add_asset_summary_card(bdef, "business", "Lv.%d" % int(owned_biz[bid].get("level", 1)))

	# 보유 주식 요약
	var holdings: Dictionary = GameManager.player.get("holdings", {})
	if holdings.size() > 0:
		var sh := Label.new()
		sh.text = "    보유 주식"
		sh.add_theme_font_size_override("font_size", 15)
		sh.add_theme_color_override("font_color", COL_TEXT_DIM)
		_asset_breakdown_container.add_child(sh)
		for sid in holdings:
			var stock: Dictionary = MarketSim.get_stock(sid)
			if stock.is_empty():
				continue
			var qty: int = int(holdings[sid].get("quantity", 0))
			if qty <= 0:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_asset_breakdown_container.add_child(row)
			# 아이콘
			var tex := _get_stock_icon(sid)
			if tex:
				var icon := TextureRect.new()
				icon.texture = tex
				icon.custom_minimum_size = Vector2(28, 28)
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(icon)
			# 이름
			var nl := Label.new()
			nl.text = "  %s (%s)" % [stock.get("name", sid), stock.get("ticker", "")]
			nl.add_theme_font_size_override("font_size", 14)
			nl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			# 수량
			var ql := Label.new()
			ql.text = "%d주" % qty
			ql.add_theme_font_size_override("font_size", 14)
			ql.add_theme_color_override("font_color", COL_ACCENT)
			ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ql.custom_minimum_size = Vector2(100, 0)
			row.add_child(ql)
			# 평가손익 / 수익률
			var avg: float = float(holdings[sid].get("avg_price", 0))
			var eval_amount: float = float(stock["price"]) * qty
			var pnl: float = eval_amount - avg * qty
			var pnl_pct: float = (pnl / (avg * qty) * 100.0) if avg > 0 and qty > 0 else 0.0
			var pl := Label.new()
			pl.text = "%s%s" % ["+" if pnl >= 0 else "", UIUtil._fmt_won_short(pnl)]
			pl.add_theme_font_size_override("font_size", 14)
			pl.add_theme_color_override("font_color", COL_UP if pnl >= 0 else COL_DOWN)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pl.custom_minimum_size = Vector2(90, 0)
			row.add_child(pl)
			var ppl := Label.new()
			ppl.text = "(%s%.1f%%)" % ["+" if pnl_pct >= 0 else "", pnl_pct]
			ppl.add_theme_font_size_override("font_size", 13)
			ppl.add_theme_color_override("font_color", COL_UP if pnl_pct >= 0 else COL_DOWN)
			ppl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ppl.custom_minimum_size = Vector2(80, 0)
			row.add_child(ppl)

		# 보유 주식 총합
		var tot_cost: float = 0.0
		var tot_eval: float = 0.0
		for sid2 in holdings:
			var st2: Dictionary = MarketSim.get_stock(sid2)
			if st2.is_empty():
				continue
			var qty2: int = int(holdings[sid2].get("quantity", 0))
			if qty2 <= 0:
				continue
			tot_cost += float(holdings[sid2].get("avg_price", 0)) * qty2
			tot_eval += float(st2["price"]) * qty2
		var tot_pnl: float = tot_eval - tot_cost
		var tot_pct: float = (tot_pnl / tot_cost * 100.0) if tot_cost > 0 else 0.0
		var tot_sep := HSeparator.new()
		_asset_breakdown_container.add_child(tot_sep)
		var tot_row := HBoxContainer.new()
		tot_row.add_theme_constant_override("separation", 8)
		_asset_breakdown_container.add_child(tot_row)
		var tot_nl := Label.new()
		tot_nl.text = "    주식 총합"
		tot_nl.add_theme_font_size_override("font_size", 15)
		tot_nl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
		tot_nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tot_row.add_child(tot_nl)
		var tot_pl := Label.new()
		tot_pl.text = "원가 %s / 평가 %s / %s%s (%s%.1f%%)" % [UIUtil._fmt_won_short(tot_cost), UIUtil._fmt_won_short(tot_eval), "+" if tot_pnl >= 0 else "", UIUtil._fmt_won_short(tot_pnl), "+" if tot_pct >= 0 else "", tot_pct]
		tot_pl.add_theme_font_size_override("font_size", 14)
		tot_pl.add_theme_color_override("font_color", COL_UP if tot_pnl >= 0 else COL_DOWN)
		tot_pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tot_row.add_child(tot_pl)


## 자산 요약 카드 한 줄 추가
func _add_asset_summary_card(item: Dictionary, type: String, value_str: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_asset_breakdown_container.add_child(row)
	# 아이콘
	var tex: Texture2D = null
	match type:
		"house":
			tex = _get_biz_icon("house_" + item.get("id", ""))
		"vehicle":
			tex = _get_biz_icon("vehicle_" + item.get("id", ""))
		"business":
			tex = _get_biz_icon("biz_" + item.get("id", ""))
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	# 이름
	var nl := Label.new()
	nl.text = "  %s" % item.get("name", item.get("id", ""))
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nl)
	# 값
	var vl := Label.new()
	vl.text = value_str
	vl.add_theme_font_size_override("font_size", 14)
	vl.add_theme_color_override("font_color", COL_GOLD)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.custom_minimum_size = Vector2(100, 0)
	row.add_child(vl)

	# ── 순자산 증감 그래프 ──
	var nw_history: Array = GameManager.get_net_worth_history()
	if nw_history.size() >= 2:
		var graph_sep := HSeparator.new()
		_asset_breakdown_container.add_child(graph_sep)

		var nw_header := Label.new()
		nw_header.text = "  순자산 추이"
		nw_header.add_theme_font_size_override("font_size", 18)
		nw_header.add_theme_color_override("font_color", COL_ACCENT)
		_asset_breakdown_container.add_child(nw_header)

		# Sparkline으로 순자산 그래프 표시
		var spark_script := load("res://scripts/Sparkline.gd")
		var nw_spark := Control.new()
		nw_spark.set_script(spark_script)
		nw_spark.custom_minimum_size = Vector2(0, 120)
		nw_spark.name = "NetWorthGraph"
		_asset_breakdown_container.add_child(nw_spark)

		# 값 배열 추출
		var values: Array = []
		for entry in nw_history:
			values.append(float(entry.get("value", 0)))
		var first_val: float = values[0]
		var last_val: float = values[values.size() - 1]
		nw_spark.set_data(values, last_val >= first_val)

		# 증감률 표시
		var pct_change: float = (last_val - first_val) / first_val * 100.0 if first_val > 0 else 0.0
		var change_sign := "+" if pct_change >= 0 else ""
		var change_color := COL_UP if pct_change > 0 else (COL_DOWN if pct_change < 0 else COL_TEXT_DIM)
		var change_lbl := Label.new()
		change_lbl.text = "  시작 대비 %s%.1f%% | 현재 순자산 %s" % [change_sign, pct_change, UIUtil._fmt_won(last_val)]
		change_lbl.add_theme_font_size_override("font_size", 15)
		change_lbl.add_theme_color_override("font_color", change_color)
		_asset_breakdown_container.add_child(change_lbl)


## 사업 목록 갱신
func _refresh_business_view() -> void:
	# 기존 자식 전체 제거 (헤더 + 카드)
	for c in _asset_business_container.get_children():
		c.queue_free()
	# 헤더 재추가
	var bh := Label.new()
	bh.text = "  사업 운영"
	bh.add_theme_font_size_override("font_size", 20)
	bh.add_theme_color_override("font_color", COL_ACCENT)
	_asset_business_container.add_child(bh)
	# 필터링된 카드 추가
	var defs: Array = BusinessManager.get_all_defs()
	var filter: String = _business_cat_filter
	var owned: Dictionary = BusinessManager.get_owned()
	for def_item in defs:
		if filter != "" and filter != "전체":
			if _biz_cat_name(def_item.get("category", "")) != filter:
				continue
		var biz_tier: int = int(def_item.get("tier", 1))
		var is_locked: bool = false
		if biz_tier > 1 and not owned.has(def_item.get("id", "")):
			# 같은 카테고리의 이전 티어를 보유했는지 확인
			var cat: String = def_item.get("category", "")
			var prev_tier_found: bool = false
			for other in defs:
				if int(other.get("tier", 1)) == biz_tier - 1 and other.get("category", "") == cat:
					if owned.has(other.get("id", "")):
						prev_tier_found = true
						break
			is_locked = not prev_tier_found
		var card := _create_business_card(def_item, is_locked)
		_asset_business_container.add_child(card)


## 사업 카드 생성
func _create_business_card(def: Dictionary, locked: bool = false) -> Control:
	var owned: Dictionary = BusinessManager.get_owned()
	var is_owned: bool = owned.has(def.get("id", ""))
	var entry: Dictionary = owned.get(def.get("id", ""), {})

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if locked:
		card.add_theme_stylebox_override("normal", UIUtil._flat(Color(0.06, 0.06, 0.07, 1), 6))
		card.add_theme_color_override("font_color", COL_TEXT_DIM)
		card.disabled = true
	else:
		card.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL if not is_owned else Color(0.10, 0.15, 0.12, 1), 6))
		card.add_theme_stylebox_override("hover", UIUtil._flat(COL_PANEL_LIGHT, 6))
	card.add_theme_font_size_override("font_size", 14)
	if not locked:
		card.pressed.connect(_on_business_selected.bind(def.get("id", "")))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.offset_left = 12
	vbox.offset_top = 8
	vbox.offset_right = -12
	vbox.offset_bottom = -8
	card.add_child(vbox)

	# 이름 + 카테고리
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	# 사업 아이콘
	var biz_icon := _get_biz_icon(def.get("id", ""))
	if biz_icon:
		top_row.add_child(_make_icon_rect(biz_icon, 48))

	var name_lbl := Label.new()
	name_lbl.text = ("🔒 " if locked else "") + def.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", COL_TEXT_DIM if locked else (COL_TEXT_BRIGHT if is_owned else COL_TEXT_DIM))
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

	# 사업 설명
	var biz_desc: String = def.get("desc", "")
	if biz_desc != "":
		var biz_desc_lbl := Label.new()
		biz_desc_lbl.text = "  " + biz_desc
		biz_desc_lbl.add_theme_font_size_override("font_size", 12)  # was 11
		biz_desc_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(biz_desc_lbl)

	# 정보 라인
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	vbox.add_child(info_row)

	if locked:
		_info_label(info_row, "잠김", "이전 단계 사업 필요", COL_TEXT_DIM)
		# 잠금 상태에서도 가격/회수기간 표시
		var lpp: float = float(def.get("purchase_price", 0))
		var lpd: float = float(def.get("base_revenue_per_day", 0))
		_info_label(info_row, "가격", UIUtil._fmt_won_short(lpp), COL_GOLD)
		if lpd > 0:
			_info_label(info_row, "회수", "%d일" % int(lpp / lpd), COL_TEXT_DIM)
		return card

	var daily_rev: float = 0.0
	if is_owned:
		daily_rev = BusinessManager._calc_business_daily_revenue(def.get("id", ""))
	var per_sec: float = daily_rev / 10.0 if daily_rev > 0 else 0.0

	if is_owned:
		_info_label(info_row, "수익/일", UIUtil._fmt_won_short(daily_rev), COL_UP if daily_rev > 0 else COL_TEXT_DIM)
		_info_label(info_row, "직원", "%d/5" % int(entry.get("employees", 0)), COL_TEXT_DIM)
		var ev_mult: float = float(entry.get("event_multiplier", 1.0))
		if ev_mult != 1.0:
			var ev_text := "호황" if ev_mult > 1.0 else "불황"
			_info_label(info_row, "이벤트", ev_text, COL_UP if ev_mult > 1.0 else COL_DOWN)
	else:
		# 미보유: 가격 + 회수기간
		var pp: float = float(def.get("purchase_price", 0))
		var pd: float = float(def.get("base_revenue_per_day", 0))
		_info_label(info_row, "가격", UIUtil._fmt_won_short(pp), COL_GOLD)
		if pd > 0:
			_info_label(info_row, "수익/일", UIUtil._fmt_won_short(pd), COL_UP)
			_info_label(info_row, "회수", "%d일" % int(pp / pd), COL_ACCENT)

	return card


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


## 사업 선택 — 상세 팝업 표시
func _on_business_selected(biz_id: String) -> void:
	_show_business_detail_popup(biz_id)

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
	_speed1_btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT if cur_speed == 1.0 and not cur_paused else COL_PANEL, 4))
	_speed2_btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT if cur_speed == 2.0 and not cur_paused else COL_PANEL, 4))
	_speed4_btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT if cur_speed == 4.0 and not cur_paused else COL_PANEL, 4))
	_speed1_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 1.0 and not cur_paused else COL_TEXT_DIM)
	_speed2_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 2.0 and not cur_paused else COL_TEXT_DIM)
	_speed4_btn.add_theme_color_override("font_color", Color.WHITE if cur_speed == 4.0 and not cur_paused else COL_TEXT_DIM)


func _life_row(item: Dictionary, type: String, is_cur: bool, locked: bool, _idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 70)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)

	if is_cur:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(Color(0.10, 0.15, 0.10, 1), 4))
		btn.add_theme_color_override("font_color", COL_UP)
	elif locked:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(Color(0.06, 0.06, 0.07, 1), 4))
		btn.add_theme_color_override("font_color", COL_TEXT_DIM)
		btn.disabled = true
	else:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
		btn.add_theme_stylebox_override("hover", UIUtil._flat(COL_PANEL_LIGHT, 4))
	# 클릭 시 상세 팝업 표시 (직접 구매 아님)
	btn.pressed.connect(_on_life_selected.bind(type, item["id"]))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	btn.add_child(outer)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	outer.add_child(hbox)

	# 아이콘
	var icon_tex := _get_life_icon(type, item["id"])
	if icon_tex:
		hbox.add_child(_make_icon_rect(icon_tex, 48))

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

	var price := Label.new()
	if is_cur:
		price.text = "보유"
	elif locked:
		price.text = "잠금"
	elif item["price"] == 0:
		price.text = "기본"
	else:
		price.text = UIUtil._fmt_won(item["price"])
	price.add_theme_font_size_override("font_size", 16)
	price.custom_minimum_size = Vector2(160, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not is_cur and not locked:
		price.add_theme_color_override("font_color", COL_GOLD)
	hbox.add_child(price)

	# 설명 라인
	var desc_text: String = item.get("desc", "")
	if desc_text == "":
		# desc가 없으면 energy/happiness로 자동 생성
		var parts: Array = []
		var eb: int = int(item.get("energy_bonus", 0))
		var hp: int = int(item.get("happiness", 0))
		if eb > 0:
			parts.append("체력 +%d" % eb)
		if hp > 0:
			parts.append("행복도 +%d" % hp)
		if parts.is_empty():
			desc_text = "효과 없음"
		else:
			desc_text = "  ".join(parts)
	var desc_label := Label.new()
	desc_label.text = "    " + desc_text
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", COL_TEXT_DIM)
	outer.add_child(desc_label)

	return btn


## 사업 상세 팝업
func _show_business_detail_popup(biz_id: String) -> void:
	var defs: Array = BusinessManager.get_all_defs()
	var def: Dictionary = {}
	for d in defs:
		if d.get("id", "") == biz_id:
			def = d
			break
	if def.is_empty():
		return

	var owned: Dictionary = BusinessManager.get_owned()
	var is_owned: bool = owned.has(biz_id)
	var entry: Dictionary = owned.get(biz_id, {})

	GameClockManager.pause_for_event()

	# 오버레이
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	add_child(overlay)

	# 팝업 — 화면 중앙 배치
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(520, 420)
	popup.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL_LIGHT, 8))
	popup.z_index = 71
	# 명시적 중앙 배치 (anchors)
	popup.set_anchor(SIDE_LEFT, 0.5)
	popup.set_anchor(SIDE_RIGHT, 0.5)
	popup.set_anchor(SIDE_TOP, 0.5)
	popup.set_anchor(SIDE_BOTTOM, 0.5)
	popup.set_offset(SIDE_LEFT, -260)
	popup.set_offset(SIDE_RIGHT, 260)
	popup.set_offset(SIDE_TOP, -210)
	popup.set_offset(SIDE_BOTTOM, 210)
	add_child(popup)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.offset_left = 20
	main_hbox.offset_top = 20
	main_hbox.offset_right = -20
	main_hbox.offset_bottom = -20
	popup.add_child(main_hbox)

	# 좌측: 사업 아이콘
	var biz_icon := _get_biz_icon(biz_id)
	if biz_icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = biz_icon
		icon_rect.custom_minimum_size = Vector2(128, 128)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main_hbox.add_child(icon_rect)

	# 우측: 정보 + 버튼
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text = def.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	content.add_child(name_lbl)

	# 카테고리
	var cat_lbl := Label.new()
	cat_lbl.text = _biz_cat_name(def.get("category", ""))
	cat_lbl.add_theme_font_size_override("font_size", 14)
	cat_lbl.add_theme_color_override("font_color", COL_ACCENT)
	content.add_child(cat_lbl)

	# 티어 정보
	var tier: int = int(def.get("tier", 1))
	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %d" % tier
	tier_lbl.add_theme_font_size_override("font_size", 14)
	tier_lbl.add_theme_color_override("font_color", COL_GOLD if tier >= 3 else COL_TEXT_DIM)
	content.add_child(tier_lbl)

	# 설명
	var biz_desc: String = def.get("desc", "")
	if biz_desc != "":
		var desc_lbl := Label.new()
		desc_lbl.text = biz_desc
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		content.add_child(desc_lbl)

	# 보유 상태
	if is_owned:
		var cur_lbl := Label.new()
		cur_lbl.text = "현재 보유 중"
		cur_lbl.add_theme_font_size_override("font_size", 15)
		cur_lbl.add_theme_color_override("font_color", COL_UP)
		content.add_child(cur_lbl)

		# 레벨
		var lvl_lbl := Label.new()
		lvl_lbl.text = "레벨: %d" % int(entry.get("level", 1))
		lvl_lbl.add_theme_font_size_override("font_size", 15)
		lvl_lbl.add_theme_color_override("font_color", COL_GOLD)
		content.add_child(lvl_lbl)

		# 직원 수
		var emp_lbl := Label.new()
		emp_lbl.text = "직원: %d/5" % int(entry.get("employees", 0))
		emp_lbl.add_theme_font_size_override("font_size", 15)
		emp_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		content.add_child(emp_lbl)

		# 일일 수익
		var daily_rev: float = BusinessManager._calc_business_daily_revenue(biz_id)
		var rev_lbl := Label.new()
		rev_lbl.text = "일일 수익: " + UIUtil._fmt_won_short(daily_rev)
		rev_lbl.add_theme_font_size_override("font_size", 15)
		rev_lbl.add_theme_color_override("font_color", COL_UP)
		content.add_child(rev_lbl)

		# 이벤트 배율
		var ev_mult: float = float(entry.get("event_multiplier", 1.0))
		if ev_mult != 1.0:
			var ev_text := "이벤트: %s (x%.1f)" % [("호황" if ev_mult > 1.0 else "불황"), ev_mult]
			var ev_lbl := Label.new()
			ev_lbl.text = ev_text
			ev_lbl.add_theme_font_size_override("font_size", 15)
			ev_lbl.add_theme_color_override("font_color", COL_UP if ev_mult > 1.0 else COL_DOWN)
			content.add_child(ev_lbl)

		# 자동화 토글
		var auto_upgrade_btn := _make_biz_auto_toggle("자동 업그레이드", "biz_auto_upgrade")
		content.add_child(auto_upgrade_btn)
		var auto_hire_btn := _make_biz_auto_toggle("자동 고용", "biz_auto_hire")
		content.add_child(auto_hire_btn)

		# 업그레이드 효율 (보유)
		var up_cost_val: float = BusinessManager.get_upgrade_cost(biz_id)
		var cur_daily: float = BusinessManager._calc_business_daily_revenue(biz_id)
		if cur_daily > 0:
			var gain_per_day: float = cur_daily * 0.2
			var up_payback: int = int(up_cost_val / gain_per_day)
			var eff_lbl := Label.new()
			eff_lbl.text = "업그레이드 효율: +%s/일 (회수 %d일)" % [UIUtil._fmt_won_short(gain_per_day), up_payback]
			eff_lbl.add_theme_font_size_override("font_size", 14)
			eff_lbl.add_theme_color_override("font_color", COL_ACCENT)
			content.add_child(eff_lbl)
	else:
		var cur_lbl := Label.new()
		cur_lbl.text = "미보유"
		cur_lbl.add_theme_font_size_override("font_size", 15)
		cur_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		content.add_child(cur_lbl)

		# 가격
		var price_lbl := Label.new()
		price_lbl.text = "가격: " + UIUtil._fmt_won(float(def.get("purchase_price", 0)))
		price_lbl.add_theme_font_size_override("font_size", 16)
		price_lbl.add_theme_color_override("font_color", COL_GOLD)
		content.add_child(price_lbl)

		# 일일 예상 수익
		var est_rev: float = float(def.get("base_revenue_per_day", 0))
		if est_rev > 0:
			var est_lbl := Label.new()
			est_lbl.text = "예상 일일 수익: " + UIUtil._fmt_won_short(est_rev)
			est_lbl.add_theme_font_size_override("font_size", 15)
			est_lbl.add_theme_color_override("font_color", COL_UP)
			content.add_child(est_lbl)

		# 예상 회수기간 (미보유)
		var buy_price: float = float(def.get("purchase_price", 0))
		var base_daily: float = float(def.get("base_revenue_per_day", 0))
		if base_daily > 0:
			var payback: int = int(buy_price / base_daily)
			var payback_lbl := Label.new()
			payback_lbl.text = "예상 회수기간: %d일" % payback
			payback_lbl.add_theme_font_size_override("font_size", 15)
			payback_lbl.add_theme_color_override("font_color", COL_ACCENT)
			content.add_child(payback_lbl)

	# 빈 공간
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sp)

	# 버튼 행
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	content.add_child(btn_row)

	if not is_owned:
		# 구매 버튼
		var price_val: float = float(def.get("purchase_price", 0))
		var buy_btn := Button.new()
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(120, 42)
		buy_btn.add_theme_font_size_override("font_size", 18)
		buy_btn.add_theme_color_override("font_color", COL_UP)
		var cat_count: int = BusinessManager._count_category(def.get("category", ""))
		if cat_count >= 2:
			buy_btn.text = "카테고리 한도"
			buy_btn.disabled = true
		elif not GameManager.can_afford(price_val):
			buy_btn.disabled = true
			buy_btn.text = "잔액 부족"
		buy_btn.pressed.connect(
			func():
				var r: Dictionary = BusinessManager.purchase(biz_id)
				if r.get("success"):
					AudioManager.play_buy()
					_show_toast("사업 구매: %s" % r.get("business", {}).get("name", ""))
				else:
					AudioManager.play_error()
					_show_toast("실패: " + r.get("reason", ""))
				overlay.queue_free()
				popup.queue_free()
				GameClockManager.resume_from_event()
				_refresh_asset_view()
		)
		btn_row.add_child(buy_btn)
	else:
		# 업그레이드 버튼
		var up_cost: float = BusinessManager.get_upgrade_cost(biz_id)
		var up_btn := Button.new()
		var cur_level: int = int(entry.get("level", 1))
		if cur_level >= 10:
			up_btn.text = "최대 레벨"
			up_btn.disabled = true
		elif not GameManager.can_afford(up_cost):
			up_btn.text = "업그레이드 (잔액 부족)"
			up_btn.disabled = true
		else:
			up_btn.text = "업그레이드 (" + UIUtil._fmt_won_short(up_cost) + ")"
		up_btn.custom_minimum_size = Vector2(140, 42)
		up_btn.add_theme_font_size_override("font_size", 16)
		up_btn.add_theme_color_override("font_color", COL_GOLD)
		up_btn.pressed.connect(
			func():
				var r: Dictionary = BusinessManager.upgrade(biz_id)
				if r.get("success"):
					AudioManager.play_buy()
					_show_toast("업그레이드: Lv.%d" % r.get("new_level", 1))
				else:
					AudioManager.play_error()
					_show_toast("실패: " + r.get("reason", ""))
				overlay.queue_free()
				popup.queue_free()
				GameClockManager.resume_from_event()
				_refresh_asset_view()
		)
		btn_row.add_child(up_btn)

		# 직원 고용 버튼
		var emp_count: int = int(entry.get("employees", 0))
		var emp_btn := Button.new()
		if emp_count >= 5:
			emp_btn.text = "직원 정원 (5/5)"
			emp_btn.disabled = true
		else:
			emp_btn.text = "직원 고용 (%d/5)" % emp_count
		emp_btn.custom_minimum_size = Vector2(140, 42)
		emp_btn.add_theme_font_size_override("font_size", 16)
		emp_btn.add_theme_color_override("font_color", COL_ACCENT)
		emp_btn.pressed.connect(
			func():
				var r: Dictionary = BusinessManager.hire_employee(biz_id)
				if r.get("success"):
					_show_toast("직원 고용: %d/5" % r.get("employees", 0))
				else:
					AudioManager.play_error()
					_show_toast("실패: " + r.get("reason", ""))
				overlay.queue_free()
				popup.queue_free()
				GameClockManager.resume_from_event()
				_refresh_asset_view()
		)
		btn_row.add_child(emp_btn)

	# 닫기 버튼
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(100, 42)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", COL_TEXT_DIM)
	close_btn.pressed.connect(
		func():
			overlay.queue_free()
			popup.queue_free()
			GameClockManager.resume_from_event()
	)
	btn_row.add_child(close_btn)

	# ESC 키로 닫기 — overlay에 포커스 설정
	overlay.gui_input.connect(
		func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				overlay.queue_free()
				popup.queue_free()
				GameClockManager.resume_from_event()
	)


func _make_biz_auto_toggle(label_text: String, key: String) -> Button:
	var btn := Button.new()
	var is_on: bool = GameManager.player.get(key, true)
	btn.text = "%s: %s" % [label_text, "ON" if is_on else "OFF"]
	btn.custom_minimum_size = Vector2(160, 36)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", COL_UP if is_on else COL_TEXT_DIM)
	btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
	btn.pressed.connect(func():
		var cur: bool = GameManager.player.get(key, true)
		GameManager.player[key] = not cur
		var updated: bool = not cur
		btn.text = "%s: %s" % [label_text, "ON" if updated else "OFF"]
		btn.add_theme_color_override("font_color", COL_UP if updated else COL_TEXT_DIM)
	)
	return btn


## 주거/차량 선택 — 상세 팝업 표시
func _on_life_selected(type: String, item_id: String) -> void:
	_selected_life_type = type
	_selected_life_id = item_id
	_show_life_detail_popup(type, item_id)


## 주거/차량 상세 팝업
func _show_life_detail_popup(type: String, item_id: String) -> void:
	var item: Dictionary
	if type == "house":
		item = GameManager.get_current_house()
		for h in GameManager.get_housing_list():
			if h["id"] == item_id:
				item = h
				break
	else:
		for v in GameManager.get_vehicle_list():
			if v["id"] == item_id:
				item = v
				break
	if item.is_empty():
		return

	var is_cur: bool = false
	if type == "house":
		is_cur = (GameManager.player["house"] == item_id)
	else:
		is_cur = (GameManager.player["vehicle"] == item_id)

	GameClockManager.pause_for_event()

	# 오버레이
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 70
	add_child(overlay)

	# 팝업 — 화면 중앙 배치
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(520, 380)
	popup.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL_LIGHT, 8))
	popup.z_index = 71
	# 명시적 중앙 배치 (anchors)
	popup.set_anchor(SIDE_LEFT, 0.5)
	popup.set_anchor(SIDE_RIGHT, 0.5)
	popup.set_anchor(SIDE_TOP, 0.5)
	popup.set_anchor(SIDE_BOTTOM, 0.5)
	popup.set_offset(SIDE_LEFT, -260)
	popup.set_offset(SIDE_RIGHT, 260)
	popup.set_offset(SIDE_TOP, -190)
	popup.set_offset(SIDE_BOTTOM, 190)
	add_child(popup)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	main_hbox.offset_left = 20
	main_hbox.offset_top = 20
	main_hbox.offset_right = -20
	main_hbox.offset_bottom = -20
	popup.add_child(main_hbox)

	# 좌측: 도트 이미지
	var icon := _get_life_icon(type, item_id)
	if icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = Vector2(128, 128)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		main_hbox.add_child(icon_rect)

	# 우측: 정보 + 구매
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(content)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	content.add_child(name_lbl)

	# 상태 표시
	if is_cur:
		var cur_lbl := Label.new()
		cur_lbl.text = "현재 보유 중"
		cur_lbl.add_theme_font_size_override("font_size", 15)
		cur_lbl.add_theme_color_override("font_color", COL_UP)
		content.add_child(cur_lbl)

	# 가격
	var price_lbl := Label.new()
	if item.get("price", 0) == 0:
		price_lbl.text = "가격: 기본 제공"
	elif is_cur:
		price_lbl.text = "가격: 구매 완료"
	else:
		price_lbl.text = "가격: " + UIUtil._fmt_won(float(item["price"]))
	price_lbl.add_theme_font_size_override("font_size", 16)
	price_lbl.add_theme_color_override("font_color", COL_GOLD)
	content.add_child(price_lbl)

	# 효과
	var effects_text := ""
	if item.get("energy_bonus", 0) > 0:
		effects_text += "정보력 +%d  " % item["energy_bonus"]
	if item.get("happiness", 0) > 0:
		effects_text += "행복 +%d  " % item["happiness"]
	if item.get("rental_income_per_day", 0) > 0:
		effects_text += "임대수익 %s/일  " % UIUtil._fmt_won_short(float(item["rental_income_per_day"]))

	var effects_lbl := Label.new()
	if effects_text == "":
		effects_lbl.text = "특수 효과 없음"
		effects_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	else:
		effects_lbl.text = "효과: " + effects_text
		effects_lbl.add_theme_color_override("font_color", COL_ACCENT)
	effects_lbl.add_theme_font_size_override("font_size", 15)
	content.add_child(effects_lbl)

	# 빈 공간
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(sp)

	# 버튼 행
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	content.add_child(btn_row)

	if not is_cur:
		# 구매 버튼
		var buy_btn := Button.new()
		var price_val: float = float(item.get("price", 0))
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(120, 42)
		buy_btn.add_theme_font_size_override("font_size", 18)
		buy_btn.add_theme_color_override("font_color", COL_UP)
		if not GameManager.can_afford(price_val) and price_val > 0:
			buy_btn.disabled = true
			buy_btn.text = "잔액 부족"
		buy_btn.pressed.connect(
			func():
				var r: Dictionary
				if type == "house":
					r = GameManager.buy_house(item_id)
				else:
					r = GameManager.buy_vehicle(item_id)
				if r.get("success"):
					AudioManager.play_buy()
					_show_toast("구매 완료: %s" % item.get("name", ""))
					_refresh_asset_view()
				else:
					AudioManager.play_error()
					_show_toast("실패: " + r.get("reason", ""))
				overlay.queue_free()
				popup.queue_free()
				GameClockManager.resume_from_event()
		)
		btn_row.add_child(buy_btn)

	# 닫기 버튼
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(100, 42)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", COL_TEXT_DIM)
	close_btn.pressed.connect(
		func():
			overlay.queue_free()
			popup.queue_free()
			GameClockManager.resume_from_event()
	)
	btn_row.add_child(close_btn)


## 종목 로고 획득 (PNG 우선, 없으면 IconGenerator)
func _get_stock_icon(stock_id: String) -> Texture2D:
	# 1. PNG 파일 확인
	var png_path := "res://assets/images/stocks/stock_%s.png" % stock_id
	if FileAccess.file_exists(png_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img:
			return ImageTexture.create_from_image(img)
	# 2. IconGenerator 도트 아이콘
	var icon_gen := IconGenerator.new()
	return icon_gen.make_stock_logo(stock_id, 48)


## 주거/차량 아이콘 획득
func _get_life_icon(type: String, item_id: String) -> Texture2D:
	# 1. PNG 파일이 있으면 로드
	var png_path := "res://assets/images/%s_%s.png" % [type, item_id]
	if FileAccess.file_exists(png_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img:
			return ImageTexture.create_from_image(img)

	# 2. IconGenerator로 도트 아이콘 생성
	var icon_gen := IconGenerator.new()
	if type == "house":
		return icon_gen.make_house_icon(item_id, 96)
	elif type == "vehicle":
		return icon_gen.make_vehicle_icon(item_id, 96)
	return null


## 사업 아이콘 획득
func _get_biz_icon(biz_id: String) -> Texture2D:
	var png_path := "res://assets/images/biz_%s.png" % biz_id
	if FileAccess.file_exists(png_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img:
			return ImageTexture.create_from_image(img)
	# 폴백: 카테고리 색상으로 채운 단순 도트 아이콘
	var icon_gen := IconGenerator.new()
	return icon_gen.make_stock_logo(biz_id, 48)


## NPC 아이콘 획득
func _get_npc_icon(npc_id: String) -> Texture2D:
	var png_path := "res://assets/images/npc_%s.png" % npc_id
	if FileAccess.file_exists(png_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img:
			return ImageTexture.create_from_image(img)
	return null


## 공통 아이콘 TextureRect 생성
func _make_icon_rect(tex: Texture2D, icon_size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


# ═══════════════════════════════════════════════
#   뷰 전환
# ═══════════════════════════════════════════════

func _show_view(view_name: String) -> void:
	_current_view = view_name
	_market_view.visible = (view_name == "시장")
	_portfolio_view.visible = (view_name == "포트폴리오")
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
		"포트폴리오":
			_refresh_breakdown()
		"자산": _refresh_asset_view()
		"NPC": _refresh_npc_view()
		"진행": _refresh_progress_view()


func _on_view_tab_pressed(vn: String) -> void:
	_show_view(vn)


func _update_view_tab_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
		btn.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85, 1))


# ═══════════════════════════════════════════════
#   이벤트 핸들러
# ═══════════════════════════════════════════════

func _on_cat_pressed(cat: String) -> void:
	if cat == "전체":
		_current_category = ""
	else:
		_current_category = CATEGORY_MAP[cat]
	for child in _cat_tabs.get_children():
		if child is Button and child.has_meta("category"):
			_update_cat_style(child, child.get_meta("category") == cat)
	_apply_cat_filter()


func _update_cat_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
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
		if _detail_logo:
			_detail_logo.texture = null
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	# 로고 갱신
	if _detail_logo:
		var tex := _get_stock_icon(_selected_stock)
		_detail_logo.texture = tex
	_detail_name.text = s["name"]
	_detail_ticker.text = s.get("ticker", "")
	_detail_meta.text = "%s / %s" % [_cat_tag_kr(s.get("category", "")), s.get("sector", "")]
	# 가격 정보 영역
	var pct: float = s.get("change_pct", 0.0)
	_detail_price.text = "현재가  %s" % UIUtil._fmt_price(s["price"])
	_detail_change.text = "등락률  %s" % UIUtil._fmt_change(pct)
	_detail_change.add_theme_color_override("font_color", UIUtil._chg_color(pct))
	_detail_price.add_theme_color_override("font_color", UIUtil._chg_color(pct) if abs(pct) > 0.1 else COL_TEXT_BRIGHT)
	var q: int = GameManager.get_holding_quantity(_selected_stock)
	if q > 0:
		var avg: float = float(GameManager.get_holding(_selected_stock).get("avg_price", 0))
		var eval_amount: float = float(s["price"]) * q
		var pnl: float = eval_amount - avg * q
		_detail_holding.text = "보유  %d주" % q
		_detail_avg_price.text = "평단가  %s" % UIUtil._fmt_price(avg)
		_detail_eval_amount.text = "평가금액  %s" % UIUtil._fmt_price(eval_amount)
		_detail_eval_pnl.text = "평가손익  %s%s" % ["+" if pnl >= 0 else "", UIUtil._fmt_won(pnl)]
		_detail_eval_pnl.add_theme_color_override("font_color", COL_UP if pnl >= 0 else COL_DOWN)
	else:
		_detail_holding.text = "보유 없음"
		_detail_avg_price.text = ""
		_detail_eval_amount.text = ""
		_detail_eval_pnl.text = ""
	if _detail_sparkline:
		var detail_hist: Array = MarketSim.get_price_history(_selected_stock)
		if detail_hist.size() >= 2:
			_detail_sparkline.set_data(detail_hist, pct >= 0)
	# D/W/M/Y 수익률 갱신
	var current_day: int = GameManager.player.get("day", 1)
	var dwmy := MarketSim.get_dwmy_returns(_selected_stock, current_day)
	for key in ["D", "W", "M", "Y"]:
		var lbl: Label = _detail_dwmy_labels.get(key)
		if lbl == null:
			continue
		var val: float = dwmy.get(key, NAN)
		if is_nan(val):
			lbl.text = "%s  --" % key
			lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
		else:
			var sign := "+" if val >= 0 else ""
			lbl.text = "%s  %s%.2f%%" % [key, sign, val]
			if val > 0.01:
				lbl.add_theme_color_override("font_color", COL_UP)
			elif val < -0.01:
				lbl.add_theme_color_override("font_color", COL_DOWN)
			else:
				lbl.add_theme_color_override("font_color", COL_TEXT_DIM)
	_on_qty_changed(_trade_qty_edit.value)
	_update_trade_button_states()

func _cat_tag_kr(cat: String) -> String:
	match cat:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return cat

func _update_row_selection() -> void:
	# 선택된 행: 밝은 강조, 비선택 행: 기본 어두운 톤
	var col_normal := Color(0.094, 0.110, 0.133, 1)   # #181C22
	var col_hover := Color(0.141, 0.157, 0.220, 1)    # #242838
	var col_selected := Color(0.189, 0.204, 0.290, 1) # #30344A
	for sid in _stock_rows:
		var row: Control = _stock_rows[sid]
		if sid == _selected_stock:
			row.add_theme_stylebox_override("normal", UIUtil._flat(col_selected, 0))
			row.add_theme_stylebox_override("hover", UIUtil._flat(col_selected, 0))
		else:
			row.add_theme_stylebox_override("normal", UIUtil._flat(col_normal, 0))
			row.add_theme_stylebox_override("hover", UIUtil._flat(col_hover, 0))


func _on_qty_changed(value: float) -> void:
	if _selected_stock == "":
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	_trade_total_label.text = UIUtil._fmt_won(s["price"] * int(value))


func _on_buy() -> void:
	if _selected_stock == "":
		return
	if not _can_trade_stock(_selected_stock):
		_show_toast("장 시간이 아닙니다 (코인은 24시간 거래)", COL_DOWN)
		return
	var qty := int(_trade_qty_edit.value)
	var r := GameManager.buy_stock(_selected_stock, qty)
	if r.get("success"):
		AudioManager.play_buy()
		_show_toast("매수 완료: %d주 (%s)" % [qty, UIUtil._fmt_won(r["cost"])])
		_update_detail_panel()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))


func _on_sell() -> void:
	if _selected_stock == "":
		return
	if not _can_trade_stock(_selected_stock):
		_show_toast("장 시간이 아닙니다 (코인은 24시간 거래)", COL_DOWN)
		return
	var qty := int(_trade_qty_edit.value)
	var stock: Dictionary = MarketSim.get_stock(_selected_stock)
	var r := GameManager.sell_stock(_selected_stock, qty)
	if r.get("success"):
		AudioManager.play_sell()
		UIAnim.pulse(_detail_panel)
		var stock_name: String = stock.get("name", _selected_stock)
		# 수익실현 알림
		if r.has("profit"):
			var p: float = r["profit"]
			if p >= 0:
				_show_toast_priority("수익실현 +%s" % UIUtil._fmt_won(p), "high", COL_UP)
			else:
				_show_toast_priority("손실실현 -%s" % UIUtil._fmt_won(abs(p)), "high", COL_DOWN)
		# 현금 증가 표시
		if r.has("revenue"):
			_show_toast("%s %d주 매도 완료 (현금 +%s)" % [stock_name, qty, UIUtil._fmt_won(float(r["revenue"]))], COL_TEXT_BRIGHT)
		else:
			_show_toast("%s %d주 매도 완료" % [stock_name, qty], COL_TEXT_BRIGHT)
		_update_detail_panel()
	else:
		AudioManager.play_error()
		_show_toast("실패: " + r.get("reason", ""))


## 장 개장 여부 확인 — 종목 category 기준
func _is_market_open() -> bool:
	return GameClockManager.current_phase == GameClockManager.Phase.MARKET


## 특정 종목의 거래 가능 여부
func _can_trade_stock(stock_id: String) -> bool:
	var s: Dictionary = MarketSim.get_stock(stock_id)
	if s.is_empty():
		return false
	# 코인은 24시간 거래 가능
	if s.get("category", "") == "coin":
		return true
	# 한국/미국 주식은 장중에만 거래 가능
	return GameClockManager.current_phase == GameClockManager.Phase.MARKET


## 자산의 pct%로 매수 수량 계산 (체결 아님, 수량만 채움)
func _on_buy_pct(pct: int) -> void:
	if _selected_stock == "":
		return
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if s.is_empty():
		return
	var price: float = float(s["price"])
	if price <= 0:
		return
	var cash: float = GameManager.get_cash()
	var budget: float = cash * (float(pct) / 100.0)
	# 수수료 고려: 실제 체결 시 현금 부족 방지
	# GameManager.buy_stock에서 fee를 떼는지 확인 필요
	# 안전 마진으로 budget의 99%만 사용
	var safe_budget: float = budget * 0.99
	var qty := int(safe_budget / price)
	if qty < 1:
		_show_toast("잔액 부족 (예산 %s)" % UIUtil._fmt_won(budget))
		_trade_qty_edit.value = 0
		return
	_trade_qty_edit.value = qty
	_show_toast("매수 예정: %d주 (%s)" % [qty, UIUtil._fmt_won(price * qty)])


## 보유 주식의 pct%만큼 수량 계산 (체결 아님, 수량만 채움)
func _on_sell_pct(pct: int) -> void:
	if _selected_stock == "":
		return
	var held: int = GameManager.get_holding_quantity(_selected_stock)
	if held < 1:
		_show_toast("보유 주식 없음")
		return
	var qty := int(float(held) * (float(pct) / 100.0))
	# 100%는 floor 계산이 아닌 전체 보유 수량
	if pct == 100:
		qty = held
	elif qty < 1 and held > 0:
		qty = 1
	_trade_qty_edit.value = qty
	var s: Dictionary = MarketSim.get_stock(_selected_stock)
	if not s.is_empty():
		_show_toast("매도 예정: %d주 (%s)" % [qty, UIUtil._fmt_won(float(s["price"]) * qty)])


## 매수/매도 버튼 활성/비활성 상태 관리
func _update_trade_button_states() -> void:
	var sell_btn: Node = _detail_panel.find_child("SellButton")
	if sell_btn is Button:
		var held: int = 0
		if _selected_stock != "":
			held = GameManager.get_holding_quantity(_selected_stock)
		(sell_btn as Button).disabled = (held < 1)
		# 매도 % 버튼들도 함께 비활성화
		var pct_row2 := sell_btn.get_parent().get_parent().find_child("HBoxContainer", true, false)
	# 매수 버튼: 현금이 0 이하면 비활성화
	var buy_btn: Node = _detail_panel.find_child("BuyButton")
	if buy_btn is Button:
		var cash: float = GameManager.get_cash()
		(buy_btn as Button).disabled = (cash <= 0)


func _on_clock_day_advanced(day: int, r: Dictionary) -> void:
	AudioManager.play_day_advance()
	var msg := "%d일차 시작" % day
	_refresh_asset_view()
	if r.get("salary", 0.0) > 0:
		msg += " | 월급 +%s" % UIUtil._fmt_won(r["salary"])
	if r.get("rank_up", "") != "":
		msg += " | 승진! -> %s" % r["rank_up"]
		_rank_label.text = "  " + GameManager.get_rank_name()
		AudioManager.play_rank_up()
		UIAnim.pop_in(_rank_label)
	if r.has("bailout"):
		msg += " | 파산방지 +%s" % UIUtil._fmt_won(r["bailout"])
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
		# 중요 뉴스 토스트 알림
		if event.has("stock_ids") and abs(float(event.get("impact", 0))) >= 0.5:
			var sids: Array = event.get("stock_ids", [])
			var sid: String = str(sids[0]) if sids.size() > 0 else ""
			_show_news_alert(etitle, sid)
	_process_biz_automation()
	_refresh_progress_view()


func _process_biz_automation() -> void:
	if not GameManager.player.get("biz_auto_upgrade", true) and not GameManager.player.get("biz_auto_hire", true):
		return
	var owned: Dictionary = BusinessManager.get_owned()
	var cash: float = float(GameManager.player.get("cash", 0))
	for biz_id in owned.keys():
		if GameManager.player.get("biz_auto_upgrade", true):
			var ucost: float = BusinessManager.get_upgrade_cost(biz_id)
			if ucost > 0 and cash >= ucost:
				var r: Dictionary = BusinessManager.upgrade(biz_id)
				if r.get("success"):
					cash -= ucost
		if GameManager.player.get("biz_auto_hire", true):
			var entry: Dictionary = owned[biz_id]
			var emp: int = int(entry.get("employees", 0))
			if emp < 5:
				var e: int = int(GameManager.player.get("energy", 0))
				if e >= 3:
					BusinessManager.hire_employee(biz_id)
					GameManager.player["energy"] = e - 3


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
		_show_toast("장 마감 - 외부 활동", COL_GOLD)


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


## 신문 팝업 — 장전 브리핑 (신문형 도트 디자인, 화면 중앙 정렬)
var _briefing_layer: CanvasLayer = null

func _show_newspaper_popup() -> void:
	GameClockManager.pause_for_event()

	# ── 신문 색상 팔레트 ──
	var COL_PAPER := Color(0.847, 0.820, 0.745, 1)    # #D8D1BE
	var COL_PAPER_DARK := Color(0.812, 0.780, 0.702, 1) # #CFC7B3
	var COL_INK := Color(0.114, 0.114, 0.106, 1)       # #1D1D1B
	var COL_INK_DIM := Color(0.353, 0.333, 0.294, 1)   # #5A554B
	var COL_INK_SHADOW := Color(0.541, 0.502, 0.431, 1) # #8A806E
	var COL_BULL := Color(0.184, 0.490, 0.235, 1)      # #2F7D3C
	var COL_BEAR := Color(0.608, 0.184, 0.184, 1)      # #9B2F2F
	var COL_EVENT := Color(0.431, 0.290, 0.620, 1)     # #6E4A9E
	var COL_GOLD_INK := Color(0.851, 0.702, 0.302, 1)  # #D9B34D

	# ── CanvasLayer 생성 (최상위 렌더링) ──
	if _briefing_layer:
		_briefing_layer.queue_free()
	_briefing_layer = CanvasLayer.new()
	_briefing_layer.layer = 90
	add_child(_briefing_layer)

	# ── DimOverlay — 화면 전체 덮기 ──
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing_layer.add_child(overlay)

	# ── CenterContainer — 화면 중앙 정렬 ──
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing_layer.add_child(center)

	# ── 신문 패널 ──
	var popup := PanelContainer.new()
	popup.custom_minimum_size = Vector2(720, 580)
	popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(popup)

	# 신문 배경 — TextureRect 또는 StyleBox
	var paper_style := StyleBoxFlat.new()
	paper_style.bg_color = COL_PAPER
	paper_style.border_color = COL_INK
	paper_style.set_border_width_all(3)
	paper_style.set_content_margin_all(0)
	paper_style.corner_radius_top_left = 0
	paper_style.corner_radius_top_right = 0
	paper_style.corner_radius_bottom_left = 0
	paper_style.corner_radius_bottom_right = 0
	popup.add_theme_stylebox_override("panel", paper_style)

	# 배경 텍스처 (newspaper_bg.png) — 런타임 Image 로딩 (.import 불필요)
	var bg_path := "res://assets/images/newspaper_bg.png"
	var tex_loaded: bool = false
	if FileAccess.file_exists(bg_path):
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(bg_path))
		if err == OK:
			var img_tex := ImageTexture.create_from_image(img)
			var bg_rect := TextureRect.new()
			bg_rect.texture = img_tex
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
			bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_rect.modulate = Color(0.85, 0.82, 0.74, 0.4)
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			popup.add_child(bg_rect)
			tex_loaded = true
	# Fallback: 절차적 신문 배경 (텍스처 로드 실패 시)
	if not tex_loaded:
		var fallback_bg := ColorRect.new()
		fallback_bg.color = Color(0.82, 0.79, 0.72, 0.3)
		fallback_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(fallback_bg)

	# ── 콘텐츠 마진 ──
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	popup.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	# ══════ 헤더부 ══════
	var day: int = GameManager.player.get("day", 1)

	# 상단 얇은 구분선 (이중선 효과)
	root_vbox.add_child(_np_divider(COL_INK, 2, 0))
	root_vbox.add_child(_np_divider(COL_INK_SHADOW, 1, 2))

	# 큰 제목
	var title := Label.new()
	title.text = "데일리 증권 브리핑"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_INK)
	if _pixel_font:
		title.add_theme_font_override("font", _pixel_font)
	root_vbox.add_child(title)

	# 부제
	var subtitle := Label.new()
	subtitle.text = "STOCK TYCOON DAILY  |  %d일차 발행" % day
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", COL_INK_DIM)
	if _pixel_font:
		subtitle.add_theme_font_override("font", _pixel_font)
	root_vbox.add_child(subtitle)

	# 슬로건
	var slogan := Label.new()
	slogan.text = "시장을 아는 하루, 성공을 여는 한 걸음"
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slogan.add_theme_font_size_override("font_size", 12)
	slogan.add_theme_color_override("font_color", COL_INK_SHADOW)
	if _pixel_font:
		slogan.add_theme_font_override("font", _pixel_font)
	root_vbox.add_child(slogan)

	root_vbox.add_child(_np_divider(COL_INK_SHADOW, 1, 2))
	root_vbox.add_child(_np_divider(COL_INK, 2, 0))

	# ══════ 시장 요약 (전일 OHLC 기반) ══════
	var up_count: int = 0
	var down_count: int = 0
	var flat_count: int = 0
	var top_gainer := ""
	var top_gainer_pct := -9999.0
	var top_loser := ""
	var top_loser_pct := 9999.0
	var source_day: int = day - 1

	# 전일 OHLC 스냅샷으로 계산
	var ohlc := MarketSim.get_yesterday_ohlc_snapshot(day)
	if ohlc.is_empty():
		# 1일차: OHLC 없음 → 전부 보합
		var stocks: Array = MarketSim.get_all_stocks()
		flat_count = stocks.size()
	else:
		for stock_id in ohlc:
			var entry: Dictionary = ohlc[stock_id]
			var op: float = entry.get("open", 0.0)
			var cl: float = entry.get("close", 0.0)
			var name: String = MarketSim.get_stock(stock_id).get("name", stock_id)
			if op > 0:
				var pct: float = (cl - op) / op * 100.0
				if pct > 0.1:
					up_count += 1
					if pct > top_gainer_pct:
						top_gainer_pct = pct
						top_gainer = name
				elif pct < -0.1:
					down_count += 1
					if pct < top_loser_pct:
						top_loser_pct = pct
						top_loser = name
				else:
					flat_count += 1

	var market_status := "중립"
	var market_color: Color = COL_INK_DIM
	if up_count > down_count + 2:
		market_status = "강세"
		market_color = COL_BULL
	elif down_count > up_count + 2:
		market_status = "약세"
		market_color = COL_BEAR

	# 디버그 로그
	if DEBUG_BRIEFING:
		print("[BRIEFING_SUMMARY] day=%d source_day=%d 상승=%d 하락=%d 보합=%d" % [day, source_day, up_count, down_count, flat_count])
		if top_gainer != "":
			print("[BRIEFING_TOP] 대표상승=%s +%.2f 대표하락=%s %.2f" % [top_gainer, top_gainer_pct, top_loser if top_loser != "" else "없음", top_loser_pct])
		else:
			print("[BRIEFING_TOP] 대표상승=없음 대표하락=없음 (day=%d)" % day)

	# 시장 요약 — 구분선과 텍스트 겹침 방지: 배경 패널 + 여백
	var summary_bg := PanelContainer.new()
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = COL_PAPER_DARK
	sb_style.set_content_margin_all(8)
	sb_style.set_corner_radius_all(4)
	summary_bg.add_theme_stylebox_override("panel", sb_style)
	root_vbox.add_child(summary_bg)

	var summary_box := HBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 20)
	summary_box.alignment = BoxContainer.ALIGNMENT_CENTER
	summary_bg.add_child(summary_box)

	summary_box.add_child(_np_label("상승 %d" % up_count, 16, COL_BULL))
	summary_box.add_child(_np_label("하락 %d" % down_count, 16, COL_BEAR))
	summary_box.add_child(_np_label("보합 %d" % flat_count, 16, COL_INK_DIM))

	var summary_spacer := Control.new()
	summary_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_box.add_child(summary_spacer)

	summary_box.add_child(_np_label("시장: %s" % market_status, 16, market_color))

	# 대표 종목 (상단 여백 추가)
	root_vbox.add_child(_npUIUtil._spacer(8))
	var headline_row := HBoxContainer.new()
	headline_row.add_theme_constant_override("separation", 12)
	root_vbox.add_child(headline_row)

	if top_gainer != "":
		headline_row.add_child(_np_label("대표 상승: %s (+%.1f%%)" % [top_gainer, top_gainer_pct], 14, COL_BULL))
	else:
		headline_row.add_child(_np_label("대표 상승: 없음", 14, COL_INK_DIM))
	if top_loser != "":
		headline_row.add_child(_np_label("대표 하락: %s (%.1f%%)" % [top_loser, top_loser_pct], 14, COL_BEAR))
	else:
		headline_row.add_child(_np_label("대표 하락: 없음", 14, COL_INK_DIM))

	root_vbox.add_child(_npUIUtil._spacer(10))
	root_vbox.add_child(_np_divider(COL_INK_SHADOW, 1, 2))
	root_vbox.add_child(_npUIUtil._spacer(8))

	# ══════ 3컬럼 뉴스 영역 ══════
	var events := EventManager.get_active_events()

	# 뉴스 분류
	var bull_news: Array = []
	var bear_news: Array = []
	var event_news: Array = []
	for event in events:
		var ev_type: String = event.get("type", "")
		var ev_id: String = event.get("id", "")
		if ev_type == "crypto_risk":
			bear_news.append(event)
		elif ev_type == "life":
			event_news.append(event)
		else:
			if ev_id.findn("crash") >= 0 or ev_id.findn("fail") >= 0 or ev_id.findn("ban") >= 0 or ev_id.findn("recall") >= 0 or ev_id.findn("hack") >= 0 or ev_id.findn("fear") >= 0 or ev_id.findn("outage") >= 0 or ev_id.findn("fine") >= 0 or ev_id.findn("loss") >= 0:
				bear_news.append(event)
			else:
				bull_news.append(event)

	# 최대 3개씩
	bull_news = bull_news.slice(0, mini(3, bull_news.size()))
	bear_news = bear_news.slice(0, mini(3, bear_news.size()))
	event_news = event_news.slice(0, mini(3, event_news.size()))

	# 스크롤 영역
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	root_vbox.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 8)
	scroll.add_child(cols)

	cols.add_child(_np_news_column("▲ 강세 뉴스", COL_BULL, bull_news))
	cols.add_child(_np_news_column("▼ 약세 뉴스", COL_BEAR, bear_news))
	cols.add_child(_np_news_column("이벤트", COL_EVENT, event_news))

	root_vbox.add_child(_np_divider(COL_INK, 2, 0))

	# ══════ 확인 버튼 ══════
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(btn_row)

	var ok_btn := Button.new()
	ok_btn.text = "  확인  "
	ok_btn.custom_minimum_size = Vector2(140, 42)
	ok_btn.add_theme_font_size_override("font_size", 17)
	ok_btn.add_theme_color_override("font_color", COL_PAPER)
	ok_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	ok_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COL_INK
	btn_style.border_color = COL_GOLD_INK
	btn_style.set_border_width_all(2)
	btn_style.set_content_margin_all(8)
	ok_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.2, 0.2, 0.18, 1)
	ok_btn.add_theme_stylebox_override("hover", btn_hover)
	if _pixel_font:
		ok_btn.add_theme_font_override("font", _pixel_font)
	ok_btn.pressed.connect(
		func():
			MarketSim.apply_pre_market_effects()
			if _briefing_layer:
				_briefing_layer.queue_free()
				_briefing_layer = null
			GameClockManager.resume_from_event()
	)
	btn_row.add_child(ok_btn)

	# ESC 키로 닫기 — overlay에 포커스 설정
	overlay.gui_input.connect(
		func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
				MarketSim.apply_pre_market_effects()
				if _briefing_layer:
					_briefing_layer.queue_free()
					_briefing_layer = null
				GameClockManager.resume_from_event()
	)


## 신문용 헬퍼 — 세로 여백 생성
func _npUIUtil._spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## 신문용 헬퍼 — 구분선 생성
func _np_divider(color: Color, thickness: int, margin: int) -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(margin)
	sep.add_theme_stylebox_override("separator", style)
	sep.custom_minimum_size = Vector2(0, thickness + margin * 2)
	return sep


## 신문용 헬퍼 — Label 생성
func _np_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if _pixel_font:
		l.add_theme_font_override("font", _pixel_font)
	return l


## 신문용 헬퍼 — 뉴스 컬럼 생성
func _np_news_column(title: String, color: Color, news: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)

	# 컬럼 헤더
	var hdr := Label.new()
	hdr.text = title
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", color)
	if _pixel_font:
		hdr.add_theme_font_override("font", _pixel_font)
	col.add_child(hdr)

	# 헤더 밑 구분선
	var line := HSeparator.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = color
	ls.set_content_margin_all(0)
	line.add_theme_stylebox_override("separator", ls)
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)

	if news.is_empty():
		col.add_child(_np_label("  기사 없음", 13, Color(0.5, 0.47, 0.42, 1)))
	else:
		var first := true
		for item in news:
			if not first:
				col.add_child(_npUIUtil._spacer(6))  # 기사 사이 여백
			first = false
			# 타이틀 — 섹션 컬러 적용 (강세=초록, 약세=빨강, 이벤트=보라)
			col.add_child(_np_label(item.get("title", ""), 13, color))
			# 설명 (clip + ellipsis)
			var desc := Label.new()
			desc.text = "  " + item.get("desc", "")
			desc.add_theme_font_size_override("font_size", 12)
			desc.add_theme_color_override("font_color", Color(0.35, 0.33, 0.29, 1))
			desc.clip_text = true
			desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if _pixel_font:
				desc.add_theme_font_override("font", _pixel_font)
			col.add_child(desc)
			# 라이프 이벤트: 금액 표시 (양수=초록, 음수=빨강)
			if item.has("cash_reward"):
				var reward: float = float(item.get("cash_reward", 0.0))
				if reward != 0.0:
					var r_color: Color = COL_UP if reward > 0 else COL_DOWN
					var r_text := "+%s" % UIUtil._fmt_won_short(reward) if reward > 0 else "%s" % UIUtil._fmt_won_short(reward)
					col.add_child(_np_label("  " + r_text, 11, r_color))

	return col


## 퀘스트 완료 알림
func _on_quest_completed(quest_id: String, reward: Dictionary) -> void:
	AudioManager.play_quest_complete()
	var msg := "[퀘스트 완료] %s" % reward.get("name", quest_id)
	if reward.get("cash", 0.0) > 0:
		msg += " +%s" % UIUtil._fmt_won(reward["cash"])
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

	# 팝업 패널 — 화면 중앙 배치
	_cutscene_popup = PanelContainer.new()
	_cutscene_popup.custom_minimum_size = Vector2(560, 280)
	_cutscene_popup.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL_LIGHT, 8))
	_cutscene_popup.z_index = 61
	_cutscene_popup.set_anchor(SIDE_LEFT, 0.5)
	_cutscene_popup.set_anchor(SIDE_RIGHT, 0.5)
	_cutscene_popup.set_anchor(SIDE_TOP, 0.5)
	_cutscene_popup.set_anchor(SIDE_BOTTOM, 0.5)
	_cutscene_popup.set_offset(SIDE_LEFT, -280)
	_cutscene_popup.set_offset(SIDE_RIGHT, 280)
	_cutscene_popup.set_offset(SIDE_TOP, -140)
	_cutscene_popup.set_offset(SIDE_BOTTOM, 140)
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
		_cash_label.text = UIUtil._fmt_won(c)


func _on_net_worth_changed(nw: float) -> void:
	if _networth_label:
		_networth_label.text = UIUtil._fmt_won(nw)


func _on_day_advanced(d: int) -> void:
	_day_label.text = "%d일차 %s" % [d, GameClockManager.get_time_string()]


func _on_rank_up(nr: String) -> void:
	_rank_label.text = "  " + nr
	_show_toast("승진! → %s" % nr)


func _on_salary_paid(a: float) -> void:
	_show_toast("월급: +%s" % UIUtil._fmt_won(a))


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
			tog.add_theme_stylebox_override("normal", UIUtil._flat(Color(0.10, 0.15, 0.10, 1), 4))
		else:
			tog.text = "OFF"
			tog.add_theme_color_override("font_color", COL_TEXT_DIM)
			tog.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))

		# 문장형 조건 미리보기 갱신
		var preview_lbl: Label = p.find_child("PreviewLabel", true, false)
		if preview_lbl:
			preview_lbl.text = _build_at_preview(slot)
			# 장마감 상태 표시
			if slot["active"] and slot["stock_id"] != "":
				var st: Dictionary = MarketSim.get_stock(slot["stock_id"])
				var cat: String = st.get("category", "") if not st.is_empty() else ""
				if cat != "coin" and GameClockManager.current_phase != GameClockManager.Phase.MARKET:
					preview_lbl.text += " (장마감: 대기 중)"
					preview_lbl.add_theme_color_override("font_color", COL_TEXT_DIM)


## 자동매매 문장형 미리보기 생성
func _build_at_preview(slot: Dictionary) -> String:
	if slot["stock_id"] == "":
		return "종목 미선택"
	var stock: Dictionary = MarketSim.get_stock(slot["stock_id"])
	if stock.is_empty():
		return "종목 미상"
	var name: String = stock.get("name", slot["stock_id"])
	var cond: String = slot.get("condition_type", "")
	var val: float = float(slot.get("condition_value", 0))
	var qty: int = int(slot.get("quantity", 0))
	var action: String = slot.get("action", "buy")
	var action_str := "매수" if action == "buy" else "매도"
	match cond:
		"price_below":
			return "%s이(가) %s 이하이면 %d주 %s" % [name, UIUtil._fmt_price(val), qty, action_str]
		"price_above":
			return "%s이(가) %s 이상이면 %d주 %s" % [name, UIUtil._fmt_price(val), qty, action_str]
		"profit_above":
			return "%s 수익률이 %.1f%% 이상이면 %d주 %s" % [name, val, qty, action_str]
		"loss_below":
			return "%s 손실률이 %.1f%% 이상이면 %d주 %s" % [name, val, qty, action_str]
	return "%s — 조건 %s" % [name, cond]


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
		_networth_label.text = UIUtil._fmt_won(GameManager.get_net_worth())

	# 자동 수익/초 표시
	if _passive_label:
		var pps := PassiveIncomeManager.get_projected_per_second()
		if pps > 0:
			_passive_label.text = "+" + UIUtil._fmt_won_short(pps) + "/초"
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

	# PriceLabel — 딕셔너리에서 직접 참조
	var pl: Label = _stock_price_labels.get(sid)
	if pl:
		pl.text = UIUtil._fmt_price(s["price"])
		var pct: float = s.get("change_pct", 0.0)
		if pct > 0.1:
			pl.add_theme_color_override("font_color", COL_UP)
		elif pct < -0.1:
			pl.add_theme_color_override("font_color", COL_DOWN)
		else:
			pl.add_theme_color_override("font_color", COL_TEXT_BRIGHT)

	# ChangeLabel — 딕셔너리에서 직접 참조
	var cl: Label = _stock_change_labels.get(sid)
	if cl:
		var pct: float = s.get("change_pct", 0.0)
		cl.text = UIUtil._fmt_change(pct)
		cl.add_theme_color_override("font_color", UIUtil._chg_color(pct))

	# HoldLabel
	var hl_var: Node = row.find_child("HoldLabel")
	var hl: Label = hl_var if hl_var is Label else null
	if hl:
		var q: int = GameManager.get_holding_quantity(sid)
		if q > 0:
			hl.text = "%d주" % q
			hl.add_theme_color_override("font_color", COL_ACCENT)
		else:
			hl.text = ""

	# Sparkline
	var spark_var: Node = _stock_sparklines.get(sid)
	if spark_var:
		var hist: Array = MarketSim.get_price_history(sid)
		if hist.size() >= 2:
			spark_var.set_data(hist, s.get("change_pct", 0.0) >= 0)

	# 디버그 로그
	if DEBUG_PRICE_SYNC:
		var pct_str: String = UIUtil._fmt_change(s.get("change_pct", 0.0))
		print("[PRICE_SYNC] stock=%s row_price=%s detail_price=%s change=%s" % [sid, UIUtil._fmt_price(s["price"]), UIUtil._fmt_price(s["price"]), pct_str])


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
		_npc_container.add_child(UIUtil._spacer(8))

	# 라이벌 섹션
	_npc_container.add_child(_npc_section_label("라이벌"))
	for npc in NPCManager.get_npcs_by_category("rivals"):
		_npc_container.add_child(_create_npc_row(npc, "rival"))
	_npc_container.add_child(UIUtil._spacer(8))

	# 도움 NPC 섹션
	_npc_container.add_child(_npc_section_label("도움 NPC"))
	for npc in NPCManager.get_npcs_by_category("helpers"):
		_npc_container.add_child(_create_npc_row(npc, "helper"))
	_npc_container.add_child(UIUtil._spacer(8))

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
	panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 6))
	panel.custom_minimum_size = Vector2(0, 80)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# ── 상단: 아이콘 + 이름/역할 + 호감도 ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var npc_icon := _get_npc_icon(npc.get("id", ""))
	if npc_icon:
		hbox.add_child(_make_icon_rect(npc_icon, 56))

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

	# 호감도 라벨
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

	# ── 설명 ──
	var desc := Label.new()
	desc.text = "  " + npc.get("desc", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", COL_TEXT_DIM)
	vbox.add_child(desc)

	# ── 서비스 설명 ──
	var svc_desc: String = npc.get("service_desc", "")
	if svc_desc != "":
		var svc_label := Label.new()
		svc_label.text = "  >> " + svc_desc
		svc_label.add_theme_font_size_override("font_size", 11)
		svc_label.add_theme_color_override("font_color", COL_ACCENT)
		vbox.add_child(svc_label)

	# ── 결혼 대상: 호감도 게이지바 ──
	if type == "marriage" and not (NPCManager.get_spouse_id() == npc["id"]):
		var gauge_row := HBoxContainer.new()
		gauge_row.add_theme_constant_override("separation", 8)
		action_box_offset(gauge_row)

		var gauge_label := Label.new()
		gauge_label.text = "호감도"
		gauge_label.add_theme_font_size_override("font_size", 11)
		gauge_label.add_theme_color_override("font_color", COL_TEXT_DIM)
		gauge_row.add_child(gauge_label)

		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = aff
		bar.custom_minimum_size = Vector2(200, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		# 게이지 색상
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.18, 1)
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", style)
		var fill := StyleBoxFlat.new()
		if aff >= 80:
			fill.bg_color = COL_UP
		elif aff >= 50:
			fill.bg_color = COL_ACCENT
		else:
			fill.bg_color = COL_TEXT_DIM
		fill.corner_radius_top_left = 3
		fill.corner_radius_top_right = 3
		fill.corner_radius_bottom_left = 3
		fill.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("fill", fill)
		gauge_row.add_child(bar)

		var pct_label := Label.new()
		pct_label.text = "%d/100" % aff
		pct_label.add_theme_font_size_override("font_size", 11)
		pct_label.add_theme_color_override("font_color", COL_TEXT_DIM)
		pct_label.custom_minimum_size = Vector2(50, 0)
		gauge_row.add_child(pct_label)

		vbox.add_child(gauge_row)

	# ── 액션 버튼 행 ──
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	action_box_offset(action_row)

	match type:
		"rival":
			var plays_today: int = NPCManager.get_rival_plays_today(npc["id"])
			var max_plays: int = NPCManager.RIVAL_MAX_PLAYS_PER_DAY
			var remaining: int = max_plays - plays_today

			var btn := Button.new()
			btn.text = "대결하기" if remaining > 0 else "횟수초과"
			btn.custom_minimum_size = Vector2(80, 28)
			btn.add_theme_font_size_override("font_size", 12)
			btn.add_theme_color_override("font_color", COL_DOWN)
			btn.disabled = (remaining <= 0)
			btn.pressed.connect(_on_rival_challenge.bind(npc["id"]))
			action_row.add_child(btn)

			var remain_lbl := Label.new()
			remain_lbl.text = "%d/%d" % [remaining, max_plays]
			remain_lbl.add_theme_font_size_override("font_size", 11)
			remain_lbl.add_theme_color_override("font_color", COL_UP if remaining > 0 else COL_TEXT_DIM)
			action_row.add_child(remain_lbl)

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
				# 선물 버튼 (2단계)
				var gift1_btn := Button.new()
				gift1_btn.text = "선물 (100만)"
				gift1_btn.custom_minimum_size = Vector2(100, 28)
				gift1_btn.add_theme_font_size_override("font_size", 12)
				gift1_btn.add_theme_color_override("font_color", COL_ACCENT)
				gift1_btn.pressed.connect(_on_give_gift.bind(npc["id"], 1000000))
				action_row.add_child(gift1_btn)

				var gift2_btn := Button.new()
				gift2_btn.text = "선물 (500만)"
				gift2_btn.custom_minimum_size = Vector2(100, 28)
				gift2_btn.add_theme_font_size_override("font_size", 12)
				gift2_btn.add_theme_color_override("font_color", COL_ACCENT)
				gift2_btn.pressed.connect(_on_give_gift.bind(npc["id"], 5000000))
				action_row.add_child(gift2_btn)

				# 데이트 버튼
				var date_btn := Button.new()
				date_btn.text = "데이트"
				date_btn.custom_minimum_size = Vector2(70, 28)
				date_btn.add_theme_font_size_override("font_size", 12)
				date_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.8))
				date_btn.pressed.connect(_show_date_popup.bind(npc["id"]))
				action_row.add_child(date_btn)

				# 프로포즈 (100% 달성 시)
				if aff >= 100:
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
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
				child.add_theme_color_override("font_color", Color.WHITE)
			else:
				child.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
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
		panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 4))
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
			panel.add_theme_stylebox_override("panel", UIUtil._flat(Color(0.10, 0.15, 0.10, 1), 4))
		elif complete:
			panel.add_theme_stylebox_override("panel", UIUtil._flat(Color(0.12, 0.14, 0.10, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 4))
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
			btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_ACCENT, 4))
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.add_theme_stylebox_override("normal", UIUtil._flat(COL_PANEL, 4))
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
			panel.add_theme_stylebox_override("panel", UIUtil._flat(Color(0.12, 0.10, 0.05, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 4))
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
			panel.add_theme_stylebox_override("panel", UIUtil._flat(Color(0.10, 0.15, 0.10, 1), 4))
		else:
			panel.add_theme_stylebox_override("panel", UIUtil._flat(COL_PANEL, 4))
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
		"net_worth": return "순자산 %s" % UIUtil._fmt_won(float(trigger.get("value", 0)))
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

	# 동적 목표 (2~3줄 핵심)
	_add_dynamic_goals(_tutorial_container)


func _add_dynamic_goals(parent: Container) -> void:
	var networth: float = float(GameManager.player.get("net_worth", 0.0))
	var cash: float = float(GameManager.player.get("cash", 0))
	
	# 1. 다음 커리어 단계
	var career_map: Dictionary = {
		"신입사원": [0, "대리", 50000000],
		"대리": [50000000, "과장", 200000000],
		"과장": [200000000, "차장", 500000000],
		"차장": [500000000, "부장", 10000000000],
		"부장": [10000000000, "임원", 50000000000],
		"임원": [50000000000, "사장", 200000000000],
		"사장": [200000000000, "전설", 1000000000000],
	}
	var current_title: String = GameManager.player.get("title", "신입사원")
	if career_map.has(current_title):
		var info: Array = career_map[current_title]
		var next_title: String = info[1]
		var threshold: float = float(info[2])
		if networth < threshold:
			var need: float = threshold - networth
			var cl := Label.new()
			cl.text = "  >> %s 승진까지 %s" % [next_title, UIUtil._fmt_won(need)]
			cl.add_theme_font_size_override("font_size", 14)
			cl.add_theme_color_override("font_color", COL_ACCENT)
			parent.add_child(cl)
	
	# 2. 구매 가능한 사업 추천
	var bizs: Array = BusinessManager.get_all_defs()
	var owned: Dictionary = BusinessManager.get_owned()
	var best_name: String = ""
	var best_price: float = 0.0
	for b in bizs:
		var p: float = float(b.get("purchase_price", 0))
		if p <= cash and p > best_price and not owned.has(b.get("id", "")):
			best_name = b.get("name", "")
			best_price = p
	if best_name != "":
		var bl := Label.new()
		bl.text = "  >> 추천 사업: %s (%s)" % [best_name, UIUtil._fmt_won(best_price)]
		bl.add_theme_font_size_override("font_size", 14)
		bl.add_theme_color_override("font_color", COL_GOLD)
		parent.add_child(bl)


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
	# 라이벌별 미니게임 분기
	var npc := NPCManager.get_npc(npc_id)
	var game_type: String = npc.get("game_type", "dice")

	if game_type == "ladder":
		var game := LadderGame.new()
		game.npc_id = npc_id
		game.show_toast_callback = _show_toast
		game.refresh_npc_callback = _refresh_npc_view
		game.pixel_font = _pixel_font
		game.game_finished.connect(_on_minigame_finished)
		add_child(game)
		return
	if game_type == "blackjack":
		var game := BlackjackGame.new()
		game.npc_id = npc_id
		game.show_toast_callback = _show_toast
		game.refresh_npc_callback = _refresh_npc_view
		game.pixel_font = _pixel_font
		game.game_finished.connect(_on_minigame_finished)
		add_child(game)
		return
	if game_type == "dice":
		var game := DiceGame.new()
		game.npc_id = npc_id
		game.show_toast_callback = _show_toast
		game.refresh_npc_callback = _refresh_npc_view
		game.pixel_font = _pixel_font
		game.game_finished.connect(_on_minigame_finished)
		add_child(game)
		return

	# 기존 단순 베팅 방식 (기타)
	GameClockManager.pause_for_event()
	var bet: float = GameManager.get_cash() * 0.05
	if bet < 100000:
		bet = 100000
	var result := NPCManager.play_rival_game(npc_id, bet)
	if result.get("success"):
		var desc: String = result.get("desc", "")
		if result.get("won"):
			_show_toast(desc, COL_UP)
		elif result.get("tie"):
			_show_toast(desc, COL_TEXT_DIM)
		else:
			_show_toast(desc, COL_DOWN)
		_refresh_npc_view()
	else:
		_show_toast(result.get("reason", ""), COL_DOWN)
	GameClockManager.resume_from_event()

func _on_minigame_finished(_result: Dictionary) -> void:
	_refresh_cash_label()
	_refresh_passive_label()

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


## 데이트 팝업 — 활동 선택
var _date_popup: AcceptDialog = null

func _show_date_popup(npc_id: String) -> void:
	GameClockManager.pause_for_event()

	var check := NPCManager.can_date(npc_id)
	if not check.get("success"):
		_show_toast(check.get("reason", "데이트 불가"))
		GameClockManager.resume_from_event()
		return

	var npc := NPCManager.get_npc(npc_id)
	var base_cost: float = float(npc.get("date_cost", 5000000))

	if _date_popup:
		_date_popup.queue_free()

	_date_popup = AcceptDialog.new()
	_date_popup.title = "%s와(과) 데이트" % npc.get("name", "")
	_date_popup.get_ok_button().text = "닫기"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var info := Label.new()
	info.text = "%s와(과) 어떤 데이트를 할까?" % npc.get("name", "")
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", COL_TEXT_BRIGHT)
	vbox.add_child(info)

	# 활동별 버튼
	var activities := [
		{"id": "cafe", "name": "카페 데이트", "cost": base_cost * 0.5, "gain": "+3~5", "desc": "가벼운 커피 한잔. 부담 없는 만남."},
		{"id": "restaurant", "name": "고급 레스토랑", "cost": base_cost, "gain": "+6~9", "desc": "분위기 있는 저녁 식사."},
		{"id": "luxury", "name": "럭셔리 데이트", "cost": base_cost * 2.0, "gain": "+12~18", "desc": "최고급 코스. 감동 확정."},
	]

	for act in activities:
		var btn := Button.new()
		btn.text = "%s (%s) — 예상 호감도 %s" % [act["name"], UIUtil._fmt_won_short(act["cost"]), act["gain"]]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.8))
		btn.pressed.connect(_on_date_activity.bind(npc_id, act["id"]))
		vbox.add_child(btn)

		var act_desc := Label.new()
		act_desc.text = "  " + act["desc"]
		act_desc.add_theme_font_size_override("font_size", 11)
		act_desc.add_theme_color_override("font_color", COL_TEXT_DIM)
		vbox.add_child(act_desc)

	_date_popup.add_child(vbox)
	add_child(_date_popup)
	_date_popup.popup_centered(Vector2i(420, 380))

	# 닫기 시 이벤트 재개
	_date_popup.confirmed.connect(func():
		GameClockManager.resume_from_event()
	)
	# close 버튼 처리 (X)
	_date_popup.canceled.connect(func():
		GameClockManager.resume_from_event()
	)


func _on_date_activity(npc_id: String, activity: String) -> void:
	if _date_popup:
		_date_popup.hide()
		_date_popup.queue_free()
		_date_popup = null

	var result := NPCManager.go_on_date(npc_id, activity)
	if result.get("success"):
		_show_toast("%s (호감도 +%d → %d, 비용 %s)" % [
			result["desc"], result["gain"], result["affinity"], UIUtil._fmt_won_short(result["cost"])
		])
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
		_show_toast("세대교체! %d대 — 상속 %s" % [result["new_generation"], UIUtil._fmt_won(result["inherited_cash"])])
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
var _toast_tween: Tween = null

## 우선순위 토스트: high는 즉시 표시, normal은 교체, low는 무시 가능
func _show_toast_priority(msg: String, priority: String = "normal", color: Color = COL_TEXT_BRIGHT) -> void:
	match priority:
		"high":
			# high는 무조건 즉시 표시
			_show_toast(msg, color)
		"normal":
			# normal은 현재 표시 중이면 교체하지 않고 다음 틱에
			if not _toast_showing:
				_show_toast(msg, color)
			else:
				# 현재 토스트를 빠르게 끝내고 표시
				if _toast_tween and _toast_tween.is_valid():
					_toast_tween.kill()
				_show_toast(msg, color)
		"low":
			# low는 표시 중이 아닐 때만
			if not _toast_showing:
				_show_toast(msg, color)

func _show_toast(msg: String, color: Color = COL_TEXT_BRIGHT) -> void:
	# 기존 토스트가 표시 중이면 즉시 중단하고 새 메시지로 교체
	if _toast_showing and _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_showing = true
	_toast.text = msg
	_toast.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.position.y = 60
	_toast_tween = create_tween()
	# 표시 시간 단축 (1.5초 -> 1.0초)
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func():
		_toast.visible = false
		_toast_showing = false
	)


func _show_news_alert(title_text: String, stock_id: String) -> void:
	var msg := "[속보] %s" % title_text
	_show_toast(msg, COL_GOLD)
	# TODO: 추후 토스트 클릭 시 해당 종목으로 이동하도록 확장 가능


func UIUtil._cat_tag(c: String) -> String:
	match c:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return c


func UIUtil._cat_color(c: String) -> Color:
	match c:
		"korea": return Color(0.35, 0.60, 0.90, 1)
		"usa": return Color(0.75, 0.45, 0.85, 1)
		"coin": return COL_GOLD
		_: return COL_TEXT_DIM


func UIUtil._chg_color(p: float) -> Color:
	if p > 0.1: return COL_UP
	if p < -0.1: return COL_DOWN
	return COL_TEXT_DIM


func UIUtil._fmt_price(p: float) -> String:
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


func UIUtil._fmt_won(a: float) -> String:
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


func UIUtil._fmt_won_short(a: float) -> String:
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


func UIUtil._fmt_change(p: float) -> String:
	var sign := "+" if p >= 0 else ""
	return sign + "%.2f" % p + "%"



func UIUtil._spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func UIUtil._flat(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)  # 각진 픽셀 보더
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = COL_BORDER
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s

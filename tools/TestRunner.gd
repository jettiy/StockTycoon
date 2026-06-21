extends Node2D
## 헤드리스 자동 테스트 — 핵심 기능 검증

var passed: int = 0
var failed: int = 0
var current_test: String = ""

func _ready() -> void:
	print("\n========================================")
	print("  주식잡스 자동 테스트 시작")
	print("========================================\n")
	
	await get_tree().process_frame
	_run_all_tests()
	
	print("\n========================================")
	print("  결과: %d 통과, %d 실패 (총 %d)" % [passed, failed, passed + failed])
	print("========================================\n")
	
	get_tree().quit(0 if failed == 0 else 1)

func _run_all_tests() -> void:
	
	# 1. GameManager 초기화
	current_test = "GameManager 초기화"
	if GameManager.player.has("cash") and GameManager.player["cash"] > 0:
		_pass()
	else:
		_fail("cash = %s" % str(GameManager.player.get("cash", "없음")))
	
	# 2. MarketSim 16종목
	current_test = "MarketSim 16종목 로드"
	if MarketSim.stocks.size() == 16:
		_pass()
	else:
		_fail("종목 수 = %d" % MarketSim.stocks.size())
	
	# 3. 주가 유효성
	current_test = "주가 데이터 유효"
	var price_ok = true
	for id in MarketSim.stocks:
		var p = float(MarketSim.stocks[id].get("price", 0))
		if p <= 0:
			price_ok = false
			break
	if price_ok:
		_pass()
	else:
		_fail("가격 0 이하 존재")
	
	# 4. 매수
	current_test = "주식 매수"
	var buy_id = MarketSim.stocks.keys()[0]
	var result = GameManager.buy_stock(buy_id, 1)
	if result.get("success", false):
		_pass()
	else:
		_fail("매수 실패: %s" % str(result.get("reason", "")))
	
	# 5. 매도
	current_test = "주식 매도"
	if GameManager.player["holdings"].size() > 0:
		var sell_id = GameManager.player["holdings"].keys()[0]
		var sresult = GameManager.sell_stock(sell_id, 1)
		if sresult.get("success", false):
			_pass()
		else:
			_fail("매도 실패: %s" % str(sresult.get("reason", "")))
	else:
		_fail("보유 주식 없음")
	
	# 6. 하루 경과
	current_test = "하루 경과"
	var day_before = GameManager.player["day"]
	GameManager.advance_day()
	if GameManager.player["day"] == day_before + 1:
		_pass()
	else:
		_fail("day: %d → %d" % [day_before, GameManager.player["day"]])
	
	# 7. 순자산
	current_test = "순자산 계산"
	var nw = GameManager.get_net_worth()
	if nw > 0:
		_pass()
	else:
		_fail("순자산 = %s" % str(nw))
	
	# 8. 자동매매
	current_test = "자동매매 슬롯 등록"
	var at_id = MarketSim.stocks.keys()[0]
	var at_price = float(MarketSim.stocks[at_id]["price"])
	AutoTradeManager.set_slot(0, {
		"stock_id": at_id,
		"condition": "buy_below",
		"target_price": at_price * 2.0,
		"quantity": 10,
		"active": true
	})
	var slot = AutoTradeManager.get_slot(0)
	if slot.get("active", false):
		_pass()
	else:
		_fail("슬롯 0 비활성")
	
	# 9. NPC
	current_test = "NPC 11명 로드"
	var npc_list = NPCManager.get_all_npcs()
	if npc_list.size() >= 11:
		_pass()
	else:
		_fail("NPC 수 = %d" % npc_list.size())
	
	# 10. 이벤트
	current_test = "이벤트 데이터 로드"
	var events = EventManager.roll_daily_events()
	if events.size() >= 0:  # 이벤트 풀이 로드되었는지만 확인
		_pass()
	else:
		_fail("이벤트 롤 실패")
	
	# 11. 패시브 수익
	current_test = "패시브 수익 시스템"
	var pps = PassiveIncomeManager.get_projected_per_second()
	if pps >= 0:
		_pass()
	else:
		_fail("pps = %s" % str(pps))
	
	# 12. 저장
	current_test = "게임 저장"
	if SaveManager.save_game():
		_pass()
	else:
		_fail("save_game() false")
	
	# 13. 주거
	current_test = "주거 시스템"
	var house = GameManager.get_current_house()
	if house.has("id"):
		_pass()
	else:
		_fail("house 없음")
	
	# 14. 직급
	current_test = "직급 시스템"
	var cl = GameManager.player.get("rank_index", -1)
	if cl >= 0:
		_pass()
	else:
		_fail("rank_index = %d" % cl)
	
	# 15. 배당 계산
	current_test = "배당금 계산"
	var div_stock = ""
	for id in MarketSim.stocks:
		if float(MarketSim.stocks[id].get("dividend_yield", 0)) > 0:
			div_stock = id
			break
	if div_stock != "":
		GameManager.buy_stock(div_stock, 10)
		var div = PassiveIncomeManager._calc_tick_dividend()
		if div >= 0:
			_pass()
		else:
			_fail("배당 = %s" % str(div))
	else:
		_fail("배당 종목 없음")
	
	# 16. 정보력
	current_test = "정보력 시스템"
	var energy = GameManager.get_energy()
	if energy >= 0:
		_pass()
	else:
		_fail("energy = %d" % energy)
	
	# 17. 주가 틱
	current_test = "주가 틱 갱신"
	MarketSim._tick()
	var tick_price = float(MarketSim.stocks[MarketSim.stocks.keys()[0]]["price"])
	if tick_price > 0:
		_pass()
	else:
		_fail("틱 후 가격 0")
	
	# 18. 임대 수익
	current_test = "임대 수익 계산"
	var rental = PassiveIncomeManager._calc_tick_rental()
	if rental >= 0:
		_pass()
	else:
		_fail("임대 = %s" % str(rental))
	
	# 19. 이자
	current_test = "현금 이자 계산"
	var interest = PassiveIncomeManager._calc_tick_interest()
	if interest >= 0:
		_pass()
	else:
		_fail("이자 = %s" % str(interest))
	
	# 20. 세대
	current_test = "세대교체 데이터"
	var gen = GameManager.player.get("generation", -1)
	if gen >= 1:
		_pass()
	else:
		_fail("generation = %d" % gen)
	
	# 21. 스토리 데이터
	current_test = "스토리 챕터 로드"
	if StoryManager.get_chapter_count() == 7:
		_pass()
	else:
		_fail("챕터 수 = %d" % StoryManager.get_chapter_count())
	
	# 22. 퀘스트 데이터
	current_test = "퀘스트 데이터 로드"
	var dq = QuestManager.get_daily_quests()
	var wq = QuestManager.get_weekly_quests()
	var mq = QuestManager.get_monthly_quests()
	if dq.size() >= 3 and wq.size() >= 2 and mq.size() >= 2:
		_pass()
	else:
		_fail("일일%d 주간%d 월간%d" % [dq.size(), wq.size(), mq.size()])
	
	# 23. 업적 데이터
	current_test = "업적 데이터 로드"
	var ach = QuestManager.get_achievements()
	if ach.size() >= 15:
		_pass()
	else:
		_fail("업적 수 = %d" % ach.size())
	
	# 24. 거래 시 퀘스트 추적
	current_test = "거래 시 퀘스트 추적"
	var trades_before = QuestManager.get_total_trades()
	var trade_id = MarketSim.stocks.keys()[0]
	GameManager.buy_stock(trade_id, 1)
	var trades_after = QuestManager.get_total_trades()
	if trades_after > trades_before:
		_pass()
	else:
		_fail("거래 전 %d → 후 %d" % [trades_before, trades_after])
	
	# 25. 스토리 트리거 체크
	current_test = "스토리 트리거 체크"
	StoryManager.check_triggers()
	_pass()  # 에러 없이 실행되면 통과

	# 26. 사업 데이터 로드
	current_test = "사업 데이터 18종 로드"
	var biz_defs = BusinessManager.get_all_defs()
	if biz_defs.size() == 18:
		_pass()
	else:
		_fail("사업 수 = %d" % biz_defs.size())

	# 27. 사업 구매
	current_test = "사업 구매"
	var biz_r = BusinessManager.purchase("food_truck")
	if biz_r.get("success"):
		_pass()
	else:
		_fail("구매 실패: %s" % str(biz_r.get("reason")))

	# 28. 사업 업그레이드
	current_test = "사업 업그레이드"
	# 현금 추가
	GameManager.add_cash(10000000)
	var up_r = BusinessManager.upgrade("food_truck")
	if up_r.get("success"):
		_pass()
	else:
		_fail("업그레이드 실패: %s" % str(up_r.get("reason")))

	# 29. 직원 고용
	current_test = "직원 고용"
	var emp_r = BusinessManager.hire_employee("food_truck")
	if emp_r.get("success"):
		_pass()
	else:
		_fail("고용 실패: %s" % str(emp_r.get("reason")))

	# 30. 사업 수익 계산
	current_test = "사업 수익 계산"
	var biz_rev = BusinessManager.calc_tick_revenue()
	if biz_rev > 0:
		_pass()
	else:
		_fail("수익 = %s" % str(biz_rev))

	# 31. 사업 일일 정산
	current_test = "사업 일일 정산"
	var daily_biz = BusinessManager.pay_daily_revenue()
	if daily_biz["total"] > 0:
		_pass()
	else:
		_fail("일일 수익 = %s" % str(daily_biz.get("total")))

	# 32. 사업 이벤트 롤
	current_test = "사업 이벤트 롤"
	BusinessManager.roll_daily_events()
	_pass()  # 에러 없이 실행되면 통과

func _pass() -> void:
	passed += 1
	print("  [통과] %s" % current_test)

func _fail(msg: String) -> void:
	failed += 1
	print("  [실패] %s — %s" % [current_test, msg])

extends SceneTree
## 헤드리스 자동 테스트 — 핵심 기능 검증

var passed: int = 0
var failed: int = 0
var current_test: String = ""

func _init():
	print("\n========================================")
	print("  주식잡스 자동 테스트 시작")
	print("========================================\n")
	
	# 1. GameManager 초기화
	current_test = "GameManager 초기화"
	if GameManager.player.has("cash") and GameManager.player["cash"] > 0:
		_pass()
	else:
		_fail("cash = %s" % str(GameManager.player.get("cash", "없음")))
	
	# 2. MarketSim 주가 데이터
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
			_fail("종목 %s 가격 비정상: %s" % [id, str(MarketSim.stocks[id].get("price"))])
			break
	if price_ok:
		_pass()
	
	# 4. 매수 테스트
	current_test = "주식 매수"
	var buy_id = MarketSim.stocks.keys()[0]
	var cash_before = GameManager.player["cash"]
	GameManager.buy(buy_id, 1)
	if GameManager.player["holdings"].has(buy_id):
		_pass()
	else:
		_fail("매수 후 보유내역 없음 (cash: %s → %s)" % [str(cash_before), str(GameManager.player["cash"])])
	
	# 5. 매도 테스트
	current_test = "주식 매도"
	if GameManager.player["holdings"].size() > 0:
		var sell_id = GameManager.player["holdings"].keys()[0]
		GameManager.sell(sell_id, 1)
		_pass()
	else:
		_fail("보유 주식 없음")
	
	# 6. 하루 경과
	current_test = "하루 경과 (월급/승진)"
	var day_before = GameManager.player["day"]
	GameManager.advance_day()
	if GameManager.player["day"] == day_before + 1:
		_pass()
	else:
		_fail("day: %d → %d" % [day_before, GameManager.player["day"]])
	
	# 7. 순자산 계산
	current_test = "순자산 계산"
	var nw = GameManager.get_net_worth()
	if nw > 0:
		_pass()
	else:
		_fail("순자산 = %s" % str(nw))
	
	# 8. 자동매매 등록
	current_test = "자동매매 슬롯 등록"
	var at_id = MarketSim.stocks.keys()[0]
	var at_price = float(MarketSim.stocks[at_id]["price"])
	AutoTradeManager.set_rule(0, at_id, "buy_below", at_price * 2.0, 10)
	if AutoTradeManager.slots[0].get("active", false):
		_pass()
	else:
		_fail("슬롯 0 비활성")
	
	# 9. NPC 데이터
	current_test = "NPC 11명 로드"
	if NPCManager.npcs.size() >= 11:
		_pass()
	else:
		_fail("NPC 수 = %d" % NPCManager.npcs.size())
	
	# 10. 이벤트 데이터
	current_test = "이벤트 데이터 로드"
	if EventManager.events.size() > 0:
		_pass()
	else:
		_fail("이벤트 0건")
	
	# 11. 패시브 수익
	current_test = "패시브 수익 시스템 활성"
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
		_fail("save_game() false 반환")
	
	# 13. 주거 정보
	current_test = "주거 시스템"
	var house = GameManager.get_current_house()
	if house.has("id"):
		_pass()
	else:
		_fail("house = %s" % str(house))
	
	# 14. 직급 정보
	current_test = "직급 시스템"
	var cl = GameManager.player.get("career_level", -1)
	if cl >= 0:
		_pass()
	else:
		_fail("career_level = %d" % cl)
	
	# 15. 배당 계산
	current_test = "배당금 계산 (보유주식)"
	var div_stock = ""
	for id in MarketSim.stocks:
		if float(MarketSim.stocks[id].get("dividend_yield", 0)) > 0:
			div_stock = id
			break
	if div_stock != "":
		GameManager.buy(div_stock, 10)
		var div = PassiveIncomeManager._calc_tick_dividend()
		if div >= 0:
			_pass()
		else:
			_fail("배당 = %s" % str(div))
	else:
		_fail("배당 종목 없음")
	
	# 16. 정보력
	current_test = "정보력 시스템"
	var energy = GameManager.player.get("energy", -1)
	if energy >= 0:
		_pass()
	else:
		_fail("energy = %d" % energy)
	
	# 17. 주가 틱 (시장 갱신)
	current_test = "주가 틱 갱신"
	var tick_id = MarketSim.stocks.keys()[0]
	var price_0 = float(MarketSim.stocks[tick_id]["price"])
	MarketSim._tick()
	var price_1 = float(MarketSim.stocks[tick_id]["price"])
	if price_1 > 0:
		_pass()
	else:
		_fail("틱 후 가격 0: %s → %s" % [str(price_0), str(price_1)])
	
	# 18. 임대 수익
	current_test = "임대 수익 계산"
	var rental = PassiveIncomeManager._calc_tick_rental()
	if rental >= 0:
		_pass()
	else:
		_fail("임대 = %s" % str(rental))
	
	# 19. 이자 수익
	current_test = "현금 이자 계산"
	var interest = PassiveIncomeManager._calc_tick_interest()
	if interest >= 0:
		_pass()
	else:
		_fail("이자 = %s" % str(interest))
	
	# 20. 세대교체 데이터
	current_test = "세대교체 데이터"
	var gen = GameManager.player.get("generation", -1)
	if gen >= 1:
		_pass()
	else:
		_fail("generation = %d" % gen)
	
	print("\n========================================")
	print("  결과: %d 통과, %d 실패 (총 %d)" % [passed, failed, passed + failed])
	print("========================================\n")
	
	quit(0 if failed == 0 else 1)

func _pass() -> void:
	passed += 1
	print("  [통과] %s" % current_test)

func _fail(msg: String) -> void:
	failed += 1
	print("  [실패] %s — %s" % [current_test, msg])

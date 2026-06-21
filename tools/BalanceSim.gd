extends Node2D
## 장기 밸런스 시뮬레이션 — 365일 진행하며 일지 기록
## 목적: 초반/중반/후반 자산 성장 곡선이 적절한지 검증

var log_lines: Array = []
var start_cash: float = 0.0

func _ready() -> void:
	print("\n========================================")
	print("  주식잡스 장기 밸런스 시뮬레이션")
	print("  (365일 = 약 50분 실시간)")
	print("========================================\n")
	
	await get_tree().process_frame
	
	start_cash = GameManager.player["cash"]
	
	_log("=== 시작 상태 ===")
	_log("현금: %s원" % _fmt(start_cash))
	_log("순자산: %s원" % _fmt(GameManager.get_net_worth()))
	_log("직급: %s" % GameManager.get_rank_name())
	_log("")
	
	# 시뮬레이션 전략: 3가지 플레이 스타일
	# A) 보수적 — 배당주 위주 매수 후 방치
	# B) 공격적 — 코인/성장주 위주
	# C) 균형 — 섞어서
	
	_run_balanced_strategy()
	
	# 결과 파일로 저장
	_save_report()

func _run_balanced_strategy() -> void:
	_log("=== 균형 전략 시뮬레이션 시작 ===")
	_log("- 7일마다 월금으로 배당주 매수")
	_log("- 나머지는 자동매매 + 패시브 수익")
	_log("")
	
	var checkpoints = [7, 30, 90, 180, 365]
	var cp_idx = 0
	
	# 초기 매수: 보유 현금의 50%를 배당주에 분산 매수
	var stocks = MarketSim.get_all_stocks()
	var div_stocks = []
	for s in stocks:
		if float(s.get("dividend_yield", 0)) > 0:
			div_stocks.append(s)
	
	if div_stocks.size() > 0:
		var invest_amount = start_cash * 0.5
		var per_stock = invest_amount / div_stocks.size()
		for s in div_stocks:
			var price = float(s["price"])
			var qty = int(per_stock / price)
			if qty > 0:
				var r = GameManager.buy_stock(s["id"], qty)
				if r.get("success"):
					_log("초기 매수: %s x%d (%s원)" % [s["name"], qty, _fmt(price * qty)])
	
	_log("")
	_log("초기 매수 후 현금: %s원" % _fmt(GameManager.get_cash()))
	_log("")
	
	# 주거 업그레이드 마일스톤
	var housing_milestones = {50: "oneroom", 180: "tworoom", 365: "apartment"}
	
	for day in range(1, 366):
		# 시장 틱 (여러 틱 = 하루)
		for _i in range(10):
			MarketSim._tick()
		
		# 주거 업그레이드
		if housing_milestones.has(day):
			var target_house = housing_milestones[day]
			var r = GameManager.buy_house(target_house)
			if r.get("success"):
				_log("Day %d: 주거 업그레이드 → %s" % [day, target_house])
		
		# 하루 경과 (월급, 승진, 배당, 임대, 이자)
		GameManager.advance_day()
		
		# 7일마다: 월금으로 배당주 추가 매수 + 수익 실현
		if day % 7 == 0:
			# 수익 실현: 30%+ 수익 종목 절반 매도
			for sid in GameManager.player["holdings"].keys():
				var h = GameManager.player["holdings"][sid]
				var s = MarketSim.get_stock(sid)
				if s.is_empty():
					continue
				var avg_cost = float(h.get("avg_cost", 0))
				var cur_price = float(s["price"])
				if avg_cost > 0 and cur_price > avg_cost * 1.3:
					var sell_qty = int(int(h["quantity"]) / 2)
					if sell_qty > 0:
						GameManager.sell_stock(sid, sell_qty)
			
			# 월금으로 배당주 매수
			var cash = GameManager.get_cash()
			if cash > 100000 and div_stocks.size() > 0:
				var pick = div_stocks[day % div_stocks.size()]
				var price = float(pick["price"])
				var qty = int(cash * 0.6 / price)
				if qty > 0:
					GameManager.buy_stock(pick["id"], qty)
		
		# 체크포인트 기록
		if cp_idx < checkpoints.size() and day == checkpoints[cp_idx]:
			_log("--- Day %d 체크포인트 ---" % day)
			_log("  현금: %s원" % _fmt(GameManager.get_cash()))
			_log("  순자산: %s원" % _fmt(GameManager.get_net_worth()))
			_log("  보유 종목: %d개" % GameManager.player["holdings"].size())
			_log("  직급: %s" % GameManager.get_rank_name())
			
			# 포트폴리오 가치
			var port_val = 0.0
			for sid in GameManager.player["holdings"]:
				var h = GameManager.player["holdings"][sid]
				var s = MarketSim.get_stock(sid)
				if not s.is_empty():
					port_val += float(s["price"]) * int(h["quantity"])
			_log("  주식 가치: %s원" % _fmt(port_val))
			
			# 패시브 수익
			var pps = PassiveIncomeManager.get_projected_per_second()
			_log("  패시브/초: %s원" % _fmt(pps))
			
			# 누적 통계
			_log("  누적 배당: %s원" % _fmt(PassiveIncomeManager.get_total_dividends()))
			_log("  누적 임대: %s원" % _fmt(PassiveIncomeManager.get_total_rental()))
			_log("  누적 이자: %s원" % _fmt(PassiveIncomeManager.get_total_interest()))
			
			# 성장률
			var growth = (GameManager.get_net_worth() / start_cash - 1.0) * 100.0
			_log("  시작 대비 성장: %s%%" % _fmt(growth))
			_log("")
			cp_idx += 1
	
	# 최종 결과
	_log("=== 최종 결과 (365일) ===")
	_log("시작 순자산: %s원" % _fmt(start_cash))
	_log("최종 순자산: %s원" % _fmt(GameManager.get_net_worth()))
	var total_growth = (GameManager.get_net_worth() / start_cash - 1.0) * 100.0
	_log("총 성장률: %s%%" % _fmt(total_growth))
	_log("총 누적 배당: %s원" % _fmt(PassiveIncomeManager.get_total_dividends()))
	_log("총 누적 임대: %s원" % _fmt(PassiveIncomeManager.get_total_rental()))
	_log("총 누적 이자: %s원" % _fmt(PassiveIncomeManager.get_total_interest()))
	_log("최종 직급: %s" % GameManager.get_rank_name())

func _log(msg: String) -> void:
	log_lines.append(msg)
	print(msg)

func _fmt(amount: float) -> String:
	var a = int(amount)
	if abs(a) >= 100000000:
		return "%.2f억" % (amount / 100000000.0)
	elif abs(a) >= 10000:
		return "%.1f만" % (amount / 10000.0)
	else:
		return "%d" % a

func _save_report() -> void:
	var text = "\n".join(log_lines)
	var file = FileAccess.open("user://balance_sim_report.txt", FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
		print("\n[보고서 저장됨: user://balance_sim_report.txt]")
	
	# 프로젝트 폴더에도 저장
	var file2 = FileAccess.open("res://balance_sim_report.txt", FileAccess.WRITE)
	if file2:
		file2.store_string(text)
		file2.close()
		print("[보고서 저장됨: res://balance_sim_report.txt]")
	
	get_tree().quit(0)

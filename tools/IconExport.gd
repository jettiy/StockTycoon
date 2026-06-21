extends Node2D
## 도트 아트 생성 테스트 — PNG로 내보내서 시각 확인

const IconGen = preload("res://scripts/IconGenerator.gd")

func _ready() -> void:
	await get_tree().process_frame
	
	var gen = IconGen.new()
	var export_dir = "res://tools/icon_export/"
	DirAccess.make_dir_recursive_absolute(export_dir)
	
	print("\n=== 도트 아트 PNG 내보내기 ===\n")
	
	# 1. 종목 로고 16개
	var stock_ids = [
		"samsung", "skhynix", "celltrion", "kakaobank", "baemin",
		"apple", "tesla", "nvidia", "microsoft", "meta", "amazon", "google",
		"bitcoin", "ethereum", "dogecoin", "solana"
	]
	for sid in stock_ids:
		var tex = gen.make_stock_logo(sid, 64)
		var img = tex.get_image()
		img.save_png(export_dir + "stock_" + sid + ".png")
		print("  종목 로고: %s.png" % sid)
	
	# 2. 주거 아이콘 7개
	var house_ids = ["gosiwon", "wolset", "oneroom", "tworoom", "apartment", "penthouse", "island"]
	for hid in house_ids:
		var tex = gen.make_house_icon(hid, 64)
		var img = tex.get_image()
		img.save_png(export_dir + "house_" + hid + ".png")
		print("  주거 아이콘: %s.png" % hid)
	
	# 3. 차량 아이콘 7개
	var vehicle_ids = ["bicycle", "usedcar", "compact", "sedan", "sportscar", "supercar", "helicopter"]
	for vid in vehicle_ids:
		var tex = gen.make_vehicle_icon(vid, 64)
		var img = tex.get_image()
		img.save_png(export_dir + "vehicle_" + vid + ".png")
		print("  차량 아이콘: %s.png" % vid)
	
	# 4. UI 아이콘
	var arrow_up = gen.make_arrow_icon(true, 32)
	arrow_up.get_image().save_png(export_dir + "arrow_up.png")
	var arrow_dn = gen.make_arrow_icon(false, 32)
	arrow_dn.get_image().save_png(export_dir + "arrow_down.png")
	var coin = gen.make_coin_icon(32)
	coin.get_image().save_png(export_dir + "coin.png")
	print("  UI 아이콘: arrow_up, arrow_down, coin")
	
	# 5. 캐릭터 초상화
	var portrait = gen.make_character_portrait(1, 64)
	portrait.get_image().save_png(export_dir + "portrait.png")
	print("  캐릭터 초상화: portrait.png")
	
	print("\n총 %d개 PNG 내보냄" % (stock_ids.size() + house_ids.size() + vehicle_ids.size() + 3 + 1))
	print("경로: %s" % export_dir)
	
	get_tree().quit(0)

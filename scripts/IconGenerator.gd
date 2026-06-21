extends Node
## IconGenerator — 도트 아트 스타일 아이콘을 절차적으로 생성

# 카테고리별 색상 조합
const PALETTE_KOREA := [Color(0.15, 0.45, 0.90), Color(0.30, 0.60, 1.0), Color(0.10, 0.30, 0.70)]
const PALETTE_USA := [Color(0.55, 0.30, 0.85), Color(0.70, 0.45, 0.95), Color(0.40, 0.20, 0.70)]
const PALETTE_COIN := [Color(0.85, 0.70, 0.30), Color(1.0, 0.85, 0.40), Color(0.70, 0.55, 0.20)]
const PALETTE_BG := Color(0.094, 0.098, 0.110, 1)


## 종목 카테고리 아이콘 (32x32 도트 아트)
func make_category_icon(category: String, size: int = 32) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE_BG)

	var palette: Array = PALETTE_KOREA
	match category:
		"korea": palette = PALETTE_KOREA
		"usa": palette = PALETTE_USA
		"coin": palette = PALETTE_COIN

	var pixels := _get_category_pattern(category, size)

	for y in range(size):
		for x in range(size):
			var idx: int = pixels[y * size + x]
			if idx > 0:
				img.set_pixel(x, y, palette[idx - 1])

	return ImageTexture.create_from_image(img)


## 카테고리별 도트 패턴 (16x16을 size에 맞게 확장)
func _get_category_pattern(category: String, size: int) -> PackedByteArray:
	# 16x16 기본 패턴
	var pattern16: PackedByteArray = PackedByteArray()
	pattern16.resize(16 * 16)
	pattern16.fill(0)

	match category:
		"korea":
			# 태극 워닝 패턴 (원형)
			_draw_circle_pattern(pattern16, 8, 8, 6, 1)
			_draw_circle_pattern(pattern16, 8, 8, 3, 2)
		"usa":
			# 별 패턴
			_draw_star_pattern(pattern16, 8, 8, 2)
		"coin":
			# 코인 패턴 ($)
			_draw_dollar_pattern(pattern16)

	# size에 맞게 확장
	var result := PackedByteArray()
	result.resize(size * size)
	result.fill(0)
	var scale_factor := size / 16
	for y in range(size):
		for x in range(size):
			var sx: int = x / scale_factor
			var sy: int = y / scale_factor
			if sx < 16 and sy < 16:
				result[y * size + x] = pattern16[sy * 16 + sx]

	return result


func _draw_circle_pattern(buf: PackedByteArray, cx: int, cy: int, radius: int, value: int) -> void:
	for y in range(16):
		for x in range(16):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= radius * radius:
				buf[y * 16 + x] = value


func _draw_star_pattern(buf: PackedByteArray, cx: int, cy: int, value: int) -> void:
	# 십자가 형태 별
	for i in range(-5, 6):
		var idx_x := cx + i
		var idx_y := cy + i
		if idx_x >= 0 and idx_x < 16:
			buf[cy * 16 + idx_x] = value
		if idx_y >= 0 and idx_y < 16:
			buf[idx_y * 16 + cx] = value
	# 중앙 강조
	_draw_circle_pattern(buf, cx, cy, 2, value)


func _draw_dollar_pattern(buf: PackedByteArray) -> void:
	# $ 모양
	var s_shape := [
		[0,0,1,1,1,1,0,0],
		[0,1,1,0,0,0,0,0],
		[0,1,1,0,0,0,0,0],
		[0,0,1,1,1,1,0,0],
		[0,0,0,0,0,1,1,0],
		[0,0,0,0,0,1,1,0],
		[0,1,1,1,1,0,0,0],
	]
	var offset_x := 5
	var offset_y := 5
	for y in range(s_shape.size()):
		for x in range(s_shape[y].size()):
			if s_shape[y][x] == 1:
				buf[(offset_y + y) * 16 + (offset_x + x)] = 2


## NPC 아바타 생성 (색상 원 + 이니셜)
func make_npc_avatar(color_hex: String, size: int = 48) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var color := Color.from_string(color_hex, Color.WHITE)
	var radius := size / 2 - 2
	var cx := size / 2
	var cy := size / 2

	for y in range(size):
		for x in range(size):
			var dx := x - cx
			var dy := y - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius:
				# 외곽선 어둡게
				if dist > radius - 2:
					img.set_pixel(x, y, color.darkened(0.4))
				else:
					img.set_pixel(x, y, color)
			elif dist <= radius + 1:
				# 안티앨리어싱
				var alpha := clampf(radius + 1 - dist, 0.0, 1.0)
				var c := color
				c.a = alpha
				img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


## 캐릭터 초상화 (간단한 도트 인물)
func make_character_portrait(generation: int = 1, size: int = 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bg_color := Color(0.12, 0.10, 0.15, 1)
	img.fill(bg_color)

	# 피부색
	var skin := Color(0.90, 0.75, 0.60)
	# 머리카락
	var hair := Color(0.15, 0.10, 0.08)
	# 셔츠
	var shirt := Color(0.20, 0.30, 0.50) if generation % 2 == 1 else Color(0.50, 0.20, 0.30)

	# 머리 (위쪽 원)
	_fill_rect(img, 22, 8, 20, 18, hair)
	# 얼굴
	_fill_rect(img, 24, 16, 16, 16, skin)
	# 눈
	_fill_rect(img, 28, 22, 3, 3, Color(0.05, 0.05, 0.05))
	_fill_rect(img, 34, 22, 3, 3, Color(0.05, 0.05, 0.05))
	# 입
	_fill_rect(img, 30, 28, 5, 2, Color(0.60, 0.30, 0.30))
	# 몸 (셔츠)
	_fill_rect(img, 18, 36, 28, 28, shirt)

	return ImageTexture.create_from_image(img)


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)


# ═══════════════════════════════════════════════════
# 확장: 종목별 고유 로고 + 주거/차량 아이콘 + UI 아이콘
# ═══════════════════════════════════════════════════

## 종목별 고유 로고 (32x32)
func make_stock_logo(stock_id: String, size: int = 32) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE_BG)

	var pattern := _get_stock_pattern(stock_id)
	var palette := _get_stock_palette(stock_id)
	var grid_size := 16
	var scale := size / grid_size

	for y in range(grid_size):
		for x in range(grid_size):
			var idx: int = pattern[y * grid_size + x]
			if idx > 0 and idx <= palette.size():
				var c: Color = palette[idx - 1]
				for sy in range(scale):
					for sx in range(scale):
						var px: int = x * scale + sx
						var py: int = y * scale + sy
						if px < size and py < size:
							img.set_pixel(px, py, c)

	return ImageTexture.create_from_image(img)

## 종목별 색상 팔레트
func _get_stock_palette(stock_id: String) -> Array:
	match stock_id:
		"samsung": return [Color(0.20, 0.40, 0.90), Color(0.40, 0.60, 1.0), Color(0.15, 0.30, 0.70)]
		"skhynix": return [Color(0.90, 0.20, 0.20), Color(1.0, 0.40, 0.40), Color(0.70, 0.15, 0.15)]
		"celltrion": return [Color(0.20, 0.80, 0.40), Color(0.40, 1.0, 0.60), Color(0.15, 0.60, 0.30)]
		"alteogen": return [Color(0.20, 0.70, 0.80), Color(0.40, 0.85, 0.95), Color(0.15, 0.50, 0.65)]
		"ecopro": return [Color(0.20, 0.60, 0.30), Color(0.40, 0.80, 0.40), Color(0.15, 0.45, 0.25)]
		"apple": return [Color(0.90, 0.90, 0.92), Color(0.70, 0.70, 0.72), Color(0.50, 0.50, 0.52)]
		"tesla": return[Color(0.90, 0.30, 0.30), Color(1.0, 0.50, 0.50), Color(0.70, 0.20, 0.20)]
		"nvidia": return [Color(0.30, 0.90, 0.30), Color(0.50, 1.0, 0.50), Color(0.20, 0.70, 0.20)]
		"microsoft": return [Color(0.20, 0.50, 0.90), Color(0.40, 0.70, 1.0), Color(0.15, 0.40, 0.70)]
		"meta": return [Color(0.30, 0.50, 0.90), Color(0.50, 0.70, 1.0), Color(0.20, 0.40, 0.70)]
		"amazon": return [Color(0.90, 0.70, 0.30), Color(1.0, 0.85, 0.50), Color(0.70, 0.55, 0.20)]
		"google": return [Color(0.90, 0.30, 0.30), Color(0.30, 0.70, 0.90), Color(0.30, 0.80, 0.30)]
		"bitcoin": return [Color(0.90, 0.70, 0.20), Color(1.0, 0.85, 0.30), Color(0.70, 0.55, 0.15)]
		"ethereum": return [Color(0.60, 0.60, 0.70), Color(0.80, 0.80, 0.90), Color(0.40, 0.40, 0.50)]
		"dogecoin": return [Color(0.90, 0.80, 0.30), Color(1.0, 0.90, 0.50), Color(0.70, 0.60, 0.20)]
		"solana": return [Color(0.30, 0.50, 0.90), Color(0.90, 0.30, 0.50), Color(0.50, 0.70, 1.0)]
		_: return [Color(0.50, 0.50, 0.55), Color(0.70, 0.70, 0.75), Color(0.40, 0.40, 0.45)]

## 종목별 도트 패턴 (16x16)
func _get_stock_pattern(stock_id: String) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(16 * 16)
	buf.fill(0)

	match stock_id:
		# 블루칩 — 네모 로고
		"samsung", "apple", "microsoft":
			_fill_buf_rect(buf, 3, 3, 10, 10, 1)
			_fill_buf_rect(buf, 5, 5, 6, 6, 2)
		# 반도체 — 칩 패턴
		"skhynix", "nvidia":
			_fill_buf_rect(buf, 2, 2, 12, 12, 1)
			_fill_buf_rect(buf, 4, 4, 8, 8, 2)
			# 핀
			_fill_buf_rect(buf, 1, 5, 1, 2, 2)
			_fill_buf_rect(buf, 1, 9, 1, 2, 2)
			_fill_buf_rect(buf, 14, 5, 1, 2, 2)
			_fill_buf_rect(buf, 14, 9, 1, 2, 2)
		# 제약 — 십자
		"celltrion":
			_fill_buf_rect(buf, 6, 2, 4, 12, 1)
			_fill_buf_rect(buf, 2, 6, 12, 4, 1)
			_fill_buf_rect(buf, 7, 3, 2, 10, 2)
			_fill_buf_rect(buf, 3, 7, 10, 2, 2)
		# 금융 — 동전
		"alteogen", "alteogen":
			_draw_buf_circle(buf, 8, 8, 6, 1)
			_draw_buf_circle(buf, 8, 8, 4, 2)
		# 배달 — 봉투
		"ecopro", "amazon":
			_fill_buf_rect(buf, 3, 4, 10, 8, 1)
			_fill_buf_rect(buf, 5, 6, 6, 4, 2)
		# 자동차 — 차
		"tesla":
			_fill_buf_rect(buf, 2, 6, 12, 4, 1)  # 차체
			_fill_buf_rect(buf, 4, 4, 8, 2, 1)  # 지붕
			_fill_buf_rect(buf, 3, 10, 3, 2, 2)  # 바퀴
			_fill_buf_rect(buf, 10, 10, 3, 2, 2)
		# 소셜 — 사람
		"meta", "google":
			_draw_buf_circle(buf, 8, 5, 3, 1)  # 머리
			_fill_buf_rect(buf, 4, 9, 8, 5, 1)  # 몸
			_fill_buf_rect(buf, 6, 11, 4, 3, 2)
		# 코인 — 코인
		"bitcoin":
			_draw_buf_circle(buf, 8, 8, 6, 1)
			_draw_buf_circle(buf, 8, 8, 4, 2)
			# B 글자
			_fill_buf_rect(buf, 6, 5, 1, 6, 3)
			_fill_buf_rect(buf, 6, 5, 3, 1, 3)
			_fill_buf_rect(buf, 6, 8, 3, 1, 3)
			_fill_buf_rect(buf, 6, 10, 3, 1, 3)
		"ethereum":
			# 다이아몬드
			for i in range(6):
				var w := 6 - absi(i - 3) * 2
				_fill_buf_rect(buf, 8 - w/2, 2 + i*2, w, 1, 1)
		"dogecoin":
			_draw_buf_circle(buf, 8, 8, 6, 1)
			_fill_buf_rect(buf, 6, 6, 4, 4, 2)  # D
		"solana":
			# 평행선
			_fill_buf_rect(buf, 3, 4, 10, 2, 1)
			_fill_buf_rect(buf, 3, 7, 10, 2, 2)
			_fill_buf_rect(buf, 3, 10, 10, 2, 3)
		_:
			_draw_buf_circle(buf, 8, 8, 5, 1)

	return buf

## 주거 아이콘 (단계별로 점점 화려하게)
func make_house_icon(house_id: String, size: int = 48) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var wall := Color(0.55, 0.45, 0.35)
	var roof := Color(0.35, 0.25, 0.20)
	var window := Color(0.40, 0.60, 0.80)
	var door := Color(0.30, 0.20, 0.15)

	match house_id:
		"gosiwon":
			# 작은 네모
			_fill_rect(img, 12, 20, 24, 24, wall)
			_fill_rect(img, 20, 32, 8, 12, door)
		"wolset":
			_fill_rect(img, 10, 18, 28, 28, wall)
			_fill_rect(img, 8, 14, 32, 6, roof)
			_fill_rect(img, 22, 32, 8, 14, door)
		"oneroom":
			# 지붕 + 벽 + 창문
			var pts := [Vector2(4, 20), Vector2(24, 6), Vector2(44, 20)]
			_fill_triangle(img, pts, roof)
			_fill_rect(img, 8, 20, 32, 24, wall)
			_fill_rect(img, 14, 26, 8, 8, window)
			_fill_rect(img, 28, 26, 8, 8, window)
			_fill_rect(img, 20, 36, 8, 8, door)
		"tworoom":
			_fill_triangle(img, [Vector2(2, 22), Vector2(24, 6), Vector2(46, 22)], roof)
			_fill_rect(img, 6, 22, 36, 22, wall)
			_fill_rect(img, 12, 28, 6, 6, window)
			_fill_rect(img, 22, 28, 6, 6, window)
			_fill_rect(img, 32, 28, 6, 6, window)
			_fill_rect(img, 20, 38, 8, 8, door)
		"apartment":
			# 고층 아파트
			_fill_rect(img, 10, 4, 28, 40, wall)
			# 창문들
			for row in range(4):
				for col in range(3):
					_fill_rect(img, 13 + col * 8, 8 + row * 9, 5, 5, window)
			_fill_rect(img, 20, 36, 8, 8, door)
		"penthouse":
			# 펜트하우스 — 화려함
			_fill_rect(img, 6, 10, 36, 36, Color(0.25, 0.25, 0.30))
			# 꼭대기
			_fill_triangle(img, [Vector2(2, 14), Vector2(24, 2), Vector2(46, 14)], Color(0.15, 0.15, 0.20))
			# 금빛 창문
			var gold := Color(0.90, 0.75, 0.30)
			for row in range(3):
				for col in range(4):
					_fill_rect(img, 10 + col * 7, 18 + row * 8, 4, 5, gold)
			_fill_rect(img, 20, 38, 8, 8, Color(0.50, 0.40, 0.20))
		"island":
			# 섬 — 최고급
			_fill_rect(img, 0, 30, 48, 18, Color(0.20, 0.40, 0.60))  # 바다
			_fill_rect(img, 8, 24, 32, 8, Color(0.60, 0.55, 0.40))  # 모래
			# 야자수
			_fill_rect(img, 22, 10, 4, 16, Color(0.30, 0.20, 0.10))
			_fill_rect(img, 16, 6, 16, 6, Color(0.20, 0.50, 0.20))
			# 별
			_fill_rect(img, 6, 4, 2, 2, Color(1.0, 0.90, 0.40))
			_fill_rect(img, 38, 8, 2, 2, Color(1.0, 0.90, 0.40))

	return ImageTexture.create_from_image(img)

## 차량 아이콘 (단계별)
func make_vehicle_icon(vehicle_id: String, size: int = 48) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body := Color(0.70, 0.70, 0.75)
	var wheel := Color(0.15, 0.15, 0.15)
	var glass := Color(0.30, 0.50, 0.70)

	match vehicle_id:
		"bicycle":
			_draw_img_circle(img, 12, 32, 6, wheel)
			_draw_img_circle(img, 36, 32, 6, wheel)
			_fill_rect(img, 12, 32, 24, 2, Color(0.40, 0.40, 0.40))
		"usedcar":
			_fill_rect(img, 6, 22, 36, 12, body)
			_fill_rect(img, 10, 18, 24, 6, body)
			_fill_rect(img, 14, 20, 8, 4, glass)
			_fill_rect(img, 26, 20, 8, 4, glass)
			_draw_img_circle(img, 14, 34, 4, wheel)
			_draw_img_circle(img, 34, 34, 4, wheel)
		"compact", "sedan":
			_fill_rect(img, 4, 20, 40, 14, body)
			_fill_rect(img, 12, 14, 24, 8, body)
			_fill_rect(img, 16, 16, 8, 5, glass)
			_fill_rect(img, 26, 16, 8, 5, glass)
			_draw_img_circle(img, 14, 34, 5, wheel)
			_draw_img_circle(img, 34, 34, 5, wheel)
		"sportscar":
			var red := Color(0.85, 0.20, 0.20)
			_fill_rect(img, 2, 24, 44, 10, red)
			_fill_rect(img, 14, 18, 20, 8, red)
			_fill_rect(img, 18, 20, 6, 4, glass)
			_fill_rect(img, 26, 20, 6, 4, glass)
			_draw_img_circle(img, 12, 34, 5, wheel)
			_draw_img_circle(img, 36, 34, 5, wheel)
		"supercar":
			var yellow := Color(0.90, 0.75, 0.15)
			# 낮고 긴 차체
			_fill_rect(img, 0, 26, 48, 8, yellow)
			_fill_rect(img, 12, 22, 24, 6, yellow)
			_fill_rect(img, 16, 24, 6, 3, Color(0.20, 0.20, 0.25))
			_fill_rect(img, 26, 24, 6, 3, Color(0.20, 0.20, 0.25))
			_draw_img_circle(img, 10, 34, 5, wheel)
			_draw_img_circle(img, 38, 34, 5, wheel)
		"helicopter":
			_fill_rect(img, 8, 22, 28, 12, body)
			_fill_rect(img, 36, 24, 8, 6, body)  # 꼬리
			# 로터
			_fill_rect(img, 2, 18, 44, 2, Color(0.30, 0.30, 0.30))
			_fill_rect(img, 22, 14, 4, 6, Color(0.30, 0.30, 0.30))
			# 창문
			_fill_rect(img, 12, 25, 10, 5, glass)

	return ImageTexture.create_from_image(img)

## UI 방향 화살표
func make_arrow_icon(up: bool, size: int = 16) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var color := Color(0.16, 0.65, 0.42) if up else Color(0.80, 0.27, 0.27)

	if up:
		for i in range(size / 2):
			var w := i * 2 + 1
			var cx := size / 2
			_fill_rect(img, cx - i, size / 2 - i, w, 1, color)
	else:
		for i in range(size / 2):
			var w := i * 2 + 1
			var cx := size / 2
			_fill_rect(img, cx - i, size / 2 + i, w, 1, color)

	return ImageTexture.create_from_image(img)

## 돈 주머니 아이콘
func make_coin_icon(size: int = 16) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var gold := Color(0.90, 0.75, 0.20)
	var gold_dark := Color(0.70, 0.55, 0.15)
	_draw_img_circle(img, size / 2, size / 2, size / 2 - 1, gold)
	_draw_img_circle(img, size / 2, size / 2, size / 2 - 3, gold_dark)
	# ₩ 표시
	_fill_rect(img, size / 2 - 2, size / 2 - 3, 1, 6, Color(0.40, 0.30, 0.05))

	return ImageTexture.create_from_image(img)

# ─── 버퍼 헬퍼 ──────────────────────────

func _fill_buf_rect(buf: PackedByteArray, x: int, y: int, w: int, h: int, value: int) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < 16 and py >= 0 and py < 16:
				buf[py * 16 + px] = value

func _draw_buf_circle(buf: PackedByteArray, cx: int, cy: int, r: int, value: int) -> void:
	for y in range(16):
		for x in range(16):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				buf[y * 16 + x] = value

func _draw_img_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, color)

func _fill_triangle(img: Image, points: Array, color: Color) -> void:
	var min_x := int(min(points[0].x, min(points[1].x, points[2].x)))
	var max_x := int(max(points[0].x, max(points[1].x, points[2].x)))
	var min_y := int(min(points[0].y, min(points[1].y, points[2].y)))
	var max_y := int(max(points[0].y, max(points[1].y, points[2].y)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_triangle(Vector2(x, y), points[0], points[1], points[2]):
				img.set_pixel(x, y, color)

func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0 or d2 < 0 or d3 < 0
	var has_pos := d1 > 0 or d2 > 0 or d3 > 0
	return not (has_neg and has_pos)

func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

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

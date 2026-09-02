class_name UIUtil

## 공통 색상 상수 (MainGame과 동일하게 유지)
const COL_GOLD := Color(1.0, 0.84, 0.31, 1)       # #FFD54F
const COL_TEXT_DIM := Color(0.55, 0.55, 0.62, 1)  # #8C8C9E
const COL_UP := Color(0.40, 0.73, 0.42, 1)        # #66BB6A
const COL_DOWN := Color(1.0, 0.44, 0.26, 1)       # #FF7043
const COL_BORDER := Color(0.239, 0.239, 0.333, 1) # #3D3D55

static func _cat_tag(c: String) -> String:
	match c:
		"korea": return "한국"
		"usa": return "미국"
		"coin": return "코인"
		_: return c

static func _cat_color(c: String) -> Color:
	match c:
		"korea": return Color(0.35, 0.60, 0.90, 1)
		"usa": return Color(0.75, 0.45, 0.85, 1)
		"coin": return COL_GOLD
		_: return COL_TEXT_DIM

static func _chg_color(p: float) -> Color:
	if p > 0.1: return COL_UP
	if p < -0.1: return COL_DOWN
	return COL_TEXT_DIM

static func _fmt_price(p: float) -> String:
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

static func _fmt_won(a: float) -> String:
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

static func _fmt_won_short(a: float) -> String:
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

static func _fmt_change(p: float) -> String:
	var sign := "+" if p >= 0 else ""
	return sign + "%.2f" % p + "%"

static func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

static func _flat(bg: Color, radius: int) -> StyleBoxFlat:
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

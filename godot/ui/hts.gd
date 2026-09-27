class_name Hts
## 모두증권 HTS 화면 규칙.
##
## 800×450 픽셀 캔버스를 정수배로 키운다. 글자는 갈무리11 한 벌만 12px 배수로 쓰고,
## 굵은 글씨는 1px 옆에 한 번 더 찍는다. 창은 윈도 2000식 입체 테두리, 표는 흰 바탕,
## 상승은 빨강 하락은 파랑.

const FACE := Color("#d4d0c8")
const LIGHT := Color("#ffffff")
const SHADOW := Color("#808080")
const DARK := Color("#404040")
const DESK := Color("#3b4b5e")
const DESK_DOT := Color("#34424f")
const TITLE_A := Color("#0a246a")
const TITLE_B := Color("#a6caf0")
const TITLE_OFF_A := Color("#808080")
const TITLE_OFF_B := Color("#c0c0c0")
const INK := Color("#000000")
const SUB := Color("#5a5a5a")
const GRID := Color("#d9d6cf")
const TABLE := Color("#ffffff")
const UP := Color("#e0141e")
const DOWN := Color("#1446e0")
const ASK_BG := Color("#e9f0ff")
const BID_BG := Color("#fff0ef")
const CURRENT_BG := Color("#fff8b8")
const SELECT := Color("#316ac5")
const GOLD := Color("#f2c230")
const WARN := Color("#e07000")
const LED := Color("#ffcf33")
const LED_DIM := Color("#6b5a1c")

const SIZE := 12
const LINE := 14

static var _font: Font
static var _bevels := {}
static var _char_widths := {}


static func font() -> Font:
	if _font == null:
		var file: FontFile = load("res://fonts/Galmuri11.ttf")
		file = file.duplicate()
		file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		file.hinting = TextServer.HINTING_NONE
		file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font = file
	return _font


## 글자 한 줄. pos는 글자 윗줄 기준(베이스라인 아님).
static func text(ci: CanvasItem, pos: Vector2, s: String, color := INK, size := SIZE, bold := false,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var baseline := Vector2(roundf(pos.x), roundf(pos.y) + size)
	ci.draw_string(font(), baseline, s, align, width, size, color)
	if bold:
		ci.draw_string(font(), baseline + Vector2(1, 0), s, align, width, size, color)


## 글자에 1px 테두리 (어두운 배경 위 큰 글씨용).
static func outlined(ci: CanvasItem, pos: Vector2, s: String, color: Color, outline := INK, size := SIZE,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	for offset in [Vector2(-1, 0), Vector2(2, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, -1), Vector2(1, 1)]:
		text(ci, pos + offset, s, outline, size, false, align, width)
	text(ci, pos, s, color, size, true, align, width)


static func text_width(s: String, size := SIZE) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 12px 글자 하나의 폭 (픽셀 글꼴이라 글자 폭을 더하면 줄 폭이 된다).
static func char_width(ch: String) -> float:
	if not _char_widths.has(ch):
		_char_widths[ch] = text_width(ch)
	return _char_widths[ch]


## 윈도 2000식 입체 테두리 2px. raised면 튀어나오고 아니면 들어간다.
static func bevel(ci: CanvasItem, rect: Rect2, raised := true, face := FACE, fill := true) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	if fill:
		ci.draw_rect(r, face)
	var outer_light := LIGHT if raised else SHADOW
	var outer_dark := DARK if raised else LIGHT
	var inner_light := face.lightened(0.3) if raised else DARK
	var inner_dark := SHADOW if raised else face.lightened(0.3)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 1
	var y1 := r.end.y - 1
	ci.draw_rect(Rect2(x0, y0, r.size.x - 1, 1), outer_light)
	ci.draw_rect(Rect2(x0, y0, 1, r.size.y - 1), outer_light)
	ci.draw_rect(Rect2(x0, y1, r.size.x, 1), outer_dark)
	ci.draw_rect(Rect2(x1, y0, 1, r.size.y), outer_dark)
	ci.draw_rect(Rect2(x0 + 1, y0 + 1, r.size.x - 3, 1), inner_light)
	ci.draw_rect(Rect2(x0 + 1, y0 + 1, 1, r.size.y - 3), inner_light)
	ci.draw_rect(Rect2(x0 + 1, y1 - 1, r.size.x - 2, 1), inner_dark)
	ci.draw_rect(Rect2(x1 - 1, y0 + 1, 1, r.size.y - 2), inner_dark)


## 1px 들어간 칸 (표·목록 테두리).
static func well(ci: CanvasItem, rect: Rect2, fill := TABLE) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	ci.draw_rect(r, fill)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), SHADOW)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), SHADOW)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), LIGHT)
	ci.draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), LIGHT)


## 창 제목줄: 남색에서 하늘색으로 8단 계단 그라데이션.
static func title_bar(ci: CanvasItem, rect: Rect2, title: String, active := true) -> void:
	var a := TITLE_A if active else TITLE_OFF_A
	var b := TITLE_B if active else TITLE_OFF_B
	var bands := 8
	var w := rect.size.x / bands
	for i in bands:
		var x := roundf(rect.position.x + i * w)
		var next_x := roundf(rect.position.x + (i + 1) * w)
		ci.draw_rect(Rect2(x, rect.position.y, next_x - x, rect.size.y), a.lerp(b, float(i) / (bands - 1)))
	text(ci, rect.position + Vector2(3, 0), title, LIGHT, SIZE, true)


## 상승 빨강, 하락 파랑, 보합 검정.
static func sign_color(value: float) -> Color:
	if value > 0:
		return UP
	if value < 0:
		return DOWN
	return INK


static func price_color(price: int, base: int) -> Color:
	return sign_color(price - base)


static func arrow(value: float) -> String:
	if value > 0:
		return "▲"
	if value < 0:
		return "▼"
	return " "


static func side_color(faction: int) -> Color:
	if faction == War.Faction.BULL:
		return UP
	if faction == War.Faction.BEAR:
		return DOWN
	return INK


## 버튼 바탕으로 쓸 6×6 입체 테두리 텍스처.
static func bevel_texture(raised: bool, face: Color) -> Texture2D:
	var key := "%s%s" % [raised, face.to_html()]
	if _bevels.has(key):
		return _bevels[key]
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(face)
	var light := LIGHT if raised else DARK
	var dark := DARK if raised else LIGHT
	var inner_light := face.lightened(0.3) if raised else SHADOW
	var inner_dark := SHADOW if raised else face.lightened(0.3)
	for i in 6:
		image.set_pixel(i, 0, light)
		image.set_pixel(0, i, light)
		image.set_pixel(i, 5, dark)
		image.set_pixel(5, i, dark)
	for i in range(1, 5):
		image.set_pixel(i, 1, inner_light)
		image.set_pixel(1, i, inner_light)
		image.set_pixel(i, 4, inner_dark)
		image.set_pixel(4, i, inner_dark)
	image.set_pixel(5, 0, dark)
	image.set_pixel(0, 5, dark)
	var texture := ImageTexture.create_from_image(image)
	_bevels[key] = texture
	return texture


static func bevel_box(raised: bool, face := FACE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = bevel_texture(raised, face)
	box.set_texture_margin_all(2)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


## 버튼 하나에 바탕색과 글자색을 입힌다.
static func paint_button(button: Button, face := FACE, ink := INK) -> void:
	button.add_theme_stylebox_override("normal", bevel_box(true, face))
	button.add_theme_stylebox_override("hover", bevel_box(true, face.lightened(0.08)))
	button.add_theme_stylebox_override("pressed", bevel_box(false, face.darkened(0.05)))
	button.add_theme_stylebox_override("disabled", bevel_box(true, face))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(SHADOW, 1))
	button.focus_mode = Control.FOCUS_NONE


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = SIZE
	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("normal", "Button", bevel_box(true))
	theme.set_stylebox("hover", "Button", bevel_box(true, FACE.lightened(0.08)))
	theme.set_stylebox("pressed", "Button", bevel_box(false))
	theme.set_stylebox("disabled", "Button", bevel_box(true))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", SHADOW)
	theme.set_stylebox("panel", "TooltipPanel", _tooltip_box())
	theme.set_color("font_color", "TooltipLabel", INK)
	return theme


static func _tooltip_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#ffffe1")
	box.border_color = INK
	box.set_border_width_all(1)
	box.set_content_margin_all(3)
	return box


static func button(label: String, face := FACE, ink := INK) -> Button:
	var b := Button.new()
	b.text = label
	paint_button(b, face, ink)
	return b

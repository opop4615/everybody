class_name Look
extends RefCounted
## 화면 공통: 색, 글꼴, 자주 쓰는 노드 만들기.
##
## 어두운 트레이딩 데스크 위에 종이 카드와 종이 전망표가 놓인 모양.
## 한국 시장 관례대로 오름은 빨강, 내림은 파랑.

const BG := Color("0e131a")
const BAR := Color("0a0e14")
const PANEL := Color("121922")
const PANEL_2 := Color("151c26")
const RAISED := Color("1c2532")
const LINE := Color("2a3444")
const LINE_2 := Color("3a4556")
const GRID := Color("1f2835")

const TEXT := Color("eef0f3")
const SOFT := Color("c9d0db")
const DIM := Color("a7b0bf")
const DIM_2 := Color("8a94a6")
const FAINT := Color("5d6a80")

const GOLD := Color("f2c230")
const GOLD_DARK := Color("7a5200")
const GOLD_BG := Color("1f1a0c")

const UP := Color("ff5a4c")
const UP_TEXT := Color("ff8a7e")
const UP_STRONG := Color("b0261b")
const DOWN := Color("4d8dff")
const DOWN_TEXT := Color("8fb4ff")
const DOWN_STRONG := Color("1d4fb8")

const PAPER := Color("f4ecd8")
const PAPER_HABIT := Color("e2dccf")
const INK := Color("1a1916")
const INK_SOFT := Color("4f4a40")

## 카드 종류별 [띠 배경, 띠 글자, 그림 배경, 그림 글자]
const TYPE_COLORS := {
	"long": [Color("b0261b"), Color.WHITE, Color("f1d9d2"), Color("b0261b")],
	"short": [Color("1d4fb8"), Color.WHITE, Color("d9e2f6"), Color("1d4fb8")],
	"entry": [Color("7a3d8c"), Color.WHITE, Color("eadcf0"), Color("5e2a70")],
	"order": [Color("4f4a40"), Color.WHITE, Color("e8e0cc"), Color("4f4a40")],
	"hedge": [Color("46546a"), Color.WHITE, Color("dde3ec"), Color("2e3a4c")],
	"info": [Color("2f6b4f"), Color.WHITE, Color("d8eadf"), Color("24533d")],
	"pattern": [Color("b8860b"), Color.WHITE, Color("f6e7b8"), Color("7a5200")],
	"habit": [Color("7a746a"), Color.WHITE, Color("dcd6ca"), Color("5c5548")],
}
const RARITY_BORDER := [Color("1a1916"), Color("8a94a6"), Color("c9962a")]

static var _fonts := {}


static func font(name: String) -> Font:
	if not _fonts.has(name):
		var path: String = {
			"display": "res://fonts/BlackHanSans-Regular.ttf",
			"body": "res://fonts/IBMPlexSansKR-Regular.ttf",
			"bold": "res://fonts/IBMPlexSansKR-Bold.ttf",
			"mono": "res://fonts/IBMPlexMono-Regular.ttf",
			"mono_bold": "res://fonts/IBMPlexMono-SemiBold.ttf",
		}.get(name, "res://fonts/IBMPlexSansKR-Regular.ttf")
		var loaded: Font = load(path)
		if name.begins_with("mono"):
			# 숫자는 Plex Mono, 한글이 섞이면 Plex Sans KR 로 넘어간다.
			var fallback: Font = load("res://fonts/IBMPlexSansKR-Bold.ttf" if name == "mono_bold" else "res://fonts/IBMPlexSansKR-Regular.ttf")
			var variation := FontVariation.new()
			variation.base_font = loaded
			variation.fallbacks = [fallback]
			loaded = variation
		elif name == "display":
			var variation := FontVariation.new()
			variation.base_font = loaded
			variation.fallbacks = [load("res://fonts/IBMPlexSansKR-Bold.ttf")]
			loaded = variation
		_fonts[name] = loaded
	return _fonts[name]


static func up_down(value: float) -> Color:
	if value > 0.0001:
		return UP_TEXT
	if value < -0.0001:
		return DOWN_TEXT
	return TEXT


# ── 노드 만들기 ───────────────────────────────────────────────────

static func label(text: String, size := 14, color := TEXT, face := "body") -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font(face))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func wrap_label(text: String, size := 14, color := TEXT, width := 200.0, face := "body") -> Label:
	var node := label(text, size, color, face)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = width
	return node


static func rich(bbcode: String, size := 14, color := TEXT, width := 200.0) -> RichTextLabel:
	var node := RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = true
	node.scroll_active = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = width
	node.add_theme_font_override("normal_font", font("body"))
	node.add_theme_font_override("bold_font", font("bold"))
	node.add_theme_font_override("mono_font", font("mono"))
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_font_size_override("bold_font_size", size)
	node.add_theme_font_size_override("mono_font_size", size)
	node.add_theme_color_override("default_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = bbcode
	return node


static func box(bg := PANEL, border := LINE, radius := 8, border_width := 1, pad := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	style.anti_aliasing = true
	return style


static func panel(bg := PANEL, border := LINE, radius := 8, pad := 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(bg, border, radius, 1, pad))
	return node


static func vbox(gap := 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node


static func hbox(gap := 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 버튼. kind: "primary"(금색 테두리), "plain", "ghost"
static func button(text: String, kind := "plain", size := 15, key := "") -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := "display" if kind == "primary" else "bold"
	node.add_theme_font_override("font", font(face))
	node.add_theme_font_size_override("font_size", size)
	var border := GOLD if kind == "primary" else LINE_2
	var bg := RAISED if kind != "ghost" else Color(0, 0, 0, 0)
	var ink := GOLD if kind == "primary" else TEXT
	var normal := box(bg, border, 8, 2 if kind == "primary" else 1, 10)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08) if kind != "ghost" else Color(1, 1, 1, 0.05)
	hover.border_color = border.lightened(0.2)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.2)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = PANEL
	disabled.border_color = LINE
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", disabled)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	node.add_theme_color_override("font_color", ink)
	node.add_theme_color_override("font_hover_color", ink.lightened(0.2))
	node.add_theme_color_override("font_pressed_color", ink)
	node.add_theme_color_override("font_disabled_color", FAINT)
	if not key.is_empty():
		node.text = "%s  [%s]" % [text, key]
	return node


## 작은 글자 딱지 (보스, 정예, 롱 3계약 …).
static func tag(text: String, bg: Color, ink := Color.WHITE, size := 12) -> PanelContainer:
	var node := PanelContainer.new()
	var style := box(bg, bg, 3, 0, 0)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 1
	style.content_margin_bottom = 2
	node.add_theme_stylebox_override("panel", style)
	node.add_child(label(text, size, ink, "bold"))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func stars(level: int, of := 3) -> String:
	return "★".repeat(level) + "☆".repeat(maxi(0, of - level))


## 전체 화면을 덮는 반투명 막.
static func dim_layer(alpha := 0.72) -> ColorRect:
	var node := ColorRect.new()
	node.color = Color(0.02, 0.03, 0.05, alpha)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


static func place(node: Control, x: float, y: float, w := -1.0, h := -1.0) -> Control:
	node.position = Vector2(x, y)
	if w >= 0.0 or h >= 0.0:
		node.size = Vector2(maxf(w, 0.0), maxf(h, 0.0))
		node.custom_minimum_size = node.size
	return node


static func kind_name(kind: String) -> String:
	return {"trade": "거래", "elite": "발표일", "boss": "보스", "news": "뉴스", "desk": "데스크",
		"rest": "퇴근", "start": "출근"}.get(kind, kind)


static func kind_color(kind: String) -> Color:
	return {"trade": Color("3a4556"), "elite": Color("7a3d8c"), "boss": DOWN_STRONG, "news": Color("8a6a1c"),
		"desk": Color("2f6b4f"), "rest": Color("46546a"), "start": Color("2a3444")}.get(kind, LINE_2)

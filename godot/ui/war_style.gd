class_name WarStyle
## 호가전쟁 화면 색과 스타일. 국내 관례대로 상승·매수는 빨강, 하락·매도는 파랑.

const BULL := Color("#f04852")
const BEAR := Color("#408efa")
const DEEP := Color("#0a2647")
const PANEL := Color("#144272")
const ACCENT := Color("#205295")
const MUTED := Color("#96acc6")
const WARNING := Color("#ffb224")
const GOLD := Color("#ffd24a")
const MA_SHORT := Color("#ffd65a")
const MA_LONG := Color("#be96ff")

static var _regular: Font
static var _bold: Font


static func regular() -> Font:
	if _regular == null:
		_regular = load("res://fonts/NanumSquareNeo-bRg.ttf")
	return _regular


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://fonts/NanumSquareNeo-dEb.ttf")
	return _bold


static func of(faction: int) -> Color:
	if faction == War.Faction.BULL:
		return BULL
	if faction == War.Faction.BEAR:
		return BEAR
	return Color.WHITE


static func for_price(price: int, base: int) -> Color:
	if price > base:
		return BULL
	if price < base:
		return BEAR
	return Color.WHITE


static func for_sign(value: float) -> Color:
	if value > 0:
		return BULL
	if value < 0:
		return BEAR
	return Color.WHITE


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 8, border_width := 0, padding := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = regular()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color.WHITE)
	theme.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.55)))
	theme.set_font("bold_font", "RichTextLabel", bold())
	theme.set_color("default_color", "RichTextLabel", Color.WHITE)
	style_button_theme(theme)
	return theme


static func style_button_theme(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", box(ACCENT, Color(0, 0, 0, 0), 8, 0, 8))
	theme.set_stylebox("hover", "Button", box(ACCENT.lightened(0.15), Color(0, 0, 0, 0), 8, 0, 8))
	theme.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.2), Color(0, 0, 0, 0), 8, 0, 8))
	theme.set_stylebox("disabled", "Button", box(Color(ACCENT, 0.35), Color(0, 0, 0, 0), 8, 0, 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", Color.WHITE)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))


## 버튼 하나에 색을 입힌다. outline이면 테두리만.
static func paint_button(button: Button, color: Color, outline := false, font_size := 18) -> void:
	var bg := Color(color, 0.18) if outline else color
	var border := color if outline else Color(0, 0, 0, 0)
	button.add_theme_stylebox_override("normal", box(bg, border, 8, 2 if outline else 0, 8))
	button.add_theme_stylebox_override("hover", box(bg.lightened(0.12), border.lightened(0.2), 8, 2 if outline else 0, 8))
	button.add_theme_stylebox_override("pressed", box(bg.darkened(0.2), border, 8, 2 if outline else 0, 8))
	button.add_theme_stylebox_override("disabled", box(Color(bg, bg.a * 0.35), Color(border, 0.3), 8, 2 if outline else 0, 8))
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE


## 스킬 카드: 짙은 바탕에 진영 색 테두리.
static func paint_card(button: Button, color: Color) -> void:
	var bg := Color("#0b1c36")
	button.add_theme_stylebox_override("normal", box(bg, color, 10, 2, 10))
	button.add_theme_stylebox_override("hover", box(bg.lightened(0.1), color.lightened(0.3), 10, 3, 10))
	button.add_theme_stylebox_override("pressed", box(Color(color, 0.4), color, 10, 3, 10))
	button.add_theme_stylebox_override("disabled", box(Color(bg, 0.6), Color(color, 0.3), 10, 2, 10))
	button.add_theme_font_size_override("font_size", 15)
	button.focus_mode = Control.FOCUS_NONE


static func label(text: String, font_size := 16, color := Color.WHITE, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


static func hex(color: Color) -> String:
	return color.to_html(false)

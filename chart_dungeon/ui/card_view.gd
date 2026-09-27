class_name CardView
extends Control
## 종이 카드 한 장.
##   왼쪽 위 동전 = 주문 한도 비용, 띠 = 종류, 가운데 그림 칸, 아래 설명.
##   밑줄 친 금색 낱말은 투자 노트 항목이다 (마우스를 올리면 설명이 뜬다).

signal hovered(view: CardView)
signal unhovered(view: CardView)
signal clicked(view: CardView)

const W := 150.0
const H := 210.0

var card: Card
var trade: Trade
var cost := 0
var playable := true
## 손에 있을 때 돌아갈 자리.
var home := Vector2.ZERO
var home_rotation := 0.0
var lifted := false
var selected := false
var price_text := ""

var _name_label: Label
var _art_label: Label
var _type_label: Label
var _text: RichTextLabel
var _foot: Label


func setup(p_card: Card, p_trade: Trade = null) -> CardView:
	card = p_card
	trade = p_trade
	size = Vector2(W, H)
	custom_minimum_size = size
	pivot_offset = Vector2(W * 0.5, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_type_label = Look.label("", 11, Color.WHITE, "bold")
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Look.place(_type_label, 26, 3, W - 36, 18)
	add_child(_type_label)
	_name_label = Look.label("", 17, Look.INK, "display")
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Look.place(_name_label, 8, 27, W - 16, 24)
	add_child(_name_label)
	_art_label = Look.label("", 22, Look.INK, "display")
	_art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Look.place(_art_label, 12, 56, W - 24, 48)
	add_child(_art_label)
	_text = Look.rich("", 12, Look.INK, W - 20)
	_text.add_theme_constant_override("line_separation", 1)
	Look.place(_text, 10, 110, W - 20, 0)
	add_child(_text)
	_foot = Look.label("", 10, Look.INK_SOFT, "bold")
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Look.place(_foot, 8, H - 20, W - 16, 16)
	add_child(_foot)
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit(self))
	refresh()
	return self


func refresh() -> void:
	if card == null:
		return
	cost = trade.cost_of(card) if trade else card.base_cost()
	playable = card.playable() and (trade == null or trade.why_not(card).is_empty())
	_type_label.text = CardDB.TYPE_LABEL.get(card.type(), "")
	_name_label.text = card.name()
	_name_label.add_theme_color_override("font_color", Color("1f6b3a") if card.upgraded else Look.INK)
	var colors: Array = Look.TYPE_COLORS.get(card.type(), Look.TYPE_COLORS["order"])
	_art_label.text = CardDB.art(card, trade)
	_art_label.add_theme_color_override("font_color", colors[3])
	var parts := CardDB.text(card, trade)
	_text.text = "%s[color=#7a5200][u]%s[/u][/color]%s" % [parts[0], parts[1], parts[2]]
	var foot := ""
	if card.ethereal:
		foot = "오늘만"
	if not price_text.is_empty():
		foot = price_text
	_foot.text = foot
	queue_redraw()


func keyword() -> String:
	var note: String = card.def().get("note", "")
	if card.type() == "pattern":
		note = card.def()["pattern"]
	return note


func _draw() -> void:
	var colors: Array = Look.TYPE_COLORS.get(card.type(), Look.TYPE_COLORS["order"])
	var paper := Look.PAPER_HABIT if card.is_habit() else Look.PAPER
	var border: Color = Look.RARITY_BORDER[clampi(card.rarity(), 0, 2)]
	# 그림자
	var shadow := Look.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 10, 0, 0)
	draw_style_box(shadow, Rect2(Vector2(3, 7), size))
	if selected:
		var glow := Look.box(Color(0, 0, 0, 0), Look.GOLD, 12, 3, 0)
		draw_style_box(glow, Rect2(Vector2(-4, -4), size + Vector2(8, 8)))
	var body := Look.box(paper, border, 9, 3 if card.rarity() > 0 else 2, 0)
	draw_style_box(body, Rect2(Vector2.ZERO, size))
	# 종류 띠
	var strip := StyleBoxFlat.new()
	strip.bg_color = colors[0]
	strip.corner_radius_top_left = 7
	strip.corner_radius_top_right = 7
	strip.anti_aliasing = true
	draw_style_box(strip, Rect2(Vector2(2, 2), Vector2(size.x - 4, 21)))
	# 그림 칸
	var art := Look.box(colors[2], colors[2], 4, 0, 0)
	draw_style_box(art, Rect2(Vector2(12, 56), Vector2(size.x - 24, 48)))
	if card.type() == "pattern":
		_draw_pattern_mark(Rect2(Vector2(12, 56), Vector2(size.x - 24, 48)))
	# 비용 동전
	var coin_center := Vector2(7, 7)
	var coin_bg := Look.GOLD
	if not card.playable():
		coin_bg = Color("cfc6b2")
	elif trade and cost < card.base_cost():
		coin_bg = Color("7fd18b")
	draw_circle(coin_center, 18, Look.INK)
	draw_circle(coin_center, 15.5, coin_bg)
	var coin_text := "–" if not card.playable() else str(cost)
	var font := Look.font("display")
	var text_size := font.get_string_size(coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, coin_center + Vector2(-text_size.x * 0.5, 7), coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Look.INK)
	if card.upgraded:
		draw_string(Look.font("bold"), Vector2(size.x - 18, size.y - 8), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("1f6b3a"))
	if trade and not playable and card.playable():
		draw_style_box(Look.box(Color(0.05, 0.07, 0.1, 0.38), Color(0, 0, 0, 0), 9, 0, 0), Rect2(Vector2.ZERO, size))


## 패턴 카드 그림 칸에 작은 캔들 모양을 그린다.
func _draw_pattern_mark(area: Rect2) -> void:
	var pattern: String = card.def().get("pattern", "")
	var up := Look.UP
	var down := Look.DOWN
	var cx := area.position.x + 14.0
	var y0 := area.position.y + 8.0
	var h := area.size.y - 16.0
	var candles: Array = []
	match pattern:
		"hammer":
			candles = [[0.1, 0.5, 0.2, 0.6, false], [0.35, 0.95, 0.35, 0.45, true]]
		"shooting_star":
			candles = [[0.4, 0.9, 0.5, 0.8, true], [0.05, 0.65, 0.55, 0.65, false]]
		"bullish_engulfing":
			candles = [[0.35, 0.75, 0.45, 0.65, false], [0.25, 0.8, 0.3, 0.7, true]]
		"bearish_engulfing":
			candles = [[0.25, 0.65, 0.35, 0.55, true], [0.2, 0.75, 0.3, 0.7, false]]
		_:
			candles = []
	if candles.is_empty():
		return
	for i in candles.size():
		var c: Array = candles[i]
		var x := cx + i * 16.0
		var color: Color = up if c[4] else down
		draw_line(Vector2(x, y0 + h * c[0]), Vector2(x, y0 + h * c[1]), color, 1.5)
		draw_rect(Rect2(Vector2(x - 4, y0 + h * c[2]), Vector2(8, h * (c[3] - c[2]))), color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()

class_name OrderBookView
extends Control
## 호가창: 위는 매도 호가(파랑), 아래는 매수 호가(빨강). 칸을 누르면 그 가격에 주문한다.

signal price_clicked(price: int)

const LEVELS := 10
const HEADER := 26.0

var engine: BattleEngine
var _row_prices: Array[int] = []
var _hover := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _row_height() -> float:
	return (size.y - HEADER) / (LEVELS * 2)


func _row_at(y: float) -> int:
	if y < HEADER:
		return -1
	return clampi(int((y - HEADER) / _row_height()), 0, LEVELS * 2 - 1)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var row := _row_at(motion.position.y)
		if row != _hover:
			_hover = row
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(click.position.y)
		if row >= 0 and row < _row_prices.size() and _row_prices[row] != OrderBook.NO_PRICE:
			price_clicked.emit(_row_prices[row])
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()


func _draw() -> void:
	if engine == null:
		return
	var font := WarStyle.regular()
	var bold := WarStyle.bold()
	var w := size.x
	var col := w / 3.0
	var row_h := _row_height()
	var fs := int(clampf(row_h * 0.62, 11, 17))

	draw_string(font, Vector2(0, 18), "매도잔량", HORIZONTAL_ALIGNMENT_CENTER, col, 13, WarStyle.MUTED)
	draw_string(font, Vector2(col, 18), "호가", HORIZONTAL_ALIGNMENT_CENTER, col, 13, WarStyle.MUTED)
	draw_string(font, Vector2(col * 2, 18), "매수잔량", HORIZONTAL_ALIGNMENT_CENTER, col, 13, WarStyle.MUTED)

	var asks := engine.asks(LEVELS)
	var bids := engine.bids(LEVELS)
	var max_qty := 1
	for level: OrderBook.BookLevel in asks + bids:
		max_qty = maxi(max_qty, level.quantity)

	_row_prices.clear()
	for row in LEVELS * 2:
		var is_ask := row < LEVELS
		var index := LEVELS - 1 - row if is_ask else row - LEVELS
		var list := asks if is_ask else bids
		var level: OrderBook.BookLevel = list[index] if index < list.size() else null
		_row_prices.append(level.price if level != null else OrderBook.NO_PRICE)
		_draw_row(Rect2(0, HEADER + row * row_h, w, row_h), level, is_ask, max_qty, font, bold, fs, row == _hover)


func _draw_row(rect: Rect2, level: OrderBook.BookLevel, is_ask: bool, max_qty: int,
		font: Font, bold: Font, fs: int, hovered: bool) -> void:
	var col := rect.size.x / 3.0
	var tint := WarStyle.BEAR if is_ask else WarStyle.BULL
	var price_rect := Rect2(rect.position.x + col, rect.position.y + 1, col, rect.size.y - 2)
	draw_rect(price_rect, Color(tint, 0.10 if level != null else 0.05))
	if hovered and level != null:
		draw_rect(Rect2(rect.position, rect.size), Color(1, 1, 1, 0.07))
	if level == null:
		return
	var baseline := rect.position.y + rect.size.y * 0.5 + fs * 0.36

	# 잔량 막대: 가격 칸 쪽에 붙는다.
	var qty_x := rect.position.x if is_ask else rect.position.x + col * 2
	var share := clampf(float(level.quantity) / max_qty, 0.03, 1.0)
	var bar_w := (col - 4) * share
	var bar_x := qty_x + col - 2 - bar_w if is_ask else qty_x + 2
	draw_rect(Rect2(bar_x, rect.position.y + rect.size.y * 0.18, bar_w, rect.size.y * 0.64), Color(tint, 0.35))
	draw_string(font, Vector2(qty_x + 6, baseline), Krx.format_number(level.quantity),
		HORIZONTAL_ALIGNMENT_RIGHT if is_ask else HORIZONTAL_ALIGNMENT_LEFT, col - 12, fs, Color.WHITE)

	# 가격
	var is_last := level.price == engine.last_price
	var price_color := WarStyle.for_price(level.price, engine.base_price)
	draw_string(bold if is_last else font, Vector2(price_rect.position.x, baseline),
		Krx.format_number(level.price), HORIZONTAL_ALIGNMENT_CENTER, col - 34, fs + 1, price_color)
	var rate := float(level.price - engine.base_price) / engine.base_price
	draw_string(font, Vector2(price_rect.end.x - 40, baseline), "%.1f%%" % (rate * 100.0),
		HORIZONTAL_ALIGNMENT_RIGHT, 36, fs - 4, Color(price_color, 0.8))
	if is_last:
		draw_rect(price_rect, Color.WHITE, false, 1.5)
	var tag := ""
	if level.price == engine.upper_limit:
		tag = "상"
	elif level.price == engine.lower_limit:
		tag = "하"
	if not tag.is_empty():
		draw_string(bold, Vector2(price_rect.position.x + 4, baseline), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, WarStyle.WARNING)

	# 반대편 빈 칸: 내 주문과 특수 벽
	var side_x := rect.position.x + col * 2 if is_ask else rect.position.x
	var align := HORIZONTAL_ALIGNMENT_LEFT if is_ask else HORIZONTAL_ALIGNMENT_RIGHT
	if level.player_quantity > 0:
		draw_string(bold, Vector2(side_x + 6, baseline), "내 " + Krx.format_number(level.player_quantity),
			align, col - 12, fs - 1, WarStyle.GOLD)
	elif level.wall_quantity > 0:
		draw_string(font, Vector2(side_x + 6, baseline), "[%s]" % level.wall_tag,
			align, col - 12, fs - 2, WarStyle.WARNING)

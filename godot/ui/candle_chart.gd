class_name CandleChart
extends Control
## 5분봉 차트: 양봉 빨강, 음봉 파랑, 5·20 이동평균선, 기준가 점선.

const VISIBLE := 60
const AXIS := 64.0
const TIME_AXIS := 18.0

var engine: BattleEngine


func _draw() -> void:
	if engine == null:
		return
	var font := WarStyle.regular()
	var all: Array = engine.candles.duplicate()
	all.append(engine.current_candle)
	var start := maxi(0, all.size() - VISIBLE)
	var shown := all.slice(start)
	var high := 0
	var low := 1 << 40
	for c: Candle in shown:
		high = maxi(high, c.high)
		low = mini(low, c.low)
	var pad := maxf((high - low) * 0.12, engine.base_price * 0.004)
	var top := high + pad
	var bottom := low - pad
	var width := size.x - AXIS
	var height := size.y - TIME_AXIS - 18
	var slot := width / VISIBLE
	var y := func(price: float) -> float: return 18 + height * (top - price) / (top - bottom)

	draw_string(font, Vector2(4, 13), "5분봉", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WarStyle.MUTED)
	draw_string(font, Vector2(48, 13), "MA5", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WarStyle.MA_SHORT)
	draw_string(font, Vector2(84, 13), "MA20", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WarStyle.MA_LONG)

	# 가로 눈금
	for i in 5:
		var price := bottom + (top - bottom) * i / 4.0
		var gy: float = y.call(price)
		draw_line(Vector2(0, gy), Vector2(width, gy), Color(1, 1, 1, 0.05))
		draw_string(font, Vector2(width + 6, gy + 4), Krx.format_number(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WarStyle.MUTED)

	# 기준가
	if engine.base_price > bottom and engine.base_price < top:
		var by: float = y.call(engine.base_price)
		draw_dashed_line(Vector2(0, by), Vector2(width, by), Color(WarStyle.MUTED, 0.6), 1.0, 4.0)

	# 봉
	for i in shown.size():
		var c: Candle = shown[i]
		var x := (i + 0.5) * slot
		var color := Color(1, 1, 1, 0.7)
		if c.close > c.open:
			color = WarStyle.BULL
		elif c.close < c.open:
			color = WarStyle.BEAR
		draw_line(Vector2(x, y.call(c.high)), Vector2(x, y.call(c.low)), color, 1.0)
		var body_top: float = y.call(maxi(c.open, c.close))
		var body_bottom: float = maxf(y.call(mini(c.open, c.close)), body_top + 1.0)
		draw_rect(Rect2(x - slot * 0.34, body_top, slot * 0.68, body_bottom - body_top), color)
		var index := start + i
		if index % 12 == 0:
			var minutes := 9 * 60 + index * BattleEngine.TICKS_PER_CANDLE
			@warning_ignore("integer_division")
			var label := "%02d:%02d" % [minutes / 60, minutes % 60]
			draw_string(font, Vector2(x - 20, size.y - 3), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 11, WarStyle.MUTED)

	# 이동평균선
	for spec in [[5, WarStyle.MA_SHORT], [20, WarStyle.MA_LONG]]:
		var points := PackedVector2Array()
		for i in shown.size():
			var ma := Candle.moving_average(all, spec[0], start + i + 1)
			if not is_nan(ma):
				points.append(Vector2((i + 0.5) * slot, y.call(ma)))
		if points.size() >= 2:
			draw_polyline(points, spec[1], 1.5, true)

	# 현재가 꼬리표
	var last := engine.last_price
	var ly := clampf(y.call(last), 18.0, 18.0 + height)
	var tag_color := WarStyle.for_price(last, engine.base_price)
	draw_rect(Rect2(width + 2, ly - 10, AXIS - 2, 20), Color(tag_color, 0.9) if tag_color != Color.WHITE else Color(WarStyle.ACCENT, 0.9))
	draw_string(WarStyle.bold(), Vector2(width + 2, ly + 5), Krx.format_number(last), HORIZONTAL_ALIGNMENT_CENTER, AXIS - 2, 12, Color.WHITE)

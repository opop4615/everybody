class_name MiniChart
extends Control
## [0600] 5분봉. 하루 78개 봉이 한 화면에 다 들어간다 (봉 3px + 틈 1px).

const AXIS := 44
const STEP := 4
const MA_SHORT := Color("#d08a00")
const MA_LONG := Color("#8a3cc8")

var engine: BattleEngine


func _draw() -> void:
	Hts.well(self, Rect2(Vector2.ZERO, size))
	if engine == null:
		return
	var plot := Rect2(2, 12, size.x - AXIS - 4, size.y - 24)
	var all: Array = engine.candles.duplicate()
	if engine.phase != BattleEngine.Phase.PREOPEN and engine.phase != BattleEngine.Phase.CLOSED:
		all.append(engine.current_candle)
	Hts.text(self, Vector2(3, -1), "5분봉", Hts.SUB)
	Hts.text(self, Vector2(40, -1), "5이평", MA_SHORT)
	Hts.text(self, Vector2(78, -1), "20이평", MA_LONG)
	if all.is_empty():
		Hts.text(self, plot.position + Vector2(0, plot.size.y * 0.5 - 8), "09:00 시가가 나오면 그려진다", Hts.SUB, 12, false,
			HORIZONTAL_ALIGNMENT_CENTER, plot.size.x)
		return
	var high := engine.base_price
	var low := engine.base_price
	for c: Candle in all:
		high = maxi(high, c.high)
		low = mini(low, c.low)
	var pad := maxi(Krx.tick_size(engine.base_price) * 3, roundi((high - low) * 0.08))
	var top := high + pad
	var bottom := low - pad
	var y := func(price: float) -> float: return roundf(plot.position.y + plot.size.y * (top - price) / float(top - bottom))
	# 기준가 점선과 가격축
	var base_y: float = y.call(engine.base_price)
	for x in range(int(plot.position.x), int(plot.end.x), 4):
		draw_rect(Rect2(x, base_y, 2, 1), Hts.SHADOW)
	for price in [top, (top + bottom) / 2.0, bottom]:
		var py: float = y.call(price)
		draw_rect(Rect2(plot.end.x, py, 3, 1), Hts.SHADOW)
		Hts.text(self, Vector2(plot.end.x + 4, py - 8), Krx.format_number(Krx.floor_to_tick(roundi(price))), Hts.price_color(roundi(price), engine.base_price))
	# 시간 눈금
	for hour in range(9, 16):
		var index := (hour - 9) * 12
		var tx := plot.position.x + index * STEP
		draw_rect(Rect2(tx, plot.end.y, 1, 3), Hts.SHADOW)
		Hts.text(self, Vector2(tx - 8, plot.end.y - 1), "%d" % hour, Hts.SUB)
	# 봉
	for i in all.size():
		var c: Candle = all[i]
		var x := plot.position.x + i * STEP
		var color := Hts.SHADOW
		if c.close > c.open:
			color = Hts.UP
		elif c.close < c.open:
			color = Hts.DOWN
		var hy: float = y.call(c.high)
		var ly: float = y.call(c.low)
		draw_rect(Rect2(x + 1, hy, 1, maxf(1, ly - hy + 1)), color)
		var oy: float = y.call(maxi(c.open, c.close))
		var cy: float = y.call(mini(c.open, c.close))
		draw_rect(Rect2(x, oy, 3, maxf(1, cy - oy + 1)), color)
	# 이동평균
	for spec in [[5, MA_SHORT], [20, MA_LONG]]:
		var prev := Vector2.ZERO
		for i in all.size():
			var ma := Candle.moving_average(all, spec[0], i + 1)
			if is_nan(ma):
				continue
			var point := Vector2(plot.position.x + i * STEP + 1, y.call(ma))
			if prev != Vector2.ZERO:
				draw_line(prev, point, spec[1], 1.0)
			prev = point

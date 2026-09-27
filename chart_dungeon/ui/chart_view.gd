class_name ChartView
extends Control
## 일봉 차트. 지난 캔들, 오늘 자리의 전망 상자, 가로선(평단·주문·마진콜), 장중 재생.

## 지난 봉들 (오늘 앞까지).
var bars: Array[Bar] = []
var instrument: Instrument
## 오늘 자리 전망: {low, high, up (0~1 또는 -1), label}
var forecast := {}
## 가로선: {price, color, label, dashed, width}
var lines: Array[Dictionary] = []
## 카드에 마우스를 올렸을 때 미리 보는 선.
var preview_lines: Array[Dictionary] = []
var show_ma := false
var today_label := ""

## 장중 재생 중인 오늘 캔들. {open, high, low, close}. 비어 있으면 안 그린다.
var live := {}
var live_trace: PackedVector2Array = PackedVector2Array()
## 재생 중 찍힌 체결 자리: {price, t, color, index}
var marks: Array[Dictionary] = []
var _locked_range := Vector2.ZERO

const PAD_LEFT := 12.0
const PAD_RIGHT := 70.0
const PAD_TOP := 46.0
const PAD_BOTTOM := 44.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)


## 지난 봉 + 오늘 + 재생 궤적 자리 세 칸.
func slot_count() -> int:
	return bars.size() + 4


func slot_width() -> float:
	return plot_rect().size.x / float(slot_count())


func slot_x(index: int) -> float:
	return plot_rect().position.x + (index + 0.5) * slot_width()


func today_x() -> float:
	return slot_x(bars.size())


func price_range() -> Vector2:
	if _locked_range != Vector2.ZERO:
		return _locked_range
	var lo := INF
	var hi := -INF
	for bar in bars:
		lo = minf(lo, bar.low)
		hi = maxf(hi, bar.high)
	if not forecast.is_empty():
		lo = minf(lo, forecast["low"])
		hi = maxf(hi, forecast["high"])
	if not live.is_empty():
		lo = minf(lo, live["low"])
		hi = maxf(hi, live["high"])
	var span := maxf(hi - lo, 0.0001)
	# 너무 먼 선은 범위를 늘리지 않고 가장자리에 화살표로 보인다.
	for line in lines + preview_lines:
		var p: float = line["price"]
		if is_nan(p):
			continue
		if p > lo - span * 0.6 and p < hi + span * 0.6:
			lo = minf(lo, p)
			hi = maxf(hi, p)
	if lo == INF:
		return Vector2(0, 1)
	var margin := (hi - lo) * 0.08
	return Vector2(lo - margin, hi + margin)


func lock_range(lo: float, hi: float) -> void:
	var margin := (hi - lo) * 0.08
	_locked_range = Vector2(lo - margin, hi + margin)


func unlock_range() -> void:
	_locked_range = Vector2.ZERO


func y_of(price: float) -> float:
	var r := price_range()
	var area := plot_rect()
	var k := (price - r.x) / maxf(r.y - r.x, 0.000001)
	return area.position.y + area.size.y * (1.0 - k)


func _draw() -> void:
	var area := plot_rect()
	var r := price_range()
	var mono := Look.font("mono")
	var body := Look.font("body")
	var bold := Look.font("bold")
	# 눈금
	var step := _nice_step((r.y - r.x) / 5.0)
	var value := ceilf(r.x / step) * step
	while value <= r.y:
		var y := y_of(value)
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Look.GRID, 1.0)
		draw_string(mono, Vector2(area.end.x + 6, y + 4), _price(value), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM_2)
		value += step
	# 날짜
	var every := maxi(1, int(ceil(bars.size() / 7.0)))
	for i in bars.size():
		if i < bars.size() - 1 and (bars.size() - 1 - i) % every == 0:
			draw_string(mono, Vector2(slot_x(i) - 14, area.end.y + 16), bars[i].short_date(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM_2)
	if not today_label.is_empty():
		draw_string(bold, Vector2(today_x() - 14, area.end.y + 16), today_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.GOLD)
	# 캔들
	var w := clampf(slot_width() * 0.62, 3.0, 26.0)
	for i in bars.size():
		_draw_candle(slot_x(i), bars[i].open, bars[i].high, bars[i].low, bars[i].close, w, bars[i].estimated)
	# 이동평균 (5일)
	if show_ma and bars.size() >= 6:
		var points := PackedVector2Array()
		for i in range(4, bars.size()):
			var total := 0.0
			for k in 5:
				total += bars[i - k].close
			points.append(Vector2(slot_x(i), y_of(total / 5.0)))
		if points.size() >= 2:
			draw_polyline(points, Color(Look.GOLD, 0.8), 1.5, true)
	# 전망 상자
	if not forecast.is_empty() and live.is_empty():
		var x := today_x()
		var top := y_of(forecast["high"])
		var bottom := y_of(forecast["low"])
		var box_w := maxf(w * 2.4, 34.0)
		var rect := Rect2(Vector2(x - box_w * 0.5, top), Vector2(box_w, bottom - top))
		draw_rect(rect, Color(Look.GOLD, 0.10))
		_dashed_rect(rect, Look.GOLD)
		var up: float = forecast.get("up", -1.0)
		if up >= 0.0 and absf(up - 0.5) > 0.02:
			var mid := (top + bottom) * 0.5
			var dir := -1.0 if up > 0.5 else 1.0
			var length := minf((bottom - top) * 0.32, 44.0)
			var color := Look.UP_TEXT if up > 0.5 else Look.DOWN_TEXT
			var tip := Vector2(x, mid + dir * length)
			draw_line(Vector2(x, mid - dir * length * 0.4), tip, color, 3.0, true)
			draw_line(tip, tip + Vector2(-9, -dir * 9), color, 3.0, true)
			draw_line(tip, tip + Vector2(9, -dir * 9), color, 3.0, true)
	# 가로선
	for line in lines:
		_draw_hline(line, 1.0)
	for line in preview_lines:
		_draw_hline(line, 0.95)
	# 장중 재생
	if not live.is_empty():
		var x := today_x()
		_draw_candle(x, live["open"], live["high"], live["low"], live["close"], w, false)
		if live_trace.size() >= 2:
			draw_polyline(live_trace, Color(Look.GOLD, 0.9), 2.0, true)
		var y := y_of(live["close"])
		draw_dashed_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(Look.GOLD, 0.5), 1.0, 4.0)
		var tag := Rect2(Vector2(area.end.x + 2, y - 10), Vector2(PAD_RIGHT - 4, 20))
		draw_rect(tag, Look.GOLD)
		draw_string(Look.font("mono_bold"), Vector2(tag.position.x + 4, y + 5), _price(live["close"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.INK)
		for mark in marks:
			var p := Vector2(mark["x"], y_of(mark["price"]))
			draw_circle(p, 11, Look.RAISED)
			draw_arc(p, 11, 0, TAU, 24, mark["color"], 2.0, true)
			draw_string(bold, p + Vector2(-4, 5), str(mark["index"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, mark["color"])


func _draw_candle(x: float, open: float, high: float, low: float, close: float, w: float, estimated: bool) -> void:
	var up := close >= open
	var color := Look.UP if up else Look.DOWN
	if estimated:
		color = color.lerp(Look.PANEL, 0.12)
	draw_line(Vector2(x, y_of(high)), Vector2(x, y_of(low)), color, 1.5)
	var top := y_of(maxf(open, close))
	var bottom := y_of(minf(open, close))
	draw_rect(Rect2(Vector2(x - w * 0.5, top), Vector2(w, maxf(bottom - top, 1.5))), color)


func _draw_hline(line: Dictionary, alpha: float) -> void:
	var price: float = line["price"]
	if is_nan(price):
		return
	var area := plot_rect()
	var color: Color = Color(line.get("color", Look.TEXT), alpha)
	var r := price_range()
	var text: String = line.get("label", "")
	var bold := Look.font("bold")
	if price > r.y or price < r.x:
		# 범위 밖: 가장자리에 화살표와 이름만.
		var edge_y := area.position.y + 12.0 if price > r.y else area.end.y - 6.0
		var arrow := "▲ " if price > r.y else "▼ "
		draw_string(bold, Vector2(area.position.x + 6, edge_y), arrow + text + " " + _price(price), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		return
	var y := y_of(price)
	var width: float = line.get("width", 1.5)
	if line.get("dashed", false):
		draw_dashed_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, width, 6.0)
	else:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, width)
	if not text.is_empty():
		var label_text := "%s %s" % [text, _price(price)]
		var text_size := bold.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var at := Vector2(area.position.x + 6, y - 5)
		if line.get("right", false):
			at.x = area.end.x - text_size.x - 6
		draw_rect(Rect2(at + Vector2(-3, -12), text_size + Vector2(6, 4)), Color(Look.PANEL, 0.85))
		draw_string(bold, at, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)


func _dashed_rect(rect: Rect2, color: Color) -> void:
	var a := rect.position
	var b := Vector2(rect.end.x, rect.position.y)
	var c := rect.end
	var d := Vector2(rect.position.x, rect.end.y)
	for pair in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(pair[0], pair[1], color, 1.5, 5.0)


func _price(value: float) -> String:
	if instrument:
		return instrument.price_text(value)
	return Fmt.number(value, 1)


func _nice_step(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var magnitude := pow(10.0, floor(log(raw) / log(10.0)))
	for k in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if raw <= k * magnitude:
			return k * magnitude
	return 10.0 * magnitude


## 재생 중 값이 오르내린 자리를 오늘 칸 오른쪽에 궤적으로 남긴다.
func trace_point(t: float, price: float) -> void:
	live_trace.append(Vector2(trace_x(t), y_of(price)))


func trace_x(t: float) -> float:
	return today_x() + slot_width() * 0.9 + t / 3.0 * slot_width() * 2.4

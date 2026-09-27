class_name Patterns
extends RefCounted
## 일봉 차트 패턴. 판정은 모두 '마지막으로 마감된 봉' 기준이다.
## 하락 패턴은 가격을 뒤집은 차트에서 짝이 되는 상승 패턴을 찾는다.

const LABELS := {
	"hammer": "망치형",
	"shooting_star": "유성형",
	"bullish_engulfing": "상승장악형",
	"bearish_engulfing": "하락장악형",
	"golden_cross": "골든크로스",
	"dead_cross": "데드크로스",
	"double_bottom": "쌍바닥",
	"double_top": "쌍봉",
}

## 하락 패턴 → 뒤집어서 볼 상승 패턴.
const MIRROR_OF := {
	"shooting_star": "hammer",
	"bearish_engulfing": "bullish_engulfing",
	"dead_cross": "golden_cross",
	"double_top": "double_bottom",
}

## 패턴 → 손에 들어오는 스킬 카드.
const CARD_OF := {
	"hammer": "p_rebound",
	"shooting_star": "p_fall",
	"bullish_engulfing": "p_trend_up",
	"bearish_engulfing": "p_trend_down",
	"golden_cross": "p_golden",
	"dead_cross": "p_dead",
	"double_bottom": "p_w",
	"double_top": "p_m",
}


static func label(id: String) -> String:
	return LABELS.get(id, id)


## bars[0, end) 에서 마지막 봉(end - 1)에 완성된 패턴들.
static func detect(bars: Array, end: int) -> Array[String]:
	var window: Array = bars.slice(maxi(0, end - 45), end)
	var mirrored := _mirror(window)
	var found: Array[String] = []
	for id: String in LABELS:
		var ok := false
		if MIRROR_OF.has(id):
			ok = _bullish(MIRROR_OF[id], mirrored)
		else:
			ok = _bullish(id, window)
		if ok:
			found.append(id)
	return found


static func _bullish(id: String, c: Array) -> bool:
	match id:
		"hammer":
			return _hammer(c)
		"bullish_engulfing":
			return _engulfing(c)
		"golden_cross":
			return _golden_cross(c)
		"double_bottom":
			return _double_bottom(c)
	return false


static func _mirror(bars: Array) -> Array:
	var out := []
	for b: Bar in bars:
		out.append(Bar.new(b.date, -b.open, -b.low, -b.high, -b.close, b.estimated))
	return out


static func _average_body(c: Array, end: int, period := 10) -> float:
	var start := maxi(0, end - period)
	if end <= start:
		return 0.0001
	var total := 0.0
	for i in range(start, end):
		total += c[i].body()
	return maxf(total / (end - start), 0.0001)


static func _average_range(c: Array, end: int, period := 14) -> float:
	var start := maxi(0, end - period)
	if end <= start:
		return 0.0001
	var total := 0.0
	for i in range(start, end):
		total += c[i].span()
	return maxf(total / (end - start), 0.0001)


static func _declined_into(c: Array, i: int, lookback := 3) -> bool:
	return i - lookback >= 0 and c[i].close < c[i - lookback].close


## 하락 끝에 긴 아래꼬리를 달고 새 저점을 찍은 봉.
static func _hammer(c: Array) -> bool:
	var n := c.size()
	if n < 6:
		return false
	var cur: Bar = c[n - 1]
	var span := cur.span()
	return (
		span > 0.0
		and span >= _average_range(c, n - 1) * 0.9
		and cur.lower_shadow() >= span * 0.55
		and cur.upper_shadow() <= span * 0.2
		and cur.low < minf(c[n - 2].low, c[n - 3].low)
		and _declined_into(c, n - 2)
	)


## 하락 끝에 직전 음봉을 통째로 감싸는 양봉.
static func _engulfing(c: Array) -> bool:
	var n := c.size()
	if n < 6:
		return false
	var prev: Bar = c[n - 2]
	var cur: Bar = c[n - 1]
	var avg := _average_body(c, n - 2)
	return (
		prev.close < prev.open
		and cur.close > cur.open
		and prev.body() >= avg * 0.4
		and cur.body() >= avg * 1.1
		and cur.open <= prev.close
		and cur.close >= prev.open
		and _declined_into(c, n - 2)
	)


## 5일 평균이 20일 평균을 아래에서 위로 뚫는다.
static func _golden_cross(c: Array) -> bool:
	var n := c.size()
	var short := Market.moving_average(c, 5, n)
	var long := Market.moving_average(c, 20, n)
	var prev_short := Market.moving_average(c, 5, n - 1)
	var prev_long := Market.moving_average(c, 20, n - 1)
	if is_nan(short) or is_nan(long) or is_nan(prev_short) or is_nan(prev_long):
		return false
	return prev_short <= prev_long and short > long


static func _pivot_lows(c: Array, from: int, to: int, window := 2) -> Array[int]:
	var pivots: Array[int] = []
	for i in range(maxi(from, window), to - window + 1):
		var pivot := true
		for j in range(i - window, i + window + 1):
			if j == i:
				continue
			pivot = c[j].low >= c[i].low if j < i else c[j].low > c[i].low
			if not pivot:
				break
		if pivot:
			pivots.append(i)
	return pivots


static func _highest_high(c: Array, from: int, to: int) -> float:
	var high: float = c[from].high
	for i in range(from + 1, to + 1):
		high = maxf(high, c[i].high)
	return high


static func _lowest_low(c: Array, from: int, to: int) -> float:
	var low: float = c[from].low
	for i in range(from + 1, to + 1):
		low = minf(low, c[i].low)
	return low


## 비슷한 높이의 두 바닥 뒤 넥라인을 처음 종가로 뚫는다.
static func _double_bottom(c: Array) -> bool:
	var n := c.size()
	if n < 14:
		return false
	var last := n - 1
	var atr := _average_range(c, last)
	var pivots := _pivot_lows(c, maxi(0, n - 35), last - 1)
	if pivots.size() < 2:
		return false
	var second: int = pivots.back()
	for k in range(pivots.size() - 2, -1, -1):
		var first: int = pivots[k]
		if second - first < 4:
			continue
		var low_a: float = c[first].low
		var low_b: float = c[second].low
		var floor_low := minf(low_a, low_b)
		if absf(low_a - low_b) > atr * 0.8:
			continue
		if _lowest_low(c, first + 1, second - 1) < floor_low:
			continue
		var neck := _highest_high(c, first + 1, second - 1)
		if neck - maxf(low_a, low_b) < atr * 1.2:
			continue
		if second + 1 <= last and _lowest_low(c, second + 1, last) < floor_low:
			return false
		return c[last].close > neck and c[last - 1].close <= neck
	return false

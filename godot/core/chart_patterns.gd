class_name ChartPatterns
## 완성되면 한 진영에 스킬을 내려주는 차트 패턴.
##
## 판정은 모두 '방금 마감된 봉'(candles.back()) 기준이다.
## 하락 패턴은 가격을 뒤집은 차트에서 대응하는 상승 패턴을 찾는 식으로 판정한다.

enum Pattern {
	BULLISH_ENGULFING,
	HAMMER,
	THREE_WHITE_SOLDIERS,
	GOLDEN_CROSS,
	DOUBLE_BOTTOM,
	INVERSE_HEAD_AND_SHOULDERS,
	BEARISH_ENGULFING,
	SHOOTING_STAR,
	THREE_BLACK_CROWS,
	DEAD_CROSS,
	DOUBLE_TOP,
	HEAD_AND_SHOULDERS,
}

const LABELS := {
	Pattern.BULLISH_ENGULFING: "상승장악형",
	Pattern.HAMMER: "망치형",
	Pattern.THREE_WHITE_SOLDIERS: "적삼병",
	Pattern.GOLDEN_CROSS: "골든크로스",
	Pattern.DOUBLE_BOTTOM: "쌍바닥(W)",
	Pattern.INVERSE_HEAD_AND_SHOULDERS: "역헤드앤숄더",
	Pattern.BEARISH_ENGULFING: "하락장악형",
	Pattern.SHOOTING_STAR: "유성형",
	Pattern.THREE_BLACK_CROWS: "흑삼병",
	Pattern.DEAD_CROSS: "데드크로스",
	Pattern.DOUBLE_TOP: "쌍봉(M)",
	Pattern.HEAD_AND_SHOULDERS: "헤드앤숄더",
}

## 하락 패턴 → 뒤집어서 판정할 상승 패턴.
const MIRROR_OF := {
	Pattern.BEARISH_ENGULFING: Pattern.BULLISH_ENGULFING,
	Pattern.SHOOTING_STAR: Pattern.HAMMER,
	Pattern.THREE_BLACK_CROWS: Pattern.THREE_WHITE_SOLDIERS,
	Pattern.DEAD_CROSS: Pattern.GOLDEN_CROSS,
	Pattern.DOUBLE_TOP: Pattern.DOUBLE_BOTTOM,
	Pattern.HEAD_AND_SHOULDERS: Pattern.INVERSE_HEAD_AND_SHOULDERS,
}


static func label(pattern: int) -> String:
	return LABELS[pattern]


## 이 패턴이 완성되면 스킬을 얻는 진영.
static func faction(pattern: int) -> int:
	return War.Faction.BEAR if MIRROR_OF.has(pattern) else War.Faction.BULL


## 방금 마감된 봉에서 완성된 패턴들.
static func detect(candles: Array) -> Array:
	var mirrored := _mirror(candles)
	var found := []
	for pattern: int in Pattern.values():
		if MIRROR_OF.has(pattern):
			if _bullish(MIRROR_OF[pattern], mirrored):
				found.append(pattern)
		elif _bullish(pattern, candles):
			found.append(pattern)
	return found


static func matches(pattern: int, candles: Array) -> bool:
	if MIRROR_OF.has(pattern):
		return _bullish(MIRROR_OF[pattern], _mirror(candles))
	return _bullish(pattern, candles)


static func _bullish(pattern: int, c: Array) -> bool:
	match pattern:
		Pattern.BULLISH_ENGULFING:
			return _bullish_engulfing(c)
		Pattern.HAMMER:
			return _hammer(c)
		Pattern.THREE_WHITE_SOLDIERS:
			return _three_white_soldiers(c)
		Pattern.GOLDEN_CROSS:
			return _golden_cross(c)
		Pattern.DOUBLE_BOTTOM:
			return _double_bottom(c)
		Pattern.INVERSE_HEAD_AND_SHOULDERS:
			return _inverse_head_and_shoulders(c)
	return false


static func _mirror(candles: Array) -> Array:
	var out := []
	for c: Candle in candles:
		out.append(Candle.ohlc(c.index, -c.open, -c.low, -c.high, -c.close))
	return out


# ── 공통 계산 ──────────────────────────────────────────────────────

## candles[end - period, end) 몸통 평균 (최소 1).
static func _average_body(c: Array, end: int, period := 10) -> float:
	var start := maxi(0, end - period)
	if end <= start:
		return 1.0
	var sum := 0
	for i in range(start, end):
		sum += c[i].body()
	return maxf(1.0, float(sum) / (end - start))


## candles[end - period, end) 고저폭 평균 (최소 1). 패턴 기준을 변동성에 맞춘다.
static func _average_range(c: Array, end: int, period := 14) -> float:
	var start := maxi(0, end - period)
	if end <= start:
		return 1.0
	var sum := 0
	for i in range(start, end):
		sum += c[i].span()
	return maxf(1.0, float(sum) / (end - start))


## i번째 봉까지 하락 추세였는지.
static func _declined_into(c: Array, i: int, lookback := 3) -> bool:
	return i - lookback >= 0 and c[i].close < c[i - lookback].close


## [from, to] 구간에서 좌우 window개 봉보다 저가가 낮은 봉 (to까지 확인 가능한 것만).
static func _pivot_lows(c: Array, from: int, to: int, window := 2) -> Array:
	var pivots := []
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


static func _highest_high(c: Array, from: int, to: int) -> int:
	var high: int = c[from].high
	for i in range(from + 1, to + 1):
		high = maxi(high, c[i].high)
	return high


static func _lowest_low(c: Array, from: int, to: int) -> int:
	var low: int = c[from].low
	for i in range(from + 1, to + 1):
		low = mini(low, c[i].low)
	return low


## 마지막 봉이 넥라인을 처음 종가로 뚫었는지.
static func _breaks_out(c: Array, neck: int) -> bool:
	var last := c.size() - 1
	return c[last].close > neck and c[last - 1].close <= neck


# ── 상승 패턴 ──────────────────────────────────────────────────────

## 하락 끝에 직전 음봉을 통째로 감싸는 양봉.
static func _bullish_engulfing(c: Array) -> bool:
	var n := c.size()
	if n < 5:
		return false
	var prev: Candle = c[n - 2]
	var cur: Candle = c[n - 1]
	var avg := _average_body(c, n - 2)
	return (
		prev.is_bearish()
		and cur.is_bullish()
		and prev.body() >= avg * 0.5
		and cur.body() >= avg * 1.2
		and cur.body() > prev.body()
		and cur.open <= prev.close
		and cur.close >= prev.open
		and _declined_into(c, n - 2)
	)


## 하락 끝에 긴 아래꼬리를 달고 새 저점을 찍은 봉.
static func _hammer(c: Array) -> bool:
	var n := c.size()
	if n < 5:
		return false
	var cur: Candle = c[n - 1]
	var span := cur.span()
	return (
		span > 0
		and span >= _average_range(c, n - 1)
		and cur.lower_shadow() >= span * 0.6
		and cur.upper_shadow() <= span * 0.15
		and cur.low < mini(c[n - 2].low, c[n - 3].low)
		and _declined_into(c, n - 2)
	)


## 몸통이 실한 양봉 세 개가 종가를 높이며 이어진다.
static func _three_white_soldiers(c: Array) -> bool:
	var n := c.size()
	if n < 4:
		return false
	var avg := _average_body(c, n - 3)
	for i in range(n - 3, n):
		var k: Candle = c[i]
		if not k.is_bullish() or k.body() < avg * 0.8 or k.upper_shadow() * 2 > k.body():
			return false
		if i > n - 3 and (k.close <= c[i - 1].close or k.open < c[i - 1].open):
			return false
	return true


## 5봉 이동평균이 20봉 이동평균을 아래에서 위로 뚫는다.
static func _golden_cross(c: Array) -> bool:
	var n := c.size()
	var short := Candle.moving_average(c, 5, n)
	var long := Candle.moving_average(c, 20, n)
	var prev_short := Candle.moving_average(c, 5, n - 1)
	var prev_long := Candle.moving_average(c, 20, n - 1)
	if is_nan(short) or is_nan(long) or is_nan(prev_short) or is_nan(prev_long):
		return false
	return prev_short <= prev_long and short > long


## 비슷한 높이의 두 바닥 뒤 넥라인 돌파.
static func _double_bottom(c: Array) -> bool:
	var n := c.size()
	if n < 12:
		return false
	var last := n - 1
	var atr := _average_range(c, last)
	var pivots := _pivot_lows(c, maxi(0, n - 30), last - 1)
	if pivots.size() < 2:
		return false
	var second: int = pivots.back()
	for k in range(pivots.size() - 2, -1, -1):
		var first: int = pivots[k]
		if second - first < 3:
			continue
		var low_a: int = c[first].low
		var low_b: int = c[second].low
		var floor_low := mini(low_a, low_b)
		if absi(low_a - low_b) > atr * 0.8:
			continue
		# 두 바닥 사이에 더 깊은 바닥이 있으면 W가 아니다.
		if _lowest_low(c, first + 1, second - 1) < floor_low:
			continue
		var neck := _highest_high(c, first + 1, second - 1)
		if neck - maxi(low_a, low_b) < atr * 1.5:
			continue
		if _lowest_low(c, second + 1, last) < floor_low:
			return false
		return _breaks_out(c, neck)
	return false


## 왼어깨·머리·오른어깨 세 바닥 (머리가 가장 깊음) 뒤 넥라인 돌파.
static func _inverse_head_and_shoulders(c: Array) -> bool:
	var n := c.size()
	if n < 16:
		return false
	var last := n - 1
	var atr := _average_range(c, last)
	var pivots := _pivot_lows(c, maxi(0, n - 40), last - 1)
	if pivots.size() < 3:
		return false
	var left: int = pivots[pivots.size() - 3]
	var head: int = pivots[pivots.size() - 2]
	var right: int = pivots.back()
	var left_low: int = c[left].low
	var head_low: int = c[head].low
	var right_low: int = c[right].low
	if head_low > mini(left_low, right_low) - atr * 0.5:
		return false
	if absi(left_low - right_low) > atr:
		return false
	var neck := _highest_high(c, left + 1, right - 1)
	if neck - maxi(left_low, right_low) < atr:
		return false
	if _lowest_low(c, right + 1, last) < mini(left_low, right_low):
		return false
	return _breaks_out(c, neck)

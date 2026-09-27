extends TestCase

const P := ChartPatterns.Pattern


## [open, high, low, close] 목록을 봉으로.
func _candles(ohlc: Array) -> Array:
	var out := []
	for i in ohlc.size():
		out.append(Candle.ohlc(i, ohlc[i][0], ohlc[i][1], ohlc[i][2], ohlc[i][3]))
	return out


## 가격축을 뒤집은 차트 (상승 패턴 → 하락 패턴).
func _flipped(source: Array) -> Array:
	var out := []
	for c: Candle in source:
		out.append(Candle.ohlc(c.index, 20000 - c.open, 20000 - c.low, 20000 - c.high, 20000 - c.close))
	return out


func _engulfing() -> Array:
	return _candles([[10100, 10110, 10040, 10050], [10050, 10060, 9990, 10000],
		[10000, 10010, 9940, 9950], [9950, 9960, 9890, 9900], [9900, 10010, 9890, 10000]])


func _hammer() -> Array:
	return _candles([[10100, 10110, 10050, 10060], [10060, 10070, 10010, 10020],
		[10020, 10030, 9970, 9980], [9980, 9990, 9930, 9940], [9940, 9965, 9800, 9960]])


func _soldiers() -> Array:
	return _candles([[10000, 10025, 9990, 10020], [10020, 10075, 10015, 10070],
		[10070, 10125, 10065, 10120], [10120, 10185, 10110, 10180]])


## 15봉 보합, 5봉 하락 뒤 급등 → 5봉선이 20봉선을 뚫는다.
func _cross() -> Array:
	var rows := []
	for i in 15:
		rows.append([10000, 10000, 10000, 10000])
	for i in 5:
		rows.append([9900, 9900, 9900, 9900])
	rows.append([9900, 10400, 9900, 10400])
	return _candles(rows)


func _double_bottom() -> Array:
	return _candles([
		[10100, 10110, 10070, 10080], [10080, 10090, 10030, 10040], [10040, 10050, 9990, 10000],
		[10000, 10010, 9950, 9960], [9960, 9970, 9900, 9930], [9930, 9990, 9920, 9980],
		[9980, 10040, 9970, 10030], [10030, 10060, 10020, 10050], [10050, 10055, 9990, 10000],
		[10000, 10005, 9940, 9950], [9950, 9960, 9905, 9930], [9930, 9980, 9920, 9970],
		[9970, 10030, 9960, 10020], [10020, 10050, 10010, 10040], [10040, 10110, 10030, 10100]])


func _inverse_head_and_shoulders() -> Array:
	return _candles([
		[10100, 10110, 10070, 10080], [10080, 10090, 10030, 10040], [10040, 10050, 9980, 9990],
		[9990, 10000, 9900, 9930], [9930, 10000, 9920, 9990], [9990, 10060, 9980, 10040],
		[10040, 10045, 9940, 9950], [9950, 9955, 9830, 9840], [9840, 9850, 9780, 9810],
		[9810, 9910, 9800, 9900], [9900, 10050, 9890, 10000], [10000, 10010, 9950, 9960],
		[9960, 9970, 9885, 9920], [9920, 9990, 9890, 9980], [9980, 10040, 9970, 10030],
		[10030, 10055, 10020, 10050], [10050, 10130, 10040, 10120]])


func test_bullish_patterns() -> void:
	check(ChartPatterns.matches(P.BULLISH_ENGULFING, _engulfing()), "상승장악형")
	check(ChartPatterns.matches(P.HAMMER, _hammer()), "망치형")
	check(ChartPatterns.matches(P.THREE_WHITE_SOLDIERS, _soldiers()), "적삼병")
	check(ChartPatterns.matches(P.GOLDEN_CROSS, _cross()), "골든크로스")
	check(ChartPatterns.matches(P.DOUBLE_BOTTOM, _double_bottom()), "쌍바닥")
	var found := ChartPatterns.detect(_inverse_head_and_shoulders())
	check(found.has(P.INVERSE_HEAD_AND_SHOULDERS), "역헤드앤숄더")
	check(not found.has(P.DOUBLE_BOTTOM), "머리가 깊으면 쌍바닥이 아니다")


func test_near_misses() -> void:
	var weak := _engulfing()
	weak[4] = Candle.ohlc(4, 9900, 9945, 9890, 9940)
	check(not ChartPatterns.matches(P.BULLISH_ENGULFING, weak), "감싸지 못한 양봉")
	var broken := _soldiers()
	broken[3] = Candle.ohlc(3, 10120, 10130, 10060, 10070)
	check(not ChartPatterns.matches(P.THREE_WHITE_SOLDIERS, broken), "세 번째가 음봉")
	check(not ChartPatterns.matches(P.GOLDEN_CROSS, _cross().slice(0, 20)), "교차 전")
	check(not ChartPatterns.matches(P.DOUBLE_BOTTOM, _double_bottom().slice(0, 14)), "돌파 전")


func test_bearish_patterns_are_mirrors() -> void:
	var cases := {
		P.BEARISH_ENGULFING: _engulfing(),
		P.SHOOTING_STAR: _hammer(),
		P.THREE_BLACK_CROWS: _soldiers(),
		P.DEAD_CROSS: _cross(),
		P.DOUBLE_TOP: _double_bottom(),
		P.HEAD_AND_SHOULDERS: _inverse_head_and_shoulders(),
	}
	for pattern: int in cases:
		check(ChartPatterns.matches(pattern, _flipped(cases[pattern])), ChartPatterns.label(pattern))
		check(not ChartPatterns.matches(pattern, cases[pattern]), ChartPatterns.label(pattern) + " (원본)")


func test_bull_charts_have_no_bear_patterns() -> void:
	for chart in [_engulfing(), _hammer(), _soldiers(), _cross(), _double_bottom(), _inverse_head_and_shoulders()]:
		var found := ChartPatterns.detect(chart)
		check(not found.is_empty())
		for pattern: int in found:
			eq(ChartPatterns.faction(pattern), War.Faction.BULL, ChartPatterns.label(pattern))

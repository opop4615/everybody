class_name Candle
extends RefCounted
## 봉 하나 (게임에서는 5분봉).

var index: int
var open: int
var high: int
var low: int
var close: int
var volume := 0


func _init(p_index := 0, p_open := 0) -> void:
	index = p_index
	open = p_open
	high = p_open
	low = p_open
	close = p_open


## 테스트나 차트 초기값용 완성된 봉.
static func ohlc(p_index: int, p_open: int, p_high: int, p_low: int, p_close: int) -> Candle:
	var candle := Candle.new(p_index, p_open)
	candle.high = p_high
	candle.low = p_low
	candle.close = p_close
	return candle


func update(price: int, quantity: int) -> void:
	high = maxi(high, price)
	low = mini(low, price)
	close = price
	volume += quantity


func is_bullish() -> bool:
	return close > open


func is_bearish() -> bool:
	return close < open


func body() -> int:
	return absi(close - open)


func span() -> int:
	return high - low


func upper_shadow() -> int:
	return high - maxi(open, close)


func lower_shadow() -> int:
	return mini(open, close) - low


## candles[end - period, end) 종가의 단순이동평균. 봉이 모자라면 NAN.
static func moving_average(candles: Array, period: int, end := -1) -> float:
	var stop := candles.size() if end < 0 else end
	if stop < period or period <= 0:
		return NAN
	var sum := 0
	for i in range(stop - period, stop):
		sum += candles[i].close
	return float(sum) / period

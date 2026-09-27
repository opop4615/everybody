class_name Bar
extends RefCounted
## 하루치 시세 한 줄 (일봉).

var date: String
var open: float
var high: float
var low: float
var close: float
## 시가·고가·저가를 종가로 추정한 봉인지.
var estimated: bool


func _init(p_date := "", p_open := 0.0, p_high := 0.0, p_low := 0.0, p_close := 0.0, p_estimated := false) -> void:
	date = p_date
	open = p_open
	high = p_high
	low = p_low
	close = p_close
	estimated = p_estimated


func is_up() -> bool:
	return close >= open


func body() -> float:
	return absf(close - open)


func span() -> float:
	return high - low


func upper_shadow() -> float:
	return high - maxf(open, close)


func lower_shadow() -> float:
	return minf(open, close) - low


## 장중에 지나가는 네 점. 양봉은 시가 → 저가 → 고가 → 종가, 음봉은 시가 → 고가 → 저가 → 종가.
func path() -> PackedFloat64Array:
	if is_up():
		return PackedFloat64Array([open, low, high, close])
	return PackedFloat64Array([open, high, low, close])


## "3.19"
func short_date() -> String:
	var parts := date.split("-")
	if parts.size() < 3:
		return date
	return "%d.%d" % [int(parts[1]), int(parts[2])]


## "2020.03.19 (목)"
func long_date() -> String:
	return "%s (%s)" % [date.replace("-", "."), weekday_name()]


func weekday_name() -> String:
	var info := Time.get_datetime_dict_from_datetime_string(date + "T00:00:00", true)
	return ["일", "월", "화", "수", "목", "금", "토"][int(info.get("weekday", 0))]

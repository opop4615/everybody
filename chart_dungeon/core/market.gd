class_name Market
extends RefCounted
## data/market/<상품>.csv 를 읽는다. 형식: date,open,high,low,close,est

static var root := "res://data/market"
static var _cache := {}


static func bars(id: String) -> Array[Bar]:
	if _cache.has(id):
		return _cache[id]
	var list: Array[Bar] = []
	var path := root.path_join(id + ".csv")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("시세 파일이 없다: " + path)
		return list
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 5 or row[0].is_empty():
			continue
		var estimated := row.size() > 5 and row[5].strip_edges() == "1"
		list.append(Bar.new(row[0], float(row[1]), float(row[2]), float(row[3]), float(row[4]), estimated))
	_cache[id] = list
	return list


## date 이후 첫 거래일의 위치. 없으면 -1.
static func index_on_or_after(id: String, date: String) -> int:
	var list := bars(id)
	for i in list.size():
		if list[i].date >= date:
			return i
	return -1


## bars[end - period, end) 의 평균 고저폭.
static func average_range(list: Array[Bar], end: int, period := 10) -> float:
	var start := maxi(0, end - period)
	if end <= start:
		return 1.0
	var total := 0.0
	for i in range(start, end):
		total += list[i].span()
	return maxf(total / (end - start), 0.0001)


## bars[end - period, end) 종가 평균. 모자라면 NAN.
static func moving_average(list: Array, period: int, end: int) -> float:
	if end < period or period <= 0 or end > list.size():
		return NAN
	var total := 0.0
	for i in range(end - period, end):
		total += list[i].close
	return total / period

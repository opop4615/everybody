extends TestCase
## 시세 파일과 패턴 판정.


func test_market_files_load_and_are_consistent() -> void:
	for inst in Instrument.all():
		var bars := Market.bars(inst.id)
		check(bars.size() > 200, "%s 일봉이 너무 적다" % inst.id)
		for i in bars.size():
			var b := bars[i]
			check(b.low <= minf(b.open, b.close) + 0.0001, "%s %s 저가가 몸통보다 높다" % [inst.id, b.date])
			check(b.high >= maxf(b.open, b.close) - 0.0001, "%s %s 고가가 몸통보다 낮다" % [inst.id, b.date])
			if i > 0:
				check(b.date > bars[i - 1].date, "%s 날짜가 거꾸로다" % inst.id)


func test_known_days() -> void:
	var wti := Market.bars("wti")
	var i := Market.index_on_or_after("wti", "2020-04-20")
	eq(wti[i].date, "2020-04-20")
	check(wti[i].close < -30.0, "4월 20일 WTI는 마이너스로 끝났다")
	var usd := Market.bars("usdkrw")
	var j := Market.index_on_or_after("usdkrw", "2020-03-19")
	check(usd[j].close > 1200.0 and usd[j].close < 1300.0, "3월 19일 원/달러는 1,200원대")


func test_bar_path_order() -> void:
	var up := Bar.new("2020-01-02", 10, 14, 8, 12)
	eq(Array(up.path()), [10.0, 8.0, 14.0, 12.0], "양봉은 시가 저가 고가 종가")
	var down := Bar.new("2020-01-02", 12, 14, 8, 10)
	eq(Array(down.path()), [12.0, 14.0, 8.0, 10.0], "음봉은 시가 고가 저가 종가")
	eq(up.weekday_name(), "목", "2020년 1월 2일은 목요일")
	eq(up.short_date(), "1.2")


func test_hammer_detected() -> void:
	var bars: Array = []
	var price := 100.0
	for i in 12:
		bars.append(Bar.new("d%02d" % i, price, price + 1.0, price - 3.0, price - 2.0))
		price -= 2.0
	bars.append(Bar.new("d12", price, price + 0.5, price - 12.0, price + 0.2))
	check(Patterns.detect(bars, bars.size()).has("hammer"), "긴 아래꼬리 망치형")
	var mirrored: Array = []
	for b: Bar in bars:
		mirrored.append(Bar.new(b.date, -b.open, -b.low, -b.high, -b.close))
	check(Patterns.detect(mirrored, mirrored.size()).has("shooting_star"), "뒤집으면 유성형")


func test_fmt() -> void:
	eq(Fmt.number(1234567.891, 2), "1,234,567.89")
	eq(Fmt.number(-1245.7, 1), "-1,245.7")
	eq(Fmt.money(3085.5), "3,085.5만")
	eq(Fmt.signed_money(-39.0), "-39만")
	eq(Fmt.signed_money(246.54), "+246.5만")

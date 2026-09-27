class_name Fmt
extends RefCounted
## 숫자 표기.


## 1234.5 → "1,234.5"
static func number(value: float, digits := 0) -> String:
	var negative := value < 0.0
	var text := ("%." + str(digits) + "f") % absf(value)
	var whole := text
	var fraction := ""
	var dot := text.find(".")
	if dot >= 0:
		whole = text.substr(0, dot)
		fraction = text.substr(dot)
	var grouped := ""
	var count := 0
	for i in range(whole.length() - 1, -1, -1):
		grouped = whole[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "," + grouped
	return ("-" if negative else "") + grouped + fraction


## 만원 단위 금액 → "3,085만", "1.2억". 소수 한 자리까지.
static func money(manwon: float) -> String:
	var rounded := snappedf(manwon, 0.1)
	if absf(rounded) >= 10000.0:
		return number(rounded / 10000.0, 2) + "억"
	if is_equal_approx(rounded, roundf(rounded)):
		return number(rounded, 0) + "만"
	return number(rounded, 1) + "만"


## 부호를 붙인 금액 → "+246.5만", "-39만".
static func signed_money(manwon: float) -> String:
	var rounded := snappedf(manwon, 0.1)
	if rounded > 0.0:
		return "+" + money(rounded)
	if rounded < 0.0:
		return "-" + money(-rounded)
	return "0"


static func percent(ratio: float) -> String:
	return "%d%%" % roundi(ratio * 100.0)

class_name Krx
## 한국거래소(KRX) 가격 규칙: 호가가격단위와 가격제한폭(±30%).


## 2023년 개편된 유가증권·코스닥 공통 호가가격단위.
static func tick_size(price: int) -> int:
	if price < 2000:
		return 1
	if price < 5000:
		return 5
	if price < 20000:
		return 10
	if price < 50000:
		return 50
	if price < 200000:
		return 100
	if price < 500000:
		return 500
	return 1000


## price 이하에서 가장 가까운 유효 호가.
static func floor_to_tick(price: int) -> int:
	return price - price % tick_size(price)


## price 이상에서 가장 가까운 유효 호가.
static func ceil_to_tick(price: int) -> int:
	var floored := floor_to_tick(price)
	return price if floored == price else next_tick(floored)


## 한 호가 위.
static func next_tick(price: int) -> int:
	return price + tick_size(price)


## 한 호가 아래.
static func prev_tick(price: int) -> int:
	return floor_to_tick(price - 1)


## price에서 n호가 떨어진 가격 (n이 음수면 아래로).
static func shift_ticks(price: int, n: int) -> int:
	var p := price
	for i in absi(n):
		p = next_tick(p) if n > 0 else prev_tick(p)
	return p


## from에서 to까지 몇 호가인지 (to가 아래면 음수).
static func ticks_between(from: int, to: int) -> int:
	var count := 0
	var p := from
	while p < to:
		p = next_tick(p)
		count += 1
	while p > to:
		p = prev_tick(p)
		count -= 1
	return count


## 상한가: 기준가 +30% 이내의 최고 호가.
@warning_ignore("integer_division")
static func upper_limit(base: int) -> int:
	return floor_to_tick(base + base * 3 / 10)


## 하한가: 기준가 -30% 이내의 최저 호가.
@warning_ignore("integer_division")
static func lower_limit(base: int) -> int:
	return ceil_to_tick(base - base * 3 / 10)


## 1,234,567 형태의 천 단위 구분 문자열.
static func format_number(value: float) -> String:
	var digits := str(absi(roundi(value)))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out


## +1.23% 형태.
static func signed_percent(rate: float) -> String:
	return "%s%.2f%%" % ["+" if rate > 0 else "", rate * 100.0]


## +1,234 형태.
static func signed_number(value: int) -> String:
	return ("+" if value > 0 else "") + format_number(value)


## 3.4억 / 5,200만 / 3,000 처럼 짧게.
@warning_ignore("integer_division")
static func compact_won(won: int) -> String:
	var abs_won := absi(won)
	var sign_text := "-" if won < 0 else ""
	if abs_won >= 100000000:
		return "%s%.1f억" % [sign_text, abs_won / 100000000.0]
	if abs_won >= 10000:
		return "%s%s만" % [sign_text, format_number(abs_won / 10000)]
	return sign_text + format_number(abs_won)

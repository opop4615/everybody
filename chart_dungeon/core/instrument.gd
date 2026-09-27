class_name Instrument
extends RefCounted
## 거래 상품. 손익 단위는 모두 만원이다.

var id: String
var name: String
## 지도와 카드에 찍히는 한 글자.
var glyph: String
## 가격 단위 ("원", "달러").
var unit: String
## 가격이 1 움직일 때 1계약의 손익 (만원).
var multiplier: float
## 1계약을 열 때 묶이는 증거금 (만원). 변동성이 클수록 크다.
var margin: float
var digits: int
var spec: String
var source: String


static func of(p_id: String) -> Instrument:
	for item in all():
		if item.id == p_id:
			return item
	push_error("모르는 상품 " + p_id)
	return null


static func all() -> Array[Instrument]:
	var list: Array[Instrument] = []
	list.append(_make("usdkrw", "미국달러 선물", "$", "원", 1.0, 40.0, 1,
		"1계약 1만 달러 · 1원 움직이면 1만원",
		"미 연준 H.10 원/달러 (뉴욕 정오 기준). 시가·고가·저가는 종가로 추정"))
	list.append(_make("gold", "금 선물", "금", "달러", 1.2, 110.0, 1,
		"1계약 10온스 · 1달러 움직이면 1.2만원 (1달러 = 1,200원)",
		"XAUUSD 일봉 (MT4)"))
	list.append(_make("wti", "WTI 원유 선물", "유", "달러", 12.0, 100.0, 2,
		"1계약 100배럴 · 1달러 움직이면 12만원 (1달러 = 1,200원)",
		"미 에너지정보청 WTI 쿠싱 현물. 시가·고가·저가는 종가로 추정"))
	return list


static func _make(p_id: String, p_name: String, p_glyph: String, p_unit: String, p_multiplier: float,
		p_margin: float, p_digits: int, p_spec: String, p_source: String) -> Instrument:
	var item := Instrument.new()
	item.id = p_id
	item.name = p_name
	item.glyph = p_glyph
	item.unit = p_unit
	item.multiplier = p_multiplier
	item.margin = p_margin
	item.digits = p_digits
	item.spec = p_spec
	item.source = p_source
	return item


## 증거금 금액으로 살 수 있는 계약 수 (최소 1).
func contracts_for(budget: float) -> int:
	return maxi(1, int(floor(budget / margin)))


func price_text(price: float) -> String:
	return Fmt.number(price, digits)

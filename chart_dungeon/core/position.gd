class_name Position
extends RefCounted
## 한 상품의 순포지션. 양수면 롱, 음수면 숏.
##
## avg 는 들어간 평균 가격(보여 주기와 거래 손익용),
## basis 는 마지막 정산 가격이다. 선물은 매일 장이 끝나면 종가로 손익을 계좌에 넣고(일일정산)
## basis 를 종가로 옮긴다.

var qty := 0
var avg := 0.0
var basis := 0.0


func direction() -> int:
	return signi(qty)


func is_flat() -> bool:
	return qty == 0


## delta 계약을 price 에 체결한다. 계좌에 바로 들어갈 실현 손익(만원, basis 기준)을 돌려준다.
func fill(delta: int, price: float, multiplier: float) -> float:
	if delta == 0:
		return 0.0
	var realized := 0.0
	if qty == 0 or signi(delta) == signi(qty):
		var total := absi(qty) + absi(delta)
		avg = (avg * absi(qty) + price * absi(delta)) / total
		basis = (basis * absi(qty) + price * absi(delta)) / total
		qty += delta
		return 0.0
	var closing := mini(absi(delta), absi(qty))
	realized = (price - basis) * closing * signi(qty) * multiplier
	var remainder := absi(delta) - closing
	qty += signi(delta) * closing
	if qty == 0:
		avg = 0.0
		basis = 0.0
	if remainder > 0:
		qty = signi(delta) * remainder
		avg = price
		basis = price
	return realized


## 지금 가격으로 본 미정산 손익 (basis 기준).
func unrealized(price: float, multiplier: float) -> float:
	return (price - basis) * qty * multiplier


## 들어간 가격부터 따진 평가 손익 (보여 주기용).
func open_profit(price: float, multiplier: float) -> float:
	return (price - avg) * qty * multiplier


## 종가로 일일정산. 계좌에 넣을 금액을 돌려준다.
func settle(close: float, multiplier: float) -> float:
	var amount := unrealized(close, multiplier)
	if qty != 0:
		basis = close
	return amount


func copy() -> Position:
	var other := Position.new()
	other.qty = qty
	other.avg = avg
	other.basis = basis
	return other

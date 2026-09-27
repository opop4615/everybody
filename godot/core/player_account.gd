class_name PlayerAccount
extends RefCounted
## 플레이어 계좌. 포지션은 음수(공매도)도 가능하다.

var cash: int
var position := 0
var average_price := 0.0
var realized := 0


func _init(p_cash: int) -> void:
	cash = p_cash


func apply(side: int, price: int, quantity: int) -> void:
	var signed := quantity if side == OrderBook.Side.BUY else -quantity
	cash -= signed * price
	if position == 0 or signi(position) == signi(signed):
		var size := absi(position)
		average_price = (average_price * size + price * quantity) / (size + quantity)
		position += signed
		return
	var closing := mini(quantity, absi(position))
	realized += roundi((price - average_price) * closing * signi(position))
	position += signi(signed) * closing
	var rest := quantity - closing
	if position == 0:
		average_price = 0.0
	if rest > 0:
		position = signi(signed) * rest
		average_price = price


func equity(price: int) -> int:
	return cash + position * price


func unrealized(price: int) -> int:
	return roundi((price - average_price) * position)

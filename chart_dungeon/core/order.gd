class_name Order
extends RefCounted
## 포지션을 정리하는 대기 주문. 체결될 때까지(또는 포지션이 없어질 때까지) 날을 넘겨 남는다.

enum Kind { STOP, TAKE, TRAIL }

var kind: int
## 지키는 포지션 방향. +1 이면 롱을 정리하는 주문, -1 이면 숏을 정리하는 주문.
var dir: int
var price: float
## 트레일링 스톱: 가장 좋았던 가격에서 떨어진 거리.
var trail := 0.0
var best := 0.0
## 사용자가 차트에서 끌어 옮길 수 있는지.
var movable := true


static func stop(p_dir: int, p_price: float) -> Order:
	var order := Order.new()
	order.kind = Kind.STOP
	order.dir = p_dir
	order.price = p_price
	return order


static func take(p_dir: int, p_price: float) -> Order:
	var order := Order.new()
	order.kind = Kind.TAKE
	order.dir = p_dir
	order.price = p_price
	return order


static func trailing(p_dir: int, from_price: float, distance: float) -> Order:
	var order := Order.new()
	order.kind = Kind.TRAIL
	order.dir = p_dir
	order.trail = distance
	order.best = from_price
	order.price = from_price - p_dir * distance
	order.movable = false
	return order


func label() -> String:
	match kind:
		Kind.STOP:
			return "손절"
		Kind.TAKE:
			return "익절"
	return "트레일링"


## 이 가격에 이미 닿아 있는지 (시가 갭 확인용).
func hit_at(value: float) -> bool:
	if kind == Kind.TAKE:
		return value >= price if dir > 0 else value <= price
	return value <= price if dir > 0 else value >= price


## a 에서 b 로 한 방향으로 움직이는 동안 닿는지.
func crossed(a: float, b: float) -> bool:
	if kind == Kind.TAKE:
		if dir > 0:
			return a < price and b >= price
		return a > price and b <= price
	if dir > 0:
		return a > price and b <= price
	return a < price and b >= price


## 트레일링 스톱이 유리한 쪽으로 간 가격을 따라온다.
func follow(value: float) -> void:
	if kind != Kind.TRAIL:
		return
	if dir > 0 and value > best:
		best = value
		price = maxf(price, best - trail)
	elif dir < 0 and value < best:
		best = value
		price = minf(price, best + trail)

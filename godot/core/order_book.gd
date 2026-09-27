class_name OrderBook
extends RefCounted
## 가격-시간 우선 원칙으로 체결하는 호가창.

enum Side { BUY, SELL }

## 가격이 없음을 뜻한다 (실제 호가는 항상 양수).
const NO_PRICE := 0


## 호가창에 걸려 있는 지정가 주문.
class Order:
	var id: int
	var side: int
	var price: int
	var remaining: int
	var is_player: bool
	## 주문 주체 (LP, 나, 매수청구, 매수군 ...)
	var tag: String

	func _init(p_id: int, p_side: int, p_price: int, p_remaining: int, p_is_player: bool, p_tag: String) -> void:
		id = p_id
		side = p_side
		price = p_price
		remaining = p_remaining
		is_player = p_is_player
		tag = p_tag


## 체결 한 건. aggressor는 호가를 먹은(시장가·교차 지정가) 쪽.
class Fill:
	var price: int
	var quantity: int
	var aggressor: int
	var taker_is_player: bool
	var maker_is_player: bool

	func _init(p_price: int, p_quantity: int, p_aggressor: int, p_taker: bool, p_maker: bool) -> void:
		price = p_price
		quantity = p_quantity
		aggressor = p_aggressor
		taker_is_player = p_taker
		maker_is_player = p_maker


## 화면에 그릴 호가 한 칸.
class BookLevel:
	var price: int
	var quantity: int
	## 그중 내 주문
	var player_quantity: int
	## 그중 LP·플레이어가 아닌 특수 물량 (매수청구가 벽, 스킬 벽 등)
	var wall_quantity: int
	var wall_tag: String

	func _init(p_price: int) -> void:
		price = p_price


var _levels := {Side.BUY: {}, Side.SELL: {}}
## 둘 다 오름차순. 최우선 매수호가는 _bid_prices 맨 뒤, 최우선 매도호가는 _ask_prices 맨 앞.
var _bid_prices: Array[int] = []
var _ask_prices: Array[int] = []
var _orders := {}
var _next_id := 1


static func opposite(side: int) -> int:
	return Side.SELL if side == Side.BUY else Side.BUY


func _prices(side: int) -> Array[int]:
	return _bid_prices if side == Side.BUY else _ask_prices


func best_bid() -> int:
	return NO_PRICE if _bid_prices.is_empty() else _bid_prices.back()


func best_ask() -> int:
	return NO_PRICE if _ask_prices.is_empty() else _ask_prices.front()


## side 방향 최우선 호가 (없으면 NO_PRICE).
func best(side: int) -> int:
	return best_bid() if side == Side.BUY else best_ask()


## 지정가 주문. 반대 호가와 교차하면 먼저 체결하고 남은 수량만 호가창에 쌓는다.
## {"fills": Array[Fill], "resting": Order 또는 null}
func place_limit(side: int, price: int, quantity: int, is_player := false, tag := "") -> Dictionary:
	var fills := _match(side, quantity, price, is_player)
	var left := quantity - total_quantity_of(fills)
	var resting: Order = null
	if left > 0:
		resting = Order.new(_next_id, side, price, left, is_player, tag)
		_next_id += 1
		var levels: Dictionary = _levels[side]
		if not levels.has(price):
			levels[price] = []
			var prices := _prices(side)
			prices.insert(prices.bsearch(price), price)
		levels[price].append(resting)
		_orders[resting.id] = resting
	return {"fills": fills, "resting": resting}


## 시장가 주문. limit(>0)을 주면 그 가격을 넘어서는 호가는 먹지 않는다.
func place_market(side: int, quantity: int, limit := NO_PRICE, is_player := false) -> Array:
	return _match(side, quantity, limit, is_player)


func _match(side: int, quantity: int, limit: int, is_player: bool) -> Array:
	var opp := opposite(side)
	var opp_levels: Dictionary = _levels[opp]
	var opp_prices := _prices(opp)
	var fills := []
	var left := quantity
	while left > 0 and not opp_prices.is_empty():
		var price: int = opp_prices.front() if side == Side.BUY else opp_prices.back()
		if limit != NO_PRICE and (price > limit if side == Side.BUY else price < limit):
			break
		var queue: Array = opp_levels[price]
		while left > 0 and not queue.is_empty():
			var maker: Order = queue.front()
			var qty := mini(left, maker.remaining)
			maker.remaining -= qty
			left -= qty
			fills.append(Fill.new(price, qty, side, is_player, maker.is_player))
			if maker.remaining == 0:
				queue.pop_front()
				_orders.erase(maker.id)
		if queue.is_empty():
			opp_levels.erase(price)
			if side == Side.BUY:
				opp_prices.pop_front()
			else:
				opp_prices.pop_back()
	return fills


## 조건에 맞는 주문을 모두 취소하고 취소한 건수를 돌려준다.
func cancel_where(test: Callable) -> int:
	var targets := []
	for order in _orders.values():
		if test.call(order):
			targets.append(order)
	for order: Order in targets:
		var levels: Dictionary = _levels[order.side]
		var queue: Array = levels.get(order.price, [])
		queue.erase(order)
		if queue.is_empty() and levels.has(order.price):
			levels.erase(order.price)
			_prices(order.side).erase(order.price)
		_orders.erase(order.id)
	return targets.size()


func quantity_at(side: int, price: int) -> int:
	var total := 0
	for order: Order in _levels[side].get(price, []):
		total += order.remaining
	return total


func player_quantity_at(side: int, price: int) -> int:
	var total := 0
	for order: Order in _levels[side].get(price, []):
		if order.is_player:
			total += order.remaining
	return total


## 최우선 호가부터 count개 칸.
func levels(side: int, count: int) -> Array:
	var prices := _prices(side)
	var result := []
	var n := mini(count, prices.size())
	for i in n:
		var price: int = prices[prices.size() - 1 - i] if side == Side.BUY else prices[i]
		var level := BookLevel.new(price)
		for order: Order in _levels[side][price]:
			level.quantity += order.remaining
			if order.is_player:
				level.player_quantity += order.remaining
			elif order.tag != "LP":
				level.wall_quantity += order.remaining
				if level.wall_tag.is_empty():
					level.wall_tag = order.tag
		result.append(level)
	return result


## 최우선 호가부터 count개 칸의 잔량 합.
func total_quantity(side: int, count: int) -> int:
	var total := 0
	for level: BookLevel in levels(side, count):
		total += level.quantity
	return total


func player_orders() -> Array:
	return _orders.values().filter(func(o: Order) -> bool: return o.is_player)


func player_open_quantity(side: int) -> int:
	var total := 0
	for order: Order in player_orders():
		if order.side == side:
			total += order.remaining
	return total


static func total_quantity_of(fills: Array) -> int:
	var total := 0
	for fill: Fill in fills:
		total += fill.quantity
	return total

class_name OrderBook
extends RefCounted
## 가격-시간 우선으로 체결하는 호가창. 동시호가(auction) 동안에는 주문을 쌓아 두었다가
## 한 가격에 한꺼번에 체결한다.

enum Side { BUY, SELL }

## 가격이 없음을 뜻한다 (실제 호가는 항상 양수).
const NO_PRICE := 0


## 호가창에 걸려 있는 주문.
class Order:
	var id: int
	var side: int
	var price: int
	var remaining: int
	var is_player: bool
	## 주문 주체 (LP, 나, 개미, 매수청구 ...)
	var tag: String
	## 동시호가 중 낸 시장가 주문. 상·하한가에 걸어 두고, 체결되고 남으면 취소된다.
	var market: bool

	func _init(p_id: int, p_side: int, p_price: int, p_remaining: int, p_is_player: bool,
			p_tag: String, p_market: bool) -> void:
		id = p_id
		side = p_side
		price = p_price
		remaining = p_remaining
		is_player = p_is_player
		tag = p_tag
		market = p_market


## 체결 한 건. 접속매매에서 aggressor는 호가를 먹은 쪽이다.
## 동시호가 체결은 매수 주문을 taker, 매도 주문을 maker 자리에 넣는다.
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


## 화면에 그릴 호가 한 칸 (동시호가 시장가 주문은 빠진다).
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


## true면 주문이 들어와도 체결하지 않고 쌓는다.
var auction := false

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


func is_crossed() -> bool:
	return best_bid() != NO_PRICE and best_ask() != NO_PRICE and best_bid() >= best_ask()


## 지정가 주문. 접속매매 중 반대 호가와 교차하면 먼저 체결하고 남은 수량만 쌓는다.
## {"fills": Array[Fill], "resting": Order 또는 null}
func place_limit(side: int, price: int, quantity: int, is_player := false, tag := "",
		market := false) -> Dictionary:
	var fills := [] if auction else _match(side, quantity, price, is_player)
	var left := quantity - total_quantity_of(fills)
	var resting: Order = null
	if left > 0:
		resting = Order.new(_next_id, side, price, left, is_player, tag, market)
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
			_drop_level(opp, price)
	return fills


func _drop_level(side: int, price: int) -> void:
	_levels[side].erase(price)
	_prices(side).erase(price)


## 동시호가 예상체결: 체결량이 가장 많은 가격, 같으면 잔량 차이가 작은 가격,
## 그래도 같으면 reference에 가까운 가격.
## {"price": 예상체결가(없으면 NO_PRICE), "volume": 예상체결량, "buy": 그 가격 이상 매수 합, "sell": 그 가격 이하 매도 합}
func auction_quote(reference: int) -> Dictionary:
	var best := {"price": NO_PRICE, "volume": 0, "buy": 0, "sell": 0}
	if _bid_prices.is_empty() or _ask_prices.is_empty() or not is_crossed():
		return best
	var bid_qty := {}
	var ask_qty := {}
	for price in _bid_prices:
		bid_qty[price] = quantity_at(Side.BUY, price, true)
	for price in _ask_prices:
		ask_qty[price] = quantity_at(Side.SELL, price, true)
	var candidates := {}
	for price in _bid_prices:
		candidates[price] = true
	for price in _ask_prices:
		candidates[price] = true
	for p: int in candidates:
		var demand := 0
		for price: int in bid_qty:
			if price >= p:
				demand += bid_qty[price]
		var supply := 0
		for price: int in ask_qty:
			if price <= p:
				supply += ask_qty[price]
		var volume := mini(demand, supply)
		if volume == 0:
			continue
		var better: bool = volume > best.volume
		if volume == best.volume:
			var gap := absi(demand - supply)
			var best_gap := absi(best.buy - best.sell)
			better = gap < best_gap or (gap == best_gap and absi(p - reference) < absi(best.price - reference))
		if better:
			best = {"price": p, "volume": volume, "buy": demand, "sell": supply}
	return best


## 동시호가 체결: price 이상 매수와 price 이하 매도를 가격·시간 순으로 모두 price에 맞춘다.
func uncross(price: int) -> Array:
	var fills := []
	while not _bid_prices.is_empty() and not _ask_prices.is_empty():
		var bid_price: int = _bid_prices.back()
		var ask_price: int = _ask_prices.front()
		if bid_price < price or ask_price > price:
			break
		var bids: Array = _levels[Side.BUY][bid_price]
		var asks: Array = _levels[Side.SELL][ask_price]
		var buyer: Order = bids.front()
		var seller: Order = asks.front()
		var qty := mini(buyer.remaining, seller.remaining)
		buyer.remaining -= qty
		seller.remaining -= qty
		fills.append(Fill.new(price, qty, Side.BUY, buyer.is_player, seller.is_player))
		if buyer.remaining == 0:
			bids.pop_front()
			_orders.erase(buyer.id)
			if bids.is_empty():
				_drop_level(Side.BUY, bid_price)
		if seller.remaining == 0:
			asks.pop_front()
			_orders.erase(seller.id)
			if asks.is_empty():
				_drop_level(Side.SELL, ask_price)
	return fills


## 조건에 맞는 주문을 모두 취소하고 취소한 수량을 돌려준다.
func cancel_where(test: Callable) -> int:
	var targets := []
	for order in _orders.values():
		if test.call(order):
			targets.append(order)
	var quantity := 0
	for order: Order in targets:
		quantity += order.remaining
		var levels: Dictionary = _levels[order.side]
		var queue: Array = levels.get(order.price, [])
		queue.erase(order)
		if queue.is_empty() and levels.has(order.price):
			_drop_level(order.side, order.price)
		_orders.erase(order.id)
	return quantity


## 조건에 맞는 주문 건수.
func count_where(test: Callable) -> int:
	return _orders.values().filter(test).size()


func quantity_at(side: int, price: int, include_market := false) -> int:
	var total := 0
	for order: Order in _levels[side].get(price, []):
		if include_market or not order.market:
			total += order.remaining
	return total


func player_quantity_at(side: int, price: int) -> int:
	var total := 0
	for order: Order in _levels[side].get(price, []):
		if order.is_player:
			total += order.remaining
	return total


## 최우선 호가부터 count개 칸. 동시호가 시장가 주문은 칸에 넣지 않는다.
func levels(side: int, count: int) -> Array:
	var prices := _prices(side)
	var result := []
	var i := 0
	while result.size() < count and i < prices.size():
		var price: int = prices[prices.size() - 1 - i] if side == Side.BUY else prices[i]
		i += 1
		var level := BookLevel.new(price)
		for order: Order in _levels[side][price]:
			if order.market:
				continue
			level.quantity += order.remaining
			if order.is_player:
				level.player_quantity += order.remaining
			elif order.tag != "LP":
				level.wall_quantity += order.remaining
				if level.wall_tag.is_empty():
					level.wall_tag = order.tag
		if level.quantity > 0:
			result.append(level)
	return result


## 동시호가에 쌓인 시장가 주문 합.
func market_quantity(side: int) -> int:
	var total := 0
	for order: Order in _orders.values():
		if order.market and order.side == side:
			total += order.remaining
	return total


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

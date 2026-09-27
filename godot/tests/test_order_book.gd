extends TestCase

const BUY := OrderBook.Side.BUY
const SELL := OrderBook.Side.SELL


func _book() -> OrderBook:
	var book := OrderBook.new()
	book.place_limit(SELL, 10020, 300)
	book.place_limit(SELL, 10010, 200)
	book.place_limit(BUY, 10000, 500)
	book.place_limit(BUY, 9990, 400)
	return book


func _prices(levels: Array) -> Array:
	return levels.map(func(l: OrderBook.BookLevel) -> int: return l.price)


func test_best_prices_and_levels() -> void:
	var book := _book()
	eq(book.best_ask(), 10010)
	eq(book.best_bid(), 10000)
	eq(_prices(book.levels(SELL, 5)), [10010, 10020])
	eq(_prices(book.levels(BUY, 5)), [10000, 9990])
	eq(book.total_quantity(BUY, 10), 900)


func test_market_buy_sweeps_up() -> void:
	var book := _book()
	var fills := book.place_market(BUY, 350)
	eq(fills.map(func(f: OrderBook.Fill) -> int: return f.price), [10010, 10020])
	eq(fills.map(func(f: OrderBook.Fill) -> int: return f.quantity), [200, 150])
	eq(book.best_ask(), 10020)
	eq(book.quantity_at(SELL, 10020), 150)


func test_market_respects_limit() -> void:
	var book := _book()
	eq(OrderBook.total_quantity_of(book.place_market(BUY, 1000, 10010)), 200)
	eq(book.best_ask(), 10020)


func test_time_priority() -> void:
	var book := _book()
	book.place_limit(BUY, 10000, 100, true)
	var fills := book.place_market(SELL, 550)
	check(not fills[0].maker_is_player, "먼저 낸 NPC 주문이 먼저")
	eq(fills[0].quantity, 500)
	check(fills[1].maker_is_player)
	eq(fills[1].quantity, 50)
	eq(book.player_quantity_at(BUY, 10000), 50)


func test_crossing_limit_fills_then_rests() -> void:
	var book := _book()
	var placed := book.place_limit(BUY, 10010, 500, true)
	eq(OrderBook.total_quantity_of(placed.fills), 200)
	eq(placed.resting.remaining, 300)
	eq(book.best_bid(), 10010)
	eq(book.best_ask(), 10020)
	eq(book.player_open_quantity(BUY), 300)


func test_cancel_where() -> void:
	var book := _book()
	book.place_limit(BUY, 9980, 100, true)
	book.place_limit(SELL, 10030, 100, true)
	eq(book.count_where(func(o: OrderBook.Order) -> bool: return o.is_player), 2)
	eq(book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player), 200, "취소 수량")
	eq(book.player_orders().size(), 0)
	eq(book.quantity_at(BUY, 9980), 0)
	eq(_prices(book.levels(SELL, 10)), [10010, 10020])


func test_levels_split_walls() -> void:
	var book := OrderBook.new()
	book.place_limit(BUY, 10000, 500, false, "LP")
	book.place_limit(BUY, 10000, 700, false, "매수청구")
	book.place_limit(BUY, 10000, 50, true)
	var level: OrderBook.BookLevel = book.levels(BUY, 1)[0]
	eq(level.quantity, 1250)
	eq(level.wall_quantity, 700)
	eq(level.wall_tag, "매수청구")
	eq(level.player_quantity, 50)


func test_auction_collects_then_uncrosses_at_one_price() -> void:
	var book := OrderBook.new()
	book.auction = true
	book.place_limit(SELL, 10020, 300, false, "LP")
	book.place_limit(SELL, 10010, 200, false, "LP")
	book.place_limit(BUY, 9990, 400, false, "LP")
	# 동시호가 중에는 교차해도 체결되지 않는다.
	var placed := book.place_limit(BUY, 10020, 350, true)
	eq(placed.fills.size(), 0)
	book.place_limit(BUY, 11000, 100, false, "개미", true)
	check(book.is_crossed())
	var q := book.auction_quote(10000)
	eq(q.price, 10020, "체결량이 가장 많은 가격")
	eq(q.volume, 450)
	eq(book.market_quantity(BUY), 100)
	# 시장가는 호가 칸에 보이지 않는다.
	eq(book.levels(BUY, 5)[0].price, 10020)
	var fills := book.uncross(q.price)
	eq(OrderBook.total_quantity_of(fills), 450)
	for fill: OrderBook.Fill in fills:
		eq(fill.price, 10020, "모두 한 가격")
	check(fills[0].taker_is_player == false, "시장가가 먼저")
	check(not book.is_crossed(), "체결 뒤에는 교차가 없다")
	eq(book.quantity_at(SELL, 10020), 50)


func test_auction_quote_ties_go_to_smaller_imbalance() -> void:
	var book := OrderBook.new()
	book.auction = true
	book.place_limit(BUY, 10010, 100)
	book.place_limit(SELL, 9990, 100)
	book.place_limit(SELL, 10010, 30)
	var q := book.auction_quote(10000)
	eq(q.volume, 100)
	eq(q.price, 9990, "같은 체결량이면 잔량 차이가 작은 가격")


func test_no_quote_when_not_crossed() -> void:
	var book := _book()
	book.auction = true
	eq(book.auction_quote(10000).price, OrderBook.NO_PRICE)

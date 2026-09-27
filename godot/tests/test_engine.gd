extends TestCase

const BUY := OrderBook.Side.BUY
const SELL := OrderBook.Side.SELL
const BULL := War.Faction.BULL
const BEAR := War.Faction.BEAR
const P := ChartPatterns.Pattern
const Phase := BattleEngine.Phase


func _modu() -> Company:
	return Company.new("모두전자", "전자부품", 12000)


func _battle(faction := BULL, seed_value := 1) -> BattleEngine:
	return BattleEngine.new(_modu(), faction, seed_value)


## 09:01, 접속매매가 막 시작된 상태.
func _opened(faction := BULL, seed_value := 1) -> BattleEngine:
	var engine := _battle(faction, seed_value)
	while engine.tick <= BattleEngine.OPEN_TICK:
		engine.step()
	return engine


func _run_to(engine: BattleEngine, tick: int) -> void:
	while engine.tick < tick and not engine.is_over():
		engine.step()


func _feed_has(engine: BattleEngine, text: String) -> bool:
	for item: BattleEngine.FeedItem in engine.feed:
		if item.title.contains(text):
			return true
	return false


func test_full_day_keeps_market_rules() -> void:
	for seed_value in [1, 2, 3, 4]:
		var engine := _battle(BULL, seed_value)
		var crossed := false
		var outside := false
		while not engine.is_over():
			engine.step()
			if not engine.book.auction and engine.book.is_crossed():
				crossed = true
			if engine.last_price < engine.lower_limit or engine.last_price > engine.upper_limit \
					or engine.last_price != Krx.floor_to_tick(engine.last_price):
				outside = true
		check(not crossed, "접속매매 중 호가가 교차하면 안 된다 (시드 %d)" % seed_value)
		check(not outside, "가격은 제한폭 안의 유효 호가")
		if engine.result.reason.begins_with("종가"):
			eq(engine.clock(), "15:30")
			eq(engine.candles.size(), 77, "5분봉 76개 + 종가 동시호가 1개")
		eq(engine.book.player_orders().size(), 0, "장 마감 후 내 주문은 없다")


func test_day_starts_with_preopen_auction() -> void:
	var engine := _battle()
	eq(engine.clock(), "08:50")
	eq(engine.phase, Phase.PREOPEN)
	check(engine.book.auction)
	_run_to(engine, BattleEngine.OPEN_TICK - 1)
	eq(engine.phase, Phase.PREOPEN)
	check(engine.quote.get("volume", 0) > 0, "예상체결가가 잡힌다")
	engine.step()
	eq(engine.clock(), "09:00")
	eq(engine.phase, Phase.CONTINUOUS)
	check(engine.open_price > 0)
	eq(engine.last_price, engine.open_price)
	eq(engine.current_candle.open, engine.open_price)
	check(_feed_has(engine, "시가"))
	check(not engine.book.is_crossed())
	eq(engine.book.market_quantity(BUY) + engine.book.market_quantity(SELL), 0, "남은 시장가는 취소")


func test_preopen_order_fills_at_open_price() -> void:
	var engine := _battle()
	engine.step()
	var result := engine.attack(0.3)
	check(result.ok)
	check(result.message.contains("동시호가"))
	eq(engine.account.position, 0, "아직 체결 전")
	check(engine.book.market_quantity(BUY) > 0)
	_run_to(engine, BattleEngine.OPEN_TICK)
	check(engine.account.position > 0, "시가에 체결")
	eq(engine.account.average_price, float(engine.open_price))


func test_closing_auction_decides_the_winner() -> void:
	var engine := _battle(BEAR, 7)
	_run_to(engine, BattleEngine.CLOSING_TICK)
	if engine.is_over():
		return
	eq(engine.phase, Phase.CLOSING)
	eq(engine.clock(), "15:20")
	check(_feed_has(engine, "장 마감 동시호가"))
	var before := engine.feed_serial
	_run_to(engine, BattleEngine.END_TICK)
	check(engine.is_over())
	check(engine.feed_serial > before)
	check(engine.result.reason.begins_with("종가"))
	var expected := War.NEUTRAL
	if engine.last_price > engine.base_price:
		expected = BULL
	elif engine.last_price < engine.base_price:
		expected = BEAR
	eq(engine.result.winner, expected)
	eq(engine.take_reveals().back().label, "종가")


func test_player_can_swing_the_close() -> void:
	var calm := _battle(BULL, 11)
	var pushed := _battle(BULL, 11)
	_run_to(calm, BattleEngine.CLOSING_TICK + 5)
	_run_to(pushed, BattleEngine.CLOSING_TICK + 5)
	if calm.is_over():
		return
	check(pushed.attack(1.0).ok)
	check(pushed.quote.price >= calm.quote.price, "예상체결가가 올라간다")
	_run_to(calm, BattleEngine.END_TICK)
	_run_to(pushed, BattleEngine.END_TICK)
	check(pushed.last_price >= calm.last_price, "종가를 끌어올린다")


func test_bull_attack_is_market_buy_within_equity() -> void:
	var engine := _opened()
	check(engine.attack(1.0).ok)
	check(engine.account.position > 0)
	check(engine.attack_value > 0)
	check(engine.account.position * engine.last_price <= engine.equity() * 1.1)
	check(engine.max_quantity(BUY, engine.last_price) < 100)
	var strikes := engine.take_strikes()
	check(not strikes.is_empty(), "전장 연출용 돌격 기록")
	check(not strikes.back().levels.is_empty(), "칸별로 먹은 수량")


func test_bear_attack_is_short_sale() -> void:
	var engine := _opened(BEAR)
	check(engine.attack(0.5).ok)
	check(engine.account.position < 0)
	check(engine.close_position().ok)
	eq(engine.account.position, 0)


func test_wall_shows_as_my_quantity() -> void:
	var engine := _opened()
	var best_bid := engine.book.best_bid()
	check(engine.place_wall(0.3).ok)
	var mine := 0
	for level: OrderBook.BookLevel in engine.bids(10):
		if level.price == best_bid:
			mine = level.player_quantity
	check(mine > 0)
	check(engine.cancel_orders().ok)
	eq(engine.book.player_open_quantity(BUY), 0)


func test_close_does_not_trade_with_own_wall() -> void:
	var engine := _opened()
	engine.attack(0.5)
	check(engine.place_wall(0.5).ok)
	check(engine.close_position().ok)
	eq(engine.account.position, 0)
	eq(engine.book.player_open_quantity(BUY), 0)


func test_clicking_enemy_level_attacks_up_to_it() -> void:
	var engine := _opened()
	var target := Krx.shift_ticks(engine.book.best_ask(), 2)
	check(engine.place_wall(0.5, target).ok)
	check(engine.account.position > 0)
	check(engine.last_price <= target)


func test_own_pattern_becomes_card_and_sweeps_one_way() -> void:
	var engine := _opened()
	engine.grant_skill(Skill.of(P.GOLDEN_CROSS))
	eq(engine.hand.size(), 1)
	eq(engine.hand[0].skill.name, "골든크로스")
	var before := engine.last_price
	check(engine.use_skill(0).ok)
	eq(engine.hand.size(), 0)
	check(Krx.ticks_between(before, engine.last_price) >= 5, "위로 5호가 이상")
	var blasts := engine.take_blasts()
	eq(blasts.size(), 1)
	check(blasts[0].by_player)
	eq(engine.skills_used, 1)
	check(engine.skill_ticks > 0)
	eq(engine.account.position, 0, "스킬 물량은 내 계좌로 들어오지 않는다")
	eq(engine.pnl(), 0)


func test_unused_card_expires() -> void:
	var engine := _opened()
	engine.grant_skill(Skill.of(P.HAMMER))
	var card: BattleEngine.SkillCard = engine.hand[0]
	for i in BattleEngine.CARD_LIFETIME - 1:
		engine.step()
	check(engine.hand.has(card), "아직 남아 있다")
	engine.step()
	check(not engine.hand.has(card), "30분 뒤 만료")


func test_enemy_pattern_fires_after_windup() -> void:
	var engine := _opened()
	engine.grant_skill(Skill.of(P.DEAD_CROSS))
	eq(engine.incoming.size(), 1)
	eq(engine.feed[0].kind, BattleEngine.FeedKind.WARNING)
	engine.take_blasts()
	var fired := false
	for i in BattleEngine.ENEMY_WINDUP + 2:
		engine.step()
		for blast: BattleEngine.SkillBlast in engine.take_blasts():
			if blast.skill.pattern == P.DEAD_CROSS and not blast.by_player:
				fired = true
		if fired:
			break
	check(fired)
	eq(engine.incoming.size(), 0)


func test_vi_is_a_two_minute_auction() -> void:
	var engine := BattleEngine.new(Company.new("한빛바이오", "바이오", 3150), BULL, 3)
	_run_to(engine, BattleEngine.OPEN_TICK + 1)
	for i in 200:
		if engine.phase == Phase.VI:
			break
		engine.grant_skill(Skill.of(P.INVERSE_HEAD_AND_SHOULDERS))
		engine.use_skill(engine.hand.size() - 1)
		if engine.phase == Phase.VI:
			break
		engine.step()
	eq(engine.phase, Phase.VI, "VI 발동")
	check(engine.book.auction)
	var attack := engine.attack(0.5)
	check(attack.ok, "VI 중에도 주문은 받는다")
	check(attack.message.contains("동시호가"))
	var until := engine.tick + BattleEngine.VI_DURATION
	_run_to(engine, until)
	eq(engine.phase, Phase.CONTINUOUS, "2분 뒤 해제")
	check(_feed_has(engine, "VI 해제"))
	check(not engine.book.is_crossed())


func test_rights_offering_builds_wall_above() -> void:
	var engine := _opened()
	var event: MarketEvent = MarketEvent.deck().filter(func(e: MarketEvent) -> bool: return e.title.contains("주주배정 유상증자"))[0]
	var wall_price := Krx.ceil_to_tick(roundi(engine.last_price * 1.02))
	var before := engine.last_price
	engine.fire_event(event)
	check(engine.sentiment < 0)
	check(engine.last_price < before)
	check(engine.book.quantity_at(SELL, wall_price) >= 6 * engine.depth_unit)
	check(engine.feed[0].title.contains("모두전자"))
	eq(engine.feed[0].label, "공시")


func test_merger_dispute_builds_appraisal_wall() -> void:
	var engine := _opened()
	var event: MarketEvent = MarketEvent.deck().filter(func(e: MarketEvent) -> bool: return e.wall_tag == "매수청구")[0]
	var wall_price := Krx.floor_to_tick(roundi(engine.last_price * 0.94))
	engine.fire_event(event)
	check(engine.book.quantity_at(BUY, wall_price) >= 12 * engine.depth_unit)
	var level: OrderBook.BookLevel = null
	for l: OrderBook.BookLevel in engine.bids(200):
		if l.price == wall_price:
			level = l
	check(level != null and level.wall_tag == "매수청구", "전장에 바리케이드로 보일 태그")


func test_rumor_gets_answered() -> void:
	var engine := _opened(BULL, 9)
	var rumor: MarketEvent = MarketEvent.deck().filter(func(e: MarketEvent) -> bool: return e.category == MarketEvent.Category.RUMOR)[0]
	engine.fire_event(rumor)
	var answers := rumor.follow_ups.map(func(e: MarketEvent) -> String: return e.title_for("모두전자"))
	var answered := false
	for i in rumor.follow_up_delay + 1:
		engine.step()
		for item: BattleEngine.FeedItem in engine.feed:
			if answers.has(item.title):
				answered = true
		if answered:
			break
	check(answered)


func test_chat_room_comes_alive() -> void:
	var a := _battle(BULL, 5)
	var b := _battle(BULL, 5)
	_run_to(a, BattleEngine.END_TICK)
	_run_to(b, BattleEngine.END_TICK)
	check(a.chatter.lines.size() >= 30, "하루 동안 30마디 이상 (실제 %d)" % a.chatter.lines.size())
	eq(a.chatter.lines[3].text, b.chatter.lines[3].text, "같은 시드면 같은 대사")
	for line: Chatter.Line in a.chatter.lines:
		check(not line.text.contains("{"), "치환 안 된 자리표시자: " + line.text)


func test_news_reaction_matches_headline() -> void:
	var chatter := Chatter.new(1)
	chatter.react_to_news("10:00", "모두전자, 1주당 1주 무상증자 결정", BULL)
	check(Chatter.NEWS_LINES["무상증자"].has(chatter.lines[0].text))


func test_account_accounting() -> void:
	var account := PlayerAccount.new(1000000)
	account.apply(BUY, 10000, 100)
	account.apply(SELL, 11000, 50)
	eq(account.realized, 50000)
	eq(account.position, 50)
	eq(account.average_price, 10000.0)
	account.apply(SELL, 12000, 100)
	eq(account.realized, 150000)
	eq(account.position, -50)
	eq(account.average_price, 12000.0)
	eq(account.equity(12000), 1150000)
	account.apply(BUY, 11000, 50)
	eq(account.realized, 200000)
	eq(account.position, 0)


func test_grade() -> void:
	var result := BattleEngine.BattleResult.new()
	result.player_faction = BULL
	result.starting_cash = 100000000
	result.winner = BULL
	result.pnl = 6000000
	eq(result.grade(), "S")
	result.pnl = -1
	eq(result.grade(), "B")
	result.winner = BEAR
	result.pnl = 1
	eq(result.grade(), "B")
	result.pnl = -1
	eq(result.grade(), "C")
	result.winner = War.NEUTRAL
	check(not result.victory())

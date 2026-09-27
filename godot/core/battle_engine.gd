class_name BattleEngine
extends RefCounted
## 호가전쟁 한 판 (09:00~15:30 하루 장). step() 한 번이 1분이다.

const TICKS_PER_DAY := 390
const TICKS_PER_CANDLE := 5
## 호가 한 칸에 평소 쌓이는 금액.
const DEPTH_VALUE := 15000000
const HAND_LIMIT := 3
const CARD_LIFETIME := 30
const ENEMY_WINDUP := 3
const VI_DURATION := 2
const LIMIT_HOLD_TO_WIN := 10
const PATTERN_COOLDOWN := 6
const DEFAULT_NEWS_RATE := 1.0 / 32.0

enum FeedKind { NEWS, SKILL, WARNING, SYSTEM }

## 이름, 뽑힐 가중치, 한 번에 내는 물량 (표준 잔량 칸 수)
const TRADERS := [
	["개미", 55, 0.4],
	["기관", 20, 1.2],
	["외국인", 20, 1.5],
	["세력", 5, 4.0],
]

const BUY := OrderBook.Side.BUY
const SELL := OrderBook.Side.SELL


class FeedItem:
	var time: String
	var kind: int
	var title: String
	var detail: String
	## [공시] [속보] 같은 머리표.
	var label: String
	## 어느 진영에 유리한 소식인지 (중립이면 War.NEUTRAL).
	var tone: int

	func _init(p_time: String, p_kind: int, p_title: String, p_detail: String, p_label: String, p_tone: int) -> void:
		time = p_time
		kind = p_kind
		title = p_title
		detail = p_detail
		label = p_label
		tone = p_tone


## 플레이어 손에 들린 스킬 카드. 제때 쓰지 않으면 사라진다.
class SkillCard:
	var skill: Skill
	var expires_at: int

	func _init(p_skill: Skill, p_expires_at: int) -> void:
		skill = p_skill
		expires_at = p_expires_at


## 적 진영이 준비 중인 스킬.
class IncomingSkill:
	var skill: Skill
	var fires_at: int

	func _init(p_skill: Skill, p_fires_at: int) -> void:
		skill = p_skill
		fires_at = p_fires_at


## 화면 연출용: 스킬이 호가창을 휩쓴 기록.
class SkillBlast:
	var skill: Skill
	var from: int
	var to: int
	var by_player: bool

	func _init(p_skill: Skill, p_from: int, p_to: int, p_by_player: bool) -> void:
		skill = p_skill
		from = p_from
		to = p_to
		by_player = p_by_player


## 화면 연출용: 시장가 한 방 (누가 어느 쪽으로 얼마나 밀었나).
class Strike:
	var side: int
	var quantity: int
	var from: int
	var to: int
	var tag: String
	var by_player: bool

	func _init(p_side: int, p_quantity: int, p_from: int, p_to: int, p_tag: String, p_by_player: bool) -> void:
		side = p_side
		quantity = p_quantity
		from = p_from
		to = p_to
		tag = p_tag
		by_player = p_by_player


class ActionResult:
	var ok: bool
	var message: String

	func _init(p_ok: bool, p_message: String) -> void:
		ok = p_ok
		message = p_message


class BattleResult:
	## 이긴 진영 (보합이면 War.NEUTRAL).
	var winner: int
	var reason: String
	var player_faction: int
	var base_price: int
	var close_price: int
	var starting_cash: int
	var pnl: int
	var attack_value: int
	var defense_value: int
	var skills_used: int
	var skill_ticks: int

	func victory() -> bool:
		return winner == player_faction

	func return_rate() -> float:
		return float(pnl) / starting_cash

	func price_change() -> float:
		return float(close_price - base_price) / base_price

	func grade() -> String:
		if victory() and return_rate() >= 0.05:
			return "S"
		if victory() and return_rate() >= 0:
			return "A"
		if victory() or return_rate() > 0:
			return "B"
		return "C"


class Pressure:
	var levels: float
	var ticks_left: int

	func _init(p_levels: float, p_ticks: int) -> void:
		levels = p_levels
		ticks_left = p_ticks


class ActiveSkill:
	var skill: Skill
	var waves_left: int
	var by_player: bool

	func _init(p_skill: Skill, p_waves: int, p_by_player: bool) -> void:
		skill = p_skill
		waves_left = p_waves
		by_player = p_by_player


class Scheduled:
	var tick: int
	var event: MarketEvent

	func _init(p_tick: int, p_event: MarketEvent) -> void:
		tick = p_tick
		event = p_event


var company: Company
var faction: int
var starting_cash: int
var news_rate: float
var rng := RandomNumberGenerator.new()
var book := OrderBook.new()
var account: PlayerAccount
var base_price: int
var upper_limit: int
var lower_limit: int
## 표준 호가 잔량 (주). 스킬·이벤트 물량의 단위.
var depth_unit: int

var tick := 0
var last_price: int
## 시장 심리: -1(공포, 매도세) ~ +1(탐욕, 매수세).
var sentiment := 0.0
var _mood := 0.0
var _volatility := 1.0
var _volatility_ticks := 0

var candles: Array = []
var current_candle: Candle
## 최신이 앞.
var feed: Array = []
## 소식이 추가될 때마다 1씩 오른다 (화면 갱신용).
var feed_serial := 0
var hand: Array = []
var incoming: Array = []
var _active: Array = []
var _pressures: Array = []
var _scheduled: Array = []
var _blasts: Array = []
var _strikes: Array = []
var _last_fired := {}
var _price_history: Array[int] = []
var _buy_history: Array[int] = []
var _sell_history: Array[int] = []
var _tick_buy := 0
var _tick_sell := 0

## 남은 VI(변동성 완화장치) 시간. 0보다 크면 시장가·스킬이 봉인된다.
var vi_remaining := 0
## 정적 VI 기준가 (직전 단일가).
var vi_anchor: int
var upper_hold := 0
var lower_hold := 0

var result: BattleResult = null

# 플레이어 전공
var attack_value := 0
var defense_value := 0
var skills_used := 0
var skill_ticks := 0


func _init(p_company: Company, p_faction: int, seed_value := -1,
		p_cash := 100000000, p_news_rate := DEFAULT_NEWS_RATE) -> void:
	company = p_company
	faction = p_faction
	starting_cash = p_cash
	news_rate = p_news_rate
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	base_price = company.base_price
	upper_limit = Krx.upper_limit(base_price)
	lower_limit = Krx.lower_limit(base_price)
	depth_unit = maxi(1, roundi(float(DEPTH_VALUE) / base_price))
	last_price = base_price
	account = PlayerAccount.new(p_cash)
	vi_anchor = base_price
	current_candle = Candle.new(0, base_price)
	_provide_liquidity(1.0)
	_log(FeedKind.SYSTEM, "장 시작 — %s 합류" % War.label(faction),
		"기준가 %s원 · 상한가 %s · 하한가 %s" % [
			Krx.format_number(base_price), Krx.format_number(upper_limit),
			Krx.format_number(lower_limit)])


func is_over() -> bool:
	return result != null


func in_vi() -> bool:
	return vi_remaining > 0


func change_rate() -> float:
	return float(last_price - base_price) / base_price


func clock() -> String:
	var minutes := 9 * 60 + tick
	@warning_ignore("integer_division")
	var hours := minutes / 60
	return "%02d:%02d" % [hours, minutes % 60]


## 최근 20분 체결량 중 매수 체결 비중 (0~1). 줄다리기 게이지.
func buy_share() -> float:
	var buy := _tick_buy
	var sell := _tick_sell
	for v in _buy_history:
		buy += v
	for v in _sell_history:
		sell += v
	return 0.5 if buy + sell == 0 else float(buy) / (buy + sell)


## 체결강도 = 매수 체결량 / 매도 체결량 × 100.
func trade_strength() -> float:
	var share := buy_share()
	return 999.0 if share >= 1.0 else share / (1.0 - share) * 100.0


func equity() -> int:
	return account.equity(last_price)


func pnl() -> int:
	return equity() - starting_cash


func asks(count: int) -> Array:
	return book.levels(SELL, count)


func bids(count: int) -> Array:
	return book.levels(BUY, count)


## 스킬 연출을 꺼내 간다 (화면이 한 번씩 소비).
func take_blasts() -> Array:
	var taken := _blasts.duplicate()
	_blasts.clear()
	return taken


## 시장가 공격 기록을 꺼내 간다 (화면이 한 번씩 소비).
func take_strikes() -> Array:
	var taken := _strikes.duplicate()
	_strikes.clear()
	return taken


# ── 시간 진행 ────────────────────────────────────────────────────

## 1분 진행.
func step() -> void:
	if is_over():
		return
	tick += 1
	_run_schedule()
	if tick == 1 or rng.randf() < news_rate:
		_fire_event(_draw_event())
	_mood = clampf(_mood * 0.97 + (rng.randf() - 0.5) * 0.08, -0.4, 0.4)
	if in_vi():
		_provide_liquidity()
		vi_remaining -= 1
		if not in_vi():
			_log(FeedKind.SYSTEM, "VI 해제 — 접속매매 재개", "시장가·스킬 봉인이 풀렸다")
	else:
		_run_pressures()
		_run_active_skills()
		_fire_incoming()
		_provide_liquidity()
		_aggress()
	sentiment *= 0.97
	if _volatility_ticks > 0:
		_volatility_ticks -= 1
		if _volatility_ticks == 0:
			_volatility = 1.0
	_expire_cards()
	_record_tick()
	if tick % TICKS_PER_CANDLE == 0:
		_close_candle()
	_check_limits()
	if not is_over() and tick >= TICKS_PER_DAY:
		_close_market()


func _record_tick() -> void:
	_price_history.append(last_price)
	_buy_history.append(_tick_buy)
	_sell_history.append(_tick_sell)
	if _buy_history.size() > 20:
		_buy_history.pop_front()
		_sell_history.pop_front()
	_tick_buy = 0
	_tick_sell = 0


## 매수(+) / 매도(-) 쏠림. 심리 + 추세 추종 + 분위기 - 가치투자자의 되돌림.
func _bias() -> float:
	var momentum := 0.0
	if _price_history.size() >= 10:
		var past := _price_history[_price_history.size() - 10]
		momentum = clampf(Krx.ticks_between(past, last_price) / 30.0, -1.0, 1.0)
	var reversion := change_rate() * 4.0
	return clampf(sentiment + 0.2 * momentum + _mood - reversion, -0.9, 0.9)


# ── NPC: 유동성 공급(LP)과 시장가 공격 ────────────────────────────

## 현재가 위아래 10호가에 LP 잔량을 채운다. 쏠림이 있으면 불리한 쪽 호가가 얇아진다.
func _provide_liquidity(refill := 0.0) -> void:
	var bias := _bias()
	_refill_side(SELL, 1.0 - 0.3 * bias, refill)
	_refill_side(BUY, 1.0 + 0.3 * bias, refill)
	var high := Krx.shift_ticks(last_price, 20)
	var low := Krx.shift_ticks(last_price, -20)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.tag == "LP" and (o.price > high or o.price < low))


func _refill_side(side: int, factor: float, refill: float) -> void:
	var opposite := book.best(OrderBook.opposite(side))
	var price := last_price
	for level in 10:
		price = Krx.next_tick(price) if side == SELL else Krx.prev_tick(price)
		if price > upper_limit or price < lower_limit:
			break
		if opposite != OrderBook.NO_PRICE and (price <= opposite if side == SELL else price >= opposite):
			continue
		var target := roundi(depth_unit * factor * (0.6 + 0.1 * level))
		var have := book.quantity_at(side, price)
		if have >= target:
			continue
		var share := refill if refill > 0 else 0.25 + rng.randf() * 0.35
		var add := roundi((target - have) * share)
		if add > 0:
			book.place_limit(side, price, add, false, "LP")


func _aggress() -> void:
	var bias := _bias()
	var count := 1 + rng.randi_range(0, 2)
	for i in count:
		var trader: Array = _pick_trader()
		var side := BUY if rng.randf() < 0.5 + 0.35 * bias else SELL
		var size: float = depth_unit * trader[2] * (0.3 + rng.randf())
		var quantity := roundi(size * _volatility)
		if quantity >= depth_unit * 4.5:
			_log(FeedKind.SYSTEM, "%s 출현 — %s주 시장가 %s" % [trader[0], Krx.format_number(quantity), _verb(side)],
				"", War.of_side(side))
		_npc_market(side, quantity, trader[0])


func _pick_trader() -> Array:
	var total := 0
	for trader: Array in TRADERS:
		total += trader[1]
	var roll := rng.randi_range(0, total - 1)
	for trader: Array in TRADERS:
		roll -= trader[1]
		if roll < 0:
			return trader
	return TRADERS[0]


func _npc_market(side: int, quantity: int, tag: String) -> void:
	if quantity <= 0 or in_vi() or is_over():
		return
	var limit := _limit_for(side)
	var fills := _market(side, quantity, tag, false)
	# 상·하한가에서 못 받은 물량은 그 가격에 잔량으로 쌓인다.
	var left := quantity - OrderBook.total_quantity_of(fills)
	if left > 0 and last_price == limit:
		book.place_limit(side, limit, left, false, "잔량")


func _limit_for(side: int) -> int:
	return upper_limit if side == BUY else lower_limit


## 시장가 주문을 내고 체결을 반영한 뒤 화면용 공격 기록을 남긴다.
func _market(side: int, quantity: int, tag: String, by_player: bool) -> Array:
	var from := last_price
	var fills := book.place_market(side, quantity, _limit_for(side), by_player)
	_apply(fills)
	var filled := OrderBook.total_quantity_of(fills)
	if filled > 0:
		_strikes.append(Strike.new(side, filled, from, last_price, tag, by_player))
	return fills


# ── 체결 반영 ────────────────────────────────────────────────────

func _apply(fills: Array) -> void:
	for f: OrderBook.Fill in fills:
		last_price = f.price
		current_candle.update(f.price, f.quantity)
		if f.aggressor == BUY:
			_tick_buy += f.quantity
		else:
			_tick_sell += f.quantity
		if f.taker_is_player:
			_player_fill(f.aggressor, f.price, f.quantity, true)
		if f.maker_is_player:
			_player_fill(OrderBook.opposite(f.aggressor), f.price, f.quantity, false)
	if not fills.is_empty():
		_check_vi()


func _player_fill(side: int, price: int, quantity: int, aggressive: bool) -> void:
	account.apply(side, price, quantity)
	if side != War.attack_side(faction):
		return
	if aggressive:
		attack_value += price * quantity
	else:
		defense_value += price * quantity


## 정적 VI: 직전 단일가 대비 10% 이상 움직이면 2분간 단일가 매매.
func _check_vi() -> void:
	if in_vi() or is_over():
		return
	if absi(last_price - vi_anchor) * 10 < vi_anchor:
		return
	var up := last_price > vi_anchor
	vi_remaining = VI_DURATION
	vi_anchor = last_price
	_log(FeedKind.SYSTEM, "정적 VI 발동 %s %s원" % ["▲" if up else "▼", Krx.format_number(last_price)],
		"2분간 단일가 매매 — 시장가·스킬 봉인, 벽 쌓기만 가능",
		War.Faction.BULL if up else War.Faction.BEAR)


func _check_limits() -> void:
	upper_hold = upper_hold + 1 if last_price >= upper_limit else 0
	lower_hold = lower_hold + 1 if last_price <= lower_limit else 0
	if upper_hold == 1:
		_log(FeedKind.SYSTEM, "상한가 도달!", "%d분 동안 지키면 매수군 완승" % LIMIT_HOLD_TO_WIN, War.Faction.BULL)
	if lower_hold == 1:
		_log(FeedKind.SYSTEM, "하한가 도달!", "%d분 동안 지키면 매도군 완승" % LIMIT_HOLD_TO_WIN, War.Faction.BEAR)
	if upper_hold >= LIMIT_HOLD_TO_WIN:
		_finish(War.Faction.BULL, "상한가 안착")
	if lower_hold >= LIMIT_HOLD_TO_WIN:
		_finish(War.Faction.BEAR, "하한가 안착")


# ── 뉴스·공시 ────────────────────────────────────────────────────

func _draw_event() -> MarketEvent:
	var deck := MarketEvent.deck()
	var total := 0
	for event: MarketEvent in deck:
		total += event.weight
	var roll := rng.randi_range(0, total - 1)
	for event: MarketEvent in deck:
		roll -= event.weight
		if roll < 0:
			return event
	return deck[0]


func _run_schedule() -> void:
	var due := _scheduled.filter(func(s: Scheduled) -> bool: return s.tick <= tick)
	for s: Scheduled in due:
		_scheduled.erase(s)
		_fire_event(s.event)


## 이벤트를 즉시 터뜨린다 (테스트·연출용으로 공개).
func fire_event(event: MarketEvent) -> void:
	_fire_event(event)


func _fire_event(e: MarketEvent) -> void:
	var tone := War.NEUTRAL
	if e.sentiment > 0:
		tone = War.Faction.BULL
	elif e.sentiment < 0:
		tone = War.Faction.BEAR
	_log(FeedKind.NEWS, e.title_for(company.name), e.detail_for(company.name), tone, e.category_label())
	sentiment = clampf(sentiment + e.sentiment, -1.0, 1.0)
	if e.volatility_ticks > 0:
		_volatility = e.volatility
		_volatility_ticks = e.volatility_ticks
	if e.wall_size > 0:
		_place_event_wall(e)
	if e.shock != 0:
		_npc_market(BUY if e.shock > 0 else SELL, roundi(absf(e.shock) * depth_unit), e.category_label())
	if e.pressure_ticks > 0:
		_pressures.append(Pressure.new(e.pressure, e.pressure_ticks))
	if not e.follow_ups.is_empty():
		var next: MarketEvent = e.follow_ups[rng.randi_range(0, e.follow_ups.size() - 1)]
		_scheduled.append(Scheduled.new(tick + e.follow_up_delay, next))


func _place_event_wall(e: MarketEvent) -> void:
	var side := BUY if e.wall_offset < 0 else SELL
	var raw := roundi(last_price * (1.0 + e.wall_offset))
	var price := Krx.floor_to_tick(raw) if side == BUY else Krx.ceil_to_tick(raw)
	price = clampi(price, lower_limit, upper_limit)
	var opposite := book.best(OrderBook.opposite(side))
	if opposite != OrderBook.NO_PRICE and (price >= opposite if side == BUY else price <= opposite):
		return
	book.place_limit(side, price, roundi(e.wall_size * depth_unit), false, e.wall_tag)


func _run_pressures() -> void:
	for p: Pressure in _pressures:
		var size := absf(p.levels) * depth_unit * (0.5 + rng.randf())
		_npc_market(BUY if p.levels > 0 else SELL, roundi(size), "뉴스 물량")
		p.ticks_left -= 1
	_pressures = _pressures.filter(func(p: Pressure) -> bool: return p.ticks_left > 0)


# ── 차트 패턴 → 스킬 ─────────────────────────────────────────────

func _close_candle() -> void:
	candles.append(current_candle)
	current_candle = Candle.new(candles.size(), last_price)
	for pattern: int in ChartPatterns.detect(candles):
		if _last_fired.has(pattern) and candles.size() - _last_fired[pattern] < PATTERN_COOLDOWN:
			continue
		_last_fired[pattern] = candles.size()
		_grant(Skill.of(pattern))


func _grant(skill: Skill) -> void:
	var pattern_label := ChartPatterns.label(skill.pattern)
	if skill.faction() == faction:
		if hand.size() >= HAND_LIMIT:
			var dropped: SkillCard = hand.pop_front()
			_log(FeedKind.SYSTEM, "「%s」 카드가 밀려났다" % dropped.skill.name, "스킬 카드는 최대 %d장" % HAND_LIMIT)
		hand.append(SkillCard.new(skill, tick + CARD_LIFETIME))
		_log(FeedKind.SKILL, "%s 완성! 스킬 「%s」 획득" % [pattern_label, skill.name],
			"%s · %d분 안에 사용" % [skill.description, CARD_LIFETIME], faction)
	else:
		incoming.append(IncomingSkill.new(skill, tick + ENEMY_WINDUP))
		_log(FeedKind.WARNING, "%s 완성 — 적 %s이 「%s」 준비 중" % [pattern_label, War.label(skill.faction()), skill.name],
			"%d분 뒤 발동. 벽을 쌓아 막아라!" % ENEMY_WINDUP, skill.faction())


func _expire_cards() -> void:
	var expired := hand.filter(func(c: SkillCard) -> bool: return tick >= c.expires_at)
	for card: SkillCard in expired:
		hand.erase(card)
		_log(FeedKind.SYSTEM, "「%s」 기세 소멸" % card.skill.name, "때를 놓쳤다")


func _fire_incoming() -> void:
	var due := incoming.filter(func(s: IncomingSkill) -> bool: return tick >= s.fires_at)
	for s: IncomingSkill in due:
		if in_vi():
			break
		incoming.erase(s)
		_launch(s.skill, false)


func _run_active_skills() -> void:
	for active: ActiveSkill in _active.duplicate():
		if in_vi():
			break
		_wave(active)
	_active = _active.filter(func(a: ActiveSkill) -> bool: return a.waves_left > 0)


func _launch(skill: Skill, by_player: bool) -> void:
	var side := War.attack_side(skill.faction())
	sentiment = clampf(sentiment + skill.morale * War.direction(skill.faction()), -1.0, 1.0)
	if skill.wall > 0:
		var price := book.best(side)
		if price == OrderBook.NO_PRICE:
			price = Krx.prev_tick(last_price) if side == BUY else Krx.next_tick(last_price)
		book.place_limit(side, price, roundi(skill.wall * depth_unit), false, War.label(skill.faction()))
	var active := ActiveSkill.new(skill, skill.waves, by_player)
	_wave(active)
	if active.waves_left > 0:
		_active.append(active)


## 스킬 한 번: 진영 병력이 한 방향으로 시장가 물량을 쏟아붓는다.
func _wave(active: ActiveSkill) -> void:
	var skill := active.skill
	var side := War.attack_side(skill.faction())
	var from := last_price
	active.waves_left -= 1
	_market(side, roundi(skill.power * depth_unit), skill.name, active.by_player)
	var moved := Krx.ticks_between(from, last_price) * War.direction(skill.faction())
	if active.by_player:
		skill_ticks += maxi(0, moved)
	_blasts.append(SkillBlast.new(skill, from, last_price, active.by_player))
	_log(FeedKind.SKILL, "%s%s 「%s」 발동!" % ["내 " if active.by_player else "", War.label(skill.faction()), skill.name],
		"%s → %s (%s%d호가)" % [Krx.format_number(from), Krx.format_number(last_price), "+" if moved >= 0 else "", moved],
		skill.faction())


# ── 플레이어 행동 ────────────────────────────────────────────────

func _blocked(market := true) -> String:
	if is_over():
		return "장이 끝났습니다"
	if market and in_vi():
		return "VI 발동 중 — 시장가·스킬 봉인 (벽 쌓기만 가능)"
	return ""


## price 기준으로 새로 낼 수 있는 최대 수량 (순자산 1배 한도, 미체결 주문 포함).
@warning_ignore("integer_division")
func max_quantity(side: int, price: int) -> int:
	var capital := equity()
	if capital <= 0 or price <= 0:
		return 0
	var limit := capital / price
	var open := book.player_open_quantity(side)
	var room := limit - account.position - open if side == BUY else limit + account.position - open
	return maxi(0, room)


## 돌격: 진영 방향 시장가 주문 (주문 가능 수량의 fraction만큼).
func attack(fraction: float) -> ActionResult:
	var blocked := _blocked()
	if not blocked.is_empty():
		return ActionResult.new(false, blocked)
	var side := War.attack_side(faction)
	var reference := book.best(OrderBook.opposite(side))
	if reference == OrderBook.NO_PRICE:
		reference = last_price
	var quantity := floori(max_quantity(side, reference) * fraction)
	if quantity <= 0:
		return ActionResult.new(false, "주문 가능 수량이 없습니다")
	var filled := OrderBook.total_quantity_of(_market(side, quantity, "나", true))
	if filled == 0:
		return ActionResult.new(false, "받아줄 상대 호가가 없습니다")
	return ActionResult.new(true, "돌격! %s주 %s · 현재가 %s" % [
		Krx.format_number(filled), _verb(side), Krx.format_number(last_price)])


## 벽 쌓기: 진영 방향 지정가 주문. price를 안 주면 아군 최우선 호가에 쌓는다.
## 상대 호가에 닿는 가격이면 그 가격까지 즉시 체결된다.
func place_wall(fraction: float, price := OrderBook.NO_PRICE) -> ActionResult:
	var blocked := _blocked(false)
	if not blocked.is_empty():
		return ActionResult.new(false, blocked)
	var side := War.attack_side(faction)
	var at := price
	if at == OrderBook.NO_PRICE:
		at = book.best(side)
	if at == OrderBook.NO_PRICE:
		at = Krx.prev_tick(last_price) if side == BUY else Krx.next_tick(last_price)
	if at > upper_limit or at < lower_limit:
		return ActionResult.new(false, "가격제한폭 밖입니다")
	var opposite := book.best(OrderBook.opposite(side))
	var crosses := opposite != OrderBook.NO_PRICE and (at >= opposite if side == BUY else at <= opposite)
	if crosses and in_vi():
		return ActionResult.new(false, "VI 중에는 즉시 체결되는 주문을 낼 수 없습니다")
	var quantity := floori(max_quantity(side, at) * fraction)
	if quantity <= 0:
		return ActionResult.new(false, "주문 가능 수량이 없습니다")
	var from := last_price
	var placed := book.place_limit(side, at, quantity, true, "나")
	_apply(placed.fills)
	var filled := OrderBook.total_quantity_of(placed.fills)
	if filled > 0:
		_strikes.append(Strike.new(side, filled, from, last_price, "나", true))
	var resting := quantity - filled
	if filled == 0:
		return ActionResult.new(true, "%s원에 %s주 벽 구축" % [Krx.format_number(at), Krx.format_number(quantity)])
	return ActionResult.new(true, "%s주 즉시 %s%s" % [
		Krx.format_number(filled), _verb(side),
		", %s주는 벽으로 대기" % Krx.format_number(resting) if resting > 0 else ""])


## 내 미체결 주문 전부 취소.
func cancel_orders() -> ActionResult:
	var count := book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player)
	return ActionResult.new(count > 0, "주문 %d건 취소" % count if count > 0 else "취소할 주문이 없습니다")


## 보유 포지션을 시장가로 정리.
func close_position() -> ActionResult:
	var blocked := _blocked()
	if not blocked.is_empty():
		return ActionResult.new(false, blocked)
	var position := account.position
	if position == 0:
		return ActionResult.new(false, "정리할 포지션이 없습니다")
	var side := SELL if position > 0 else BUY
	# 내 벽과 맞체결되지 않도록 반대편 내 주문은 먼저 거둔다.
	var opposite := OrderBook.opposite(side)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player and o.side == opposite)
	var filled := OrderBook.total_quantity_of(_market(side, absi(position), "나", true))
	return ActionResult.new(filled > 0, "포지션 정리: %s주 %s" % [Krx.format_number(filled), _verb(side)])


## 손에 든 스킬 카드 사용.
func use_skill(index: int) -> ActionResult:
	var blocked := _blocked()
	if not blocked.is_empty():
		return ActionResult.new(false, blocked)
	if index < 0 or index >= hand.size():
		return ActionResult.new(false, "스킬 카드가 없습니다")
	var card: SkillCard = hand.pop_at(index)
	skills_used += 1
	_launch(card.skill, true)
	return ActionResult.new(true, "「%s」 발동!" % card.skill.name)


## 테스트·튜토리얼용: 스킬 카드를 직접 쥐여준다 (적 스킬이면 적이 준비한다).
func grant_skill(skill: Skill) -> void:
	_grant(skill)


func _verb(side: int) -> String:
	return "매수" if side == BUY else "매도"


# ── 종료 ────────────────────────────────────────────────────────

func _close_market() -> void:
	var winner := War.NEUTRAL
	if last_price > base_price:
		winner = War.Faction.BULL
	elif last_price < base_price:
		winner = War.Faction.BEAR
	_finish(winner, "장 마감 · 종가 %s원" % Krx.format_number(last_price))


func _finish(winner: int, reason: String) -> void:
	if is_over():
		return
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player)
	result = BattleResult.new()
	result.winner = winner
	result.reason = reason
	result.player_faction = faction
	result.base_price = base_price
	result.close_price = last_price
	result.starting_cash = starting_cash
	result.pnl = pnl()
	result.attack_value = attack_value
	result.defense_value = defense_value
	result.skills_used = skills_used
	result.skill_ticks = skill_ticks
	_log(FeedKind.SYSTEM, "%s — %s" % [reason, "무승부" if winner == War.NEUTRAL else War.label(winner) + " 승리"], "", winner)


func _log(kind: int, title: String, detail: String, tone := War.NEUTRAL, label := "") -> void:
	feed.push_front(FeedItem.new(clock(), kind, title, detail, label, tone))
	feed_serial += 1
	if feed.size() > 120:
		feed.pop_back()

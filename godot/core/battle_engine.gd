class_name BattleEngine
extends RefCounted
## 호가전쟁 한 판. 08:50 장전 동시호가부터 15:30 종가까지, step() 한 번이 1분이다.
##
## 하루의 흐름이 곧 판의 구조다.
##   08:50~09:00  장전 동시호가: 주문이 쌓이고 09:00에 시가 한 가격으로 체결
##   09:00~15:20  접속매매: 시장가가 호가를 먹는다. 급등락하면 VI(2분 단일가)
##   15:20~15:30  장 마감 동시호가: 쌓인 주문이 15:30 종가 한 가격으로 체결, 승패 결정

const OPEN_TICK := 10
const CLOSING_TICK := 390
const END_TICK := 400
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

enum Phase { PREOPEN, CONTINUOUS, VI, CLOSING, CLOSED }
const PHASE_LABELS := ["장전 동시호가", "장중", "VI 단일가", "장 마감 동시호가", "장 종료"]

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
	## [공시] [VI] [스킬] 같은 머리표.
	var label: String
	## 어느 편에 유리한 소식인지 (중립이면 War.NEUTRAL).
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


## 상대 편이 준비 중인 스킬.
class IncomingSkill:
	var skill: Skill
	var fires_at: int

	func _init(p_skill: Skill, p_fires_at: int) -> void:
		skill = p_skill
		fires_at = p_fires_at


## 화면 연출용: 스킬 한 방.
class SkillBlast:
	var skill: Skill
	var from: int
	var to: int
	var by_player: bool
	var tick: int

	func _init(p_skill: Skill, p_from: int, p_to: int, p_by_player: bool, p_tick: int) -> void:
		skill = p_skill
		from = p_from
		to = p_to
		by_player = p_by_player
		tick = p_tick


## 화면 연출용: 시장가 한 방. levels는 가격별로 먹은 수량.
## queued면 동시호가라 체결 없이 줄만 섰다.
class Strike:
	var side: int
	var quantity: int
	var from: int
	var to: int
	var tag: String
	var by_player: bool
	var levels: Dictionary
	var queued: bool

	func _init(p_side: int, p_quantity: int, p_from: int, p_to: int, p_tag: String,
			p_by_player: bool, p_levels := {}, p_queued := false) -> void:
		side = p_side
		quantity = p_quantity
		from = p_from
		to = p_to
		tag = p_tag
		by_player = p_by_player
		levels = p_levels
		queued = p_queued


## 화면 연출용: 동시호가가 한 가격으로 체결된 순간 (시가·VI·종가).
class Reveal:
	var label: String
	var from: int
	var to: int
	var volume: int
	var tick: int

	func _init(p_label: String, p_from: int, p_to: int, p_volume: int, p_tick: int) -> void:
		label = p_label
		from = p_from
		to = p_to
		volume = p_volume
		tick = p_tick


class ActionResult:
	var ok: bool
	var message: String

	func _init(p_ok: bool, p_message: String) -> void:
		ok = p_ok
		message = p_message


class BattleResult:
	## 이긴 편 (보합이면 War.NEUTRAL).
	var winner: int
	var reason: String
	var player_faction: int
	var base_price: int
	var open_price: int
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
var chatter: Chatter
var base_price: int
var upper_limit: int
var lower_limit: int
## 표준 호가 잔량 (주). 스킬·이벤트 물량의 단위.
var depth_unit: int

var tick := 0
var phase := Phase.PREOPEN
var last_price: int
var open_price := 0
## 동시호가 예상체결 {"price", "volume", "buy", "sell"}. 동시호가가 아니면 비어 있다.
var quote := {}
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
var _reveals: Array = []
var _last_fired := {}
var _price_history: Array[int] = []
var _buy_history: Array[int] = []
var _sell_history: Array[int] = []
var _tick_buy := 0
var _tick_sell := 0
var _last_move_chat := -99

## 정적 VI 기준가 (직전 단일가).
var vi_anchor: int
var _vi_until := 0
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
	chatter = Chatter.new(seed_value)
	base_price = company.base_price
	upper_limit = Krx.upper_limit(base_price)
	lower_limit = Krx.lower_limit(base_price)
	depth_unit = maxi(1, roundi(float(DEPTH_VALUE) / base_price))
	last_price = base_price
	account = PlayerAccount.new(p_cash)
	vi_anchor = base_price
	current_candle = Candle.new(0, base_price)
	book.auction = true
	_provide_liquidity(1.0)
	_log(FeedKind.SYSTEM, "장전 동시호가 시작", "기준가 %s · 상한가 %s · 하한가 %s" % [
		Krx.format_number(base_price), Krx.format_number(upper_limit), Krx.format_number(lower_limit)],
		War.NEUTRAL, "시장")


func is_over() -> bool:
	return result != null


func in_auction() -> bool:
	return phase == Phase.PREOPEN or phase == Phase.VI or phase == Phase.CLOSING


func phase_label() -> String:
	return PHASE_LABELS[phase]


## VI가 몇 분 남았는지.
func vi_remaining() -> int:
	return maxi(0, _vi_until - tick) if phase == Phase.VI else 0


## 동시호가가 끝나기까지 남은 분.
func auction_remaining() -> int:
	match phase:
		Phase.PREOPEN:
			return OPEN_TICK - tick
		Phase.VI:
			return vi_remaining()
		Phase.CLOSING:
			return END_TICK - tick
	return 0


func change_rate() -> float:
	return float(last_price - base_price) / base_price


## 지금 기준으로 보는 가격: 동시호가면 예상체결가, 아니면 현재가.
func reference_price() -> int:
	if in_auction() and quote.get("volume", 0) > 0:
		return quote.price
	return last_price


func clock_minutes() -> int:
	return 8 * 60 + 50 + tick


func clock() -> String:
	var minutes := clock_minutes()
	@warning_ignore("integer_division")
	var hours := minutes / 60
	return "%02d:%02d" % [hours, minutes % 60]


## 최근 20분 체결량 중 매수 체결 비중 (0~1).
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


func take_blasts() -> Array:
	var taken := _blasts.duplicate()
	_blasts.clear()
	return taken


func take_strikes() -> Array:
	var taken := _strikes.duplicate()
	_strikes.clear()
	return taken


func take_reveals() -> Array:
	var taken := _reveals.duplicate()
	_reveals.clear()
	return taken


# ── 시간 진행 ────────────────────────────────────────────────────

## 1분 진행.
func step() -> void:
	if is_over():
		return
	tick += 1
	_run_schedule()
	if tick == 1 or rng.randf() < news_rate * _news_factor():
		_fire_event(_draw_event())
	_mood = clampf(_mood * 0.97 + (rng.randf() - 0.5) * 0.08, -0.4, 0.4)
	_run_pressures()
	_run_active_skills()
	_fire_incoming()
	_provide_liquidity()
	_aggress()
	if phase == Phase.CLOSING and tick >= END_TICK - 3:
		_closing_rush()
	sentiment *= 0.97
	if _volatility_ticks > 0:
		_volatility_ticks -= 1
		if _volatility_ticks == 0:
			_volatility = 1.0
	_expire_cards()
	_record_tick()
	if tick > OPEN_TICK and tick <= CLOSING_TICK and (tick - OPEN_TICK) % TICKS_PER_CANDLE == 0:
		_close_candle()
	match phase:
		Phase.PREOPEN:
			if tick >= OPEN_TICK:
				_open_market()
		Phase.VI:
			if tick >= _vi_until:
				_end_vi()
	if phase == Phase.CONTINUOUS or phase == Phase.VI:
		_check_limits()
	if not is_over():
		if tick >= END_TICK:
			_close_market()
		elif tick >= CLOSING_TICK and phase != Phase.CLOSING:
			_start_closing()
	_update_quote()
	_chat_step()


func _record_tick() -> void:
	_price_history.append(last_price)
	_buy_history.append(_tick_buy)
	_sell_history.append(_tick_sell)
	if _buy_history.size() > 20:
		_buy_history.pop_front()
		_sell_history.pop_front()
	_tick_buy = 0
	_tick_sell = 0


## 장초반은 거칠고, 점심은 한산하고, 오후 막판은 다시 뜨겁다.
func _session_factor() -> float:
	var m := clock_minutes()
	if m < 9 * 60 + 30:
		return 1.3
	if m >= 11 * 60 + 30 and m < 13 * 60:
		return 0.6
	if m >= 14 * 60 + 30:
		return 1.2
	return 1.0


func _news_factor() -> float:
	var m := clock_minutes()
	return 0.5 if m >= 11 * 60 + 30 and m < 13 * 60 else 1.0


## 매수(+) / 매도(-) 쏠림. 심리 + 추세 추종 + 분위기 - 가치투자자의 되돌림.
func _bias() -> float:
	var momentum := 0.0
	if _price_history.size() >= 10:
		var past := _price_history[_price_history.size() - 10]
		momentum = clampf(Krx.ticks_between(past, last_price) / 30.0, -1.0, 1.0)
	var reversion := change_rate() * 4.0
	return clampf(sentiment + 0.2 * momentum + _mood - reversion, -0.9, 0.9)


# ── NPC: 유동성 공급(LP)과 시장가 공격 ────────────────────────────

## 기준가 위아래 10호가에 LP 잔량을 채운다. 쏠림이 있으면 불리한 쪽 호가가 얇아진다.
func _provide_liquidity(refill := 0.0) -> void:
	var bias := _bias()
	var anchor := reference_price()
	_refill_side(SELL, anchor, 1.0 - 0.3 * bias, refill)
	_refill_side(BUY, anchor, 1.0 + 0.3 * bias, refill)
	var high := Krx.shift_ticks(anchor, 20)
	var low := Krx.shift_ticks(anchor, -20)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.tag == "LP" and (o.price > high or o.price < low))


func _refill_side(side: int, anchor: int, factor: float, refill: float) -> void:
	# 동시호가에서는 서로 걸리지 않게 기준가 위아래로만 깐다.
	var opposite := OrderBook.NO_PRICE if book.auction else book.best(OrderBook.opposite(side))
	var price := anchor
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
	var intensity := _session_factor() if phase == Phase.CONTINUOUS else 0.8
	var count := 1 + rng.randi_range(0, 2)
	for i in count:
		var trader: Array = _pick_trader()
		var side := BUY if rng.randf() < 0.5 + 0.35 * bias else SELL
		var size: float = depth_unit * trader[2] * (0.3 + rng.randf())
		var quantity := roundi(size * _volatility * intensity)
		if quantity >= depth_unit * 4.5:
			_log(FeedKind.SYSTEM, "%s %s주 시장가 %s" % [trader[0], Krx.format_number(quantity), _verb(side)],
				"", War.of_side(side), "체결")
			if chatter.chance(0.7):
				chatter.say(clock(), "whale_buy" if side == BUY else "whale_sell")
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


## 막판 3분: 종가를 올리거나 누르려는 큰 물량이 들어온다.
func _closing_rush() -> void:
	if rng.randf() > 0.6:
		return
	var side := BUY if rng.randf() < 0.5 + 0.4 * _bias() else SELL
	_npc_market(side, roundi(depth_unit * rng.randf_range(2.0, 5.0)), "종가 관여")
	if chatter.chance(0.5):
		chatter.say(clock(), "closing_buy" if side == BUY else "closing_sell")


func _npc_market(side: int, quantity: int, tag: String) -> void:
	if quantity <= 0 or is_over():
		return
	var fills := _market(side, quantity, tag, false)
	if book.auction:
		return
	# 상·하한가에서 못 받은 물량은 그 가격에 잔량으로 쌓인다.
	var limit := _limit_for(side)
	var left := quantity - OrderBook.total_quantity_of(fills)
	if left > 0 and last_price == limit:
		book.place_limit(side, limit, left, false, "잔량")


func _limit_for(side: int) -> int:
	return upper_limit if side == BUY else lower_limit


## 시장가 주문. 접속매매면 호가를 먹고, 동시호가면 상·하한가에 걸어 둔다.
## by_player는 화면 연출(내가 한 일인지), own은 체결이 내 계좌로 들어가는지.
## 스킬은 내가 발동해도 편 전체의 물량이라 내 계좌와는 상관없다.
func _market(side: int, quantity: int, tag: String, by_player: bool, own := by_player) -> Array:
	if quantity <= 0:
		return []
	if book.auction:
		book.place_limit(side, _limit_for(side), quantity, own, tag, true)
		_strikes.append(Strike.new(side, quantity, last_price, last_price, tag, by_player, {}, true))
		_update_quote()
		return []
	var from := last_price
	var fills := book.place_market(side, quantity, _limit_for(side), own)
	_apply(fills)
	var filled := OrderBook.total_quantity_of(fills)
	if filled > 0:
		var levels := {}
		for f: OrderBook.Fill in fills:
			levels[f.price] = levels.get(f.price, 0) + f.quantity
		_strikes.append(Strike.new(side, filled, from, last_price, tag, by_player, levels))
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


func _update_quote() -> void:
	quote = book.auction_quote(last_price) if book.auction else {}


## 동시호가를 한 가격에 체결한다. 남은 시장가 주문은 취소.
func _uncross(label: String) -> void:
	var q := book.auction_quote(last_price)
	var from := last_price
	var volume: int = q.volume
	var price: int = q.price if volume > 0 else last_price
	var fills := book.uncross(price) if volume > 0 else []
	book.auction = false
	var aggressor := BUY if q.buy >= q.sell else SELL
	for f: OrderBook.Fill in fills:
		current_candle.update(f.price, f.quantity)
		if aggressor == BUY:
			_tick_buy += f.quantity
		else:
			_tick_sell += f.quantity
		if f.taker_is_player:
			_player_fill(BUY, f.price, f.quantity, true)
		if f.maker_is_player:
			_player_fill(SELL, f.price, f.quantity, true)
	last_price = price
	var mine := book.cancel_where(func(o: OrderBook.Order) -> bool: return o.market and o.is_player)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.market)
	if mine > 0:
		_log(FeedKind.SYSTEM, "%s 미체결 %s주 취소" % [label, Krx.format_number(mine)], "", War.NEUTRAL, "주문")
	_reveals.append(Reveal.new(label, from, price, volume, tick))
	quote = {}


func _open_market() -> void:
	var q := book.auction_quote(base_price)
	var price: int = q.price if q.get("volume", 0) > 0 else base_price
	current_candle = Candle.new(0, price)
	_uncross("시가")
	open_price = last_price
	vi_anchor = last_price
	phase = Phase.CONTINUOUS
	var gap := change_rate()
	_log(FeedKind.SYSTEM, "시가 %s (%s)" % [Krx.format_number(last_price), Krx.signed_percent(gap)], "",
		_tone_of(gap), "시장")
	chatter.say(clock(), "gap_up" if gap >= 0.015 else "gap_down" if gap <= -0.015 else "flat_open")


## 정적 VI: 직전 단일가 대비 10% 이상 움직이면 2분간 단일가 매매.
func _check_vi() -> void:
	if phase != Phase.CONTINUOUS or is_over():
		return
	if absi(last_price - vi_anchor) * 10 < vi_anchor:
		return
	var up := last_price > vi_anchor
	phase = Phase.VI
	book.auction = true
	_vi_until = tick + VI_DURATION
	_log(FeedKind.SYSTEM, "정적 VI 발동 %s" % Krx.format_number(last_price),
		"%s원 대비 %s. 2분 동안 주문을 모아 한 가격에 체결한다" % [Krx.format_number(vi_anchor), "10% 급등" if up else "10% 급락"],
		War.Faction.BULL if up else War.Faction.BEAR, "VI")
	chatter.say(clock(), "vi_up" if up else "vi_down")
	_update_quote()


func _end_vi() -> void:
	_uncross("VI 단일가")
	phase = Phase.CONTINUOUS
	vi_anchor = last_price
	_log(FeedKind.SYSTEM, "VI 해제, 단일가 %s" % Krx.format_number(last_price), "", War.NEUTRAL, "VI")


func _start_closing() -> void:
	phase = Phase.CLOSING
	book.auction = true
	current_candle = Candle.new(candles.size(), last_price)
	_log(FeedKind.SYSTEM, "장 마감 동시호가 시작",
		"15:30 종가가 기준가 %s보다 높으면 사자, 낮으면 팔자가 이긴다" % Krx.format_number(base_price),
		War.NEUTRAL, "시장")
	chatter.say(clock(), "closing")


func _close_market() -> void:
	if phase != Phase.CLOSING:
		_start_closing()
	_uncross("종가")
	candles.append(current_candle)
	phase = Phase.CLOSED
	var winner := War.NEUTRAL
	if last_price > base_price:
		winner = War.Faction.BULL
	elif last_price < base_price:
		winner = War.Faction.BEAR
	chatter.say(clock(), "close_up" if winner == War.Faction.BULL else "close_down" if winner == War.Faction.BEAR else "close_flat")
	_finish(winner, "종가 %s (%s)" % [Krx.format_number(last_price), Krx.signed_percent(change_rate())])


func _check_limits() -> void:
	upper_hold = upper_hold + 1 if last_price >= upper_limit else 0
	lower_hold = lower_hold + 1 if last_price <= lower_limit else 0
	if upper_hold == 1:
		_log(FeedKind.SYSTEM, "상한가 도달", "%d분 버티면 사자 완승" % LIMIT_HOLD_TO_WIN, War.Faction.BULL, "시장")
		chatter.say(clock(), "limit_up")
	if lower_hold == 1:
		_log(FeedKind.SYSTEM, "하한가 도달", "%d분 버티면 팔자 완승" % LIMIT_HOLD_TO_WIN, War.Faction.BEAR, "시장")
		chatter.say(clock(), "limit_down")
	if upper_hold >= LIMIT_HOLD_TO_WIN:
		_finish(War.Faction.BULL, "상한가 %d분 사수" % LIMIT_HOLD_TO_WIN)
	if lower_hold >= LIMIT_HOLD_TO_WIN:
		_finish(War.Faction.BEAR, "하한가 %d분 사수" % LIMIT_HOLD_TO_WIN)


# ── 종토방 ───────────────────────────────────────────────────────

func _chat_step() -> void:
	if is_over():
		return
	var t := clock()
	match phase:
		Phase.PREOPEN:
			if chatter.chance(0.3):
				chatter.say(t, "preopen")
			return
		Phase.CLOSING:
			if chatter.chance(0.3):
				chatter.say(t, "closing")
			return
		Phase.VI:
			return
	if _price_history.size() > 6 and tick - _last_move_chat > 6:
		var past := _price_history[_price_history.size() - 6]
		var move := float(last_price - past) / past
		if absf(move) >= 0.012:
			chatter.say(t, "surge" if move > 0 else "drop")
			_last_move_chat = tick
			return
	var lunch := _news_factor() < 1.0
	if not chatter.chance(0.07 if lunch else 0.12):
		return
	var pool := "ambient"
	if chatter.chance(0.35):
		var m := clock_minutes()
		if m < 9 * 60 + 30:
			pool = "morning"
		elif lunch:
			pool = "lunch"
		elif m >= 14 * 60 + 30:
			pool = "afternoon"
	var avg := Krx.floor_to_tick(roundi(last_price * (1.0 + chatter.rng.randf_range(0.03, 0.12))))
	chatter.say(t, pool, {"price": Krx.format_number(last_price), "avg": Krx.format_number(avg)})


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


## 이벤트를 바로 터뜨린다 (테스트·연출용으로 공개).
func fire_event(event: MarketEvent) -> void:
	_fire_event(event)


func _fire_event(e: MarketEvent) -> void:
	var tone := _tone_of(e.sentiment)
	var title := e.title_for(company.name)
	_log(FeedKind.NEWS, title, e.detail_for(company.name), tone, e.category_label())
	if chatter.chance(0.85):
		chatter.react_to_news(clock(), title, tone)
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
	var raw := roundi(reference_price() * (1.0 + e.wall_offset))
	var price := Krx.floor_to_tick(raw) if side == BUY else Krx.ceil_to_tick(raw)
	price = clampi(price, lower_limit, upper_limit)
	if not book.auction:
		var opposite := book.best(OrderBook.opposite(side))
		if opposite != OrderBook.NO_PRICE and (price >= opposite if side == BUY else price <= opposite):
			return
	book.place_limit(side, price, roundi(e.wall_size * depth_unit), false, e.wall_tag)


func _run_pressures() -> void:
	for p: Pressure in _pressures:
		var size := absf(p.levels) * depth_unit * (0.5 + rng.randf())
		_npc_market(BUY if p.levels > 0 else SELL, roundi(size), "뉴스 매매")
		p.ticks_left -= 1
	_pressures = _pressures.filter(func(p: Pressure) -> bool: return p.ticks_left > 0)


func _tone_of(value: float) -> int:
	if value > 0:
		return War.Faction.BULL
	if value < 0:
		return War.Faction.BEAR
	return War.NEUTRAL


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
	if chatter.chance(0.7):
		chatter.say(clock(), "skill_bull" if skill.faction() == War.Faction.BULL else "skill_bear", {"pattern": skill.name})
	if skill.faction() == faction:
		if hand.size() >= HAND_LIMIT:
			var dropped: SkillCard = hand.pop_front()
			_log(FeedKind.SKILL, "카드가 꽉 차서 %s 카드를 버렸다" % dropped.skill.name, "", War.NEUTRAL, "스킬")
		hand.append(SkillCard.new(skill, tick + CARD_LIFETIME))
		_log(FeedKind.SKILL, "%s 완성, 스킬 카드 획득" % skill.name,
			"%s. %d분 안에 써야 한다" % [skill.effect, CARD_LIFETIME], faction, "스킬")
	else:
		incoming.append(IncomingSkill.new(skill, tick + ENEMY_WINDUP))
		_log(FeedKind.WARNING, "%s 쪽 %s 완성" % [War.label(skill.faction()), skill.name],
			"%d분 뒤 %s" % [ENEMY_WINDUP, skill.effect], skill.faction(), "경고")


func _expire_cards() -> void:
	var expired := hand.filter(func(c: SkillCard) -> bool: return tick >= c.expires_at)
	for card: SkillCard in expired:
		hand.erase(card)
		_log(FeedKind.SKILL, "%s 카드 만료" % card.skill.name, "", War.NEUTRAL, "스킬")


func _fire_incoming() -> void:
	var due := incoming.filter(func(s: IncomingSkill) -> bool: return tick >= s.fires_at)
	for s: IncomingSkill in due:
		incoming.erase(s)
		_launch(s.skill, false)


func _run_active_skills() -> void:
	for active: ActiveSkill in _active.duplicate():
		_wave(active)
	_active = _active.filter(func(a: ActiveSkill) -> bool: return a.waves_left > 0)


func _launch(skill: Skill, by_player: bool) -> void:
	var side := War.attack_side(skill.faction())
	sentiment = clampf(sentiment + skill.morale * War.direction(skill.faction()), -1.0, 1.0)
	if skill.wall > 0:
		book.place_limit(side, _home_price(side), roundi(skill.wall * depth_unit), false, "%s 벽" % skill.name)
	var active := ActiveSkill.new(skill, skill.waves, by_player)
	_wave(active)
	if active.waves_left > 0:
		_active.append(active)


## 스킬 한 번: 편 전체가 한 방향으로 시장가 물량을 쏟아붓는다.
func _wave(active: ActiveSkill) -> void:
	var skill := active.skill
	var side := War.attack_side(skill.faction())
	var from := last_price
	var quantity := roundi(skill.power * depth_unit)
	active.waves_left -= 1
	var queued := book.auction
	_market(side, quantity, skill.name, active.by_player, false)
	var moved := Krx.ticks_between(from, last_price) * War.direction(skill.faction())
	if active.by_player:
		skill_ticks += maxi(0, moved)
	_blasts.append(SkillBlast.new(skill, from, last_price, active.by_player, tick))
	var who := "내 " if active.by_player else "%s 쪽 " % War.label(skill.faction())
	var detail := "동시호가에 %s주 %s" % [Krx.format_number(quantity), _verb(side)] if queued else \
		"%s → %s (%s%d호가)" % [Krx.format_number(from), Krx.format_number(last_price), "+" if moved >= 0 else "", moved]
	_log(FeedKind.SKILL, "%s%s 발동" % [who, skill.name], detail, skill.faction(), "스킬")


## 우리 편 벽을 세울 자리: 최우선 호가, 동시호가면 기준가 바로 아래(위).
func _home_price(side: int) -> int:
	if not book.auction:
		var best := book.best(side)
		if best != OrderBook.NO_PRICE:
			return best
	var anchor := reference_price()
	return Krx.prev_tick(anchor) if side == BUY else Krx.next_tick(anchor)


# ── 플레이어 행동 ────────────────────────────────────────────────

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


## 공격 기준가: 접속매매면 상대 최우선 호가, 동시호가면 예상체결가.
func attack_reference(side: int) -> int:
	if book.auction:
		return reference_price()
	var best := book.best(OrderBook.opposite(side))
	return last_price if best == OrderBook.NO_PRICE else best


## 돌격: 우리 편 방향 시장가 (살 수 있는 수량의 fraction만큼).
func attack(fraction: float) -> ActionResult:
	if is_over():
		return ActionResult.new(false, "장이 끝났다")
	var side := War.attack_side(faction)
	var quantity := floori(max_quantity(side, attack_reference(side)) * fraction)
	if quantity <= 0:
		return ActionResult.new(false, "더 낼 수 있는 수량이 없다")
	if book.auction:
		_market(side, quantity, "나", true)
		return ActionResult.new(true, "동시호가 시장가 %s %s주 접수" % [_verb(side), Krx.format_number(quantity)])
	var filled := OrderBook.total_quantity_of(_market(side, quantity, "나", true))
	if filled == 0:
		return ActionResult.new(false, "받아줄 호가가 없다")
	if filled >= depth_unit * 3 and chatter.chance(0.8):
		chatter.say(clock(), "big_buy" if side == BUY else "big_sell")
	return ActionResult.new(true, "시장가 %s %s주 체결, 현재가 %s" % [
		_verb(side), Krx.format_number(filled), Krx.format_number(last_price)])


## 벽: 우리 편 방향 지정가. price를 안 주면 우리 편 최우선 호가에 쌓는다.
## 접속매매 중 상대 호가에 닿는 가격이면 그 가격까지 바로 체결된다.
func place_wall(fraction: float, price := OrderBook.NO_PRICE) -> ActionResult:
	if is_over():
		return ActionResult.new(false, "장이 끝났다")
	var side := War.attack_side(faction)
	var at := price if price != OrderBook.NO_PRICE else _home_price(side)
	if at > upper_limit or at < lower_limit:
		return ActionResult.new(false, "상·하한가 밖 가격이다")
	var quantity := floori(max_quantity(side, at) * fraction)
	if quantity <= 0:
		return ActionResult.new(false, "더 낼 수 있는 수량이 없다")
	var from := last_price
	var placed := book.place_limit(side, at, quantity, true, "나")
	_apply(placed.fills)
	var filled := OrderBook.total_quantity_of(placed.fills)
	if filled > 0:
		var levels := {}
		for f: OrderBook.Fill in placed.fills:
			levels[f.price] = levels.get(f.price, 0) + f.quantity
		_strikes.append(Strike.new(side, filled, from, last_price, "나", true, levels))
	_update_quote()
	var resting := quantity - filled
	if filled == 0:
		return ActionResult.new(true, "%s원에 %s %s주 걸었다" % [Krx.format_number(at), _verb(side), Krx.format_number(quantity)])
	if resting == 0:
		return ActionResult.new(true, "%s주 바로 체결" % Krx.format_number(filled))
	return ActionResult.new(true, "%s주 바로 체결, %s주는 %s원에 걸림" % [
		Krx.format_number(filled), Krx.format_number(resting), Krx.format_number(at)])


## 내 미체결 주문 전부 취소.
func cancel_orders() -> ActionResult:
	var count := book.count_where(func(o: OrderBook.Order) -> bool: return o.is_player)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player)
	_update_quote()
	return ActionResult.new(count > 0, "미체결 %d건 취소" % count if count > 0 else "취소할 주문이 없다")


## 보유 포지션을 시장가로 정리.
func close_position() -> ActionResult:
	if is_over():
		return ActionResult.new(false, "장이 끝났다")
	var position := account.position
	if position == 0:
		return ActionResult.new(false, "정리할 포지션이 없다")
	var side := SELL if position > 0 else BUY
	# 내 벽과 맞체결되지 않도록 반대편 내 주문은 먼저 거둔다.
	var opposite := OrderBook.opposite(side)
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player and o.side == opposite)
	if book.auction:
		_market(side, absi(position), "나", true)
		return ActionResult.new(true, "동시호가 시장가 %s %s주 접수" % [_verb(side), Krx.format_number(absi(position))])
	var filled := OrderBook.total_quantity_of(_market(side, absi(position), "나", true))
	return ActionResult.new(filled > 0, "보유 %s주 시장가 %s" % [Krx.format_number(filled), _verb(side)])


## 손에 든 스킬 카드 사용.
func use_skill(index: int) -> ActionResult:
	if is_over():
		return ActionResult.new(false, "장이 끝났다")
	if index < 0 or index >= hand.size():
		return ActionResult.new(false, "스킬 카드가 없다")
	var card: SkillCard = hand.pop_at(index)
	skills_used += 1
	_launch(card.skill, true)
	return ActionResult.new(true, "%s 발동" % card.skill.name)


## 테스트·튜토리얼용: 스킬 카드를 직접 쥐여준다 (상대 편 스킬이면 상대가 준비한다).
func grant_skill(skill: Skill) -> void:
	_grant(skill)


func _verb(side: int) -> String:
	return "매수" if side == BUY else "매도"


# ── 종료 ────────────────────────────────────────────────────────

func _finish(winner: int, reason: String) -> void:
	if is_over():
		return
	phase = Phase.CLOSED
	book.auction = false
	book.cancel_where(func(o: OrderBook.Order) -> bool: return o.is_player)
	result = BattleResult.new()
	result.winner = winner
	result.reason = reason
	result.player_faction = faction
	result.base_price = base_price
	result.open_price = open_price
	result.close_price = last_price
	result.starting_cash = starting_cash
	result.pnl = pnl()
	result.attack_value = attack_value
	result.defense_value = defense_value
	result.skills_used = skills_used
	result.skill_ticks = skill_ticks
	_log(FeedKind.SYSTEM, reason, "무승부" if winner == War.NEUTRAL else "%s 승" % War.label(winner), winner, "시장")


func _log(kind: int, title: String, detail: String, tone := War.NEUTRAL, label := "") -> void:
	feed.push_front(FeedItem.new(clock(), kind, title, detail, label, tone))
	feed_serial += 1
	if feed.size() > 120:
		feed.pop_back()

class_name Trade
extends RefCounted
## 거래 한 건 (전투). 하루가 한 턴이다.
##
## 턴 순서: 전망표를 보고 → 카드로 주문을 낸다 → 장 마감을 누르면
## 그날 캔들이 시가 → (저가·고가) → 종가로 지나가며 닿은 주문이 체결되고 → 종가로 일일정산한다.
## 기한 안에 거래 손익이 목표에 닿으면 이기고, 계좌가 마진콜 선 아래로 떨어지면 판이 끝난다.

enum State { PLAYING, WON, FAILED, BUSTED }

const HAND_SIZE := 5
const ENERGY := 3
## 1계약 한 번 체결에 드는 수수료 (만원, 게임 값).
const FEE := 0.2
## 정예·보스 거래에서 신호 정확도가 조금 오른다 (매크로 이코노미스트).
const MACRO_BONUS := 0.05

var run: Run
var instrument: Instrument
var bars: Array[Bar]
var start_index: int
var days: int
var day := 0
var target: float
var title: String
var kind := "trade"
var node_id := ""
var start_account := 0.0
var day_start_account := 0.0

var position := Position.new()
var orders: Array[Order] = []
## 오늘 시가에 체결될 진입·청산: {delta, label}
var queued: Array[Dictionary] = []
## 오늘만 유효한 옵션: {kind, dir, strike, qty, units, center, premium}
var options: Array[Dictionary] = []
var close_at_close := false
var draw_pile: Array[Card] = []
var hand: Array[Card] = []
var discard: Array[Card] = []
var exhausted: Array[Card] = []
var energy := ENERGY
var played_entry := false
var forecast: Forecast
var state := State.PLAYING
var messages: Array[String] = []
## 보스 규칙 등 화면 위 띠에 뜨는 줄.
var rules: Array[String] = []
## 알아보지 못한 패턴 (거래가 끝나면 노트에 적힌다).
var unknown_patterns: Array[String] = []
## 오늘 손에 들어온 패턴.
var seen_patterns: Array[String] = []
## 날마다 결과 (복기용).
var days_log: Array[Dictionary] = []
var revenge_given := false
var rng := RandomNumberGenerator.new()


func _init(p_run: Run, node: Dictionary) -> void:
	run = p_run
	instrument = Instrument.of(node["inst"])
	bars = Market.bars(instrument.id)
	start_index = Market.index_on_or_after(instrument.id, node["date"])
	days = mini(int(node.get("days", 3)), bars.size() - start_index)
	target = float(node.get("target", 50))
	title = node.get("title", instrument.name)
	kind = node.get("kind", "trade")
	node_id = node.get("id", "")
	for rule: String in node.get("rules", []):
		rules.append(rule)
	rng.seed = hash("%s|%s|%s" % [run.run_seed, node_id, node["date"]])


func start() -> void:
	start_account = run.account
	draw_pile = run.deck.duplicate()
	_shuffle(draw_pile)
	run.notes.learn("futures")
	run.notes.learn("multiplier")
	_begin_day()


# ── 조회 ──────────────────────────────────────────────────────────

func today() -> Bar:
	return bars[start_index + mini(day, days - 1)]


func yesterday() -> Bar:
	return bars[start_index + mini(day, days - 1) - 1]


## 오늘 앞까지 마감된 봉들 (차트용).
func history_bars(count := 30) -> Array[Bar]:
	var end := start_index + day
	return bars.slice(maxi(0, end - count), end)


func expected_span() -> float:
	return forecast.expected if forecast else Market.average_range(bars, start_index + day)


## 오늘 시가 체결까지 반영한 계약 수.
func planned_qty() -> int:
	var total := position.qty
	for q in queued:
		total += int(q["delta"])
	return total


func trade_pnl() -> float:
	return run.account - start_account


func equity_at(price: float) -> float:
	return run.account + position.unrealized(price, instrument.multiplier) + option_value(price)


## 오늘 산 옵션을 이 가격에서 행사하면 받을 돈.
func option_value(price: float) -> float:
	var total := 0.0
	for option in options:
		if option["kind"] == "protect":
			total += maxf(0.0, (float(option["strike"]) - price) * int(option["dir"])) * int(option["qty"]) * instrument.multiplier
		else:
			total += absf(price - float(option["center"])) * int(option["units"]) * instrument.multiplier
	return total


## 계좌가 마진콜 선에 닿는 가격. 포지션이 없으면 NAN.
func margin_call_price() -> float:
	if position.is_flat():
		return NAN
	return position.basis + (run.margin_line - run.account) / (position.qty * instrument.multiplier)


## 명목 금액 ÷ 계좌.
func leverage() -> float:
	var notional := absf(float(position.qty)) * yesterday().close * instrument.multiplier
	return notional / maxf(run.account, 1.0)


func cost_of(card: Card) -> int:
	if card.is_entry() and _hand_has("h_fomo"):
		return 0
	return card.base_cost()


func is_over() -> bool:
	return state != State.PLAYING


# ── 턴 ────────────────────────────────────────────────────────────

func _begin_day() -> void:
	var index := start_index + day
	var bar := bars[index]
	var prev := bars[index - 1]
	day_start_account = run.account
	var span := Market.average_range(bars, index, 10)
	forecast = Forecast.new(bar, prev, span, "%s|%s|%s" % [run.run_seed, instrument.id, bar.date])
	var accuracy_bonus := MACRO_BONUS if kind != "trade" and run.has_member("macro") else 0.0
	accuracy_bonus += float(run.flags.get("insight_" + node_id, 0.0))
	if run.has_member("quant"):
		forecast.add_signal("퀀트", 0.62 + accuracy_bonus)
	if run.has_member("crowd"):
		forecast.add_signal("개미 커뮤니티", 0.58, true)
	if run.has_member("foreign_desk") and instrument.id == "usdkrw":
		forecast.add_signal("외국계 데스크", 0.6)
	played_entry = false
	close_at_close = false
	options.clear()
	seen_patterns.clear()
	_draw(HAND_SIZE)
	energy = ENERGY + (int(run.flags.get("alert", 0)) if day == 0 else 0)
	if day == 0:
		run.flags.erase("alert")
	energy -= _count_in_hand("h_fomo") + _count_in_hand("h_fear")
	energy = maxi(energy, 1)
	_add_pattern_cards(index)


func _add_pattern_cards(index: int) -> void:
	for id in Patterns.detect(bars, index):
		if run.notes.level(id) >= 1:
			if seen_patterns.size() < 2:
				hand.append(Card.new(Patterns.CARD_OF[id]))
				seen_patterns.append(id)
				run.stats["patterns"] = int(run.stats.get("patterns", 0)) + 1
		elif not unknown_patterns.has(id):
			unknown_patterns.append(id)


func _draw(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			if discard.is_empty():
				return
			draw_pile = discard.duplicate()
			discard.clear()
			_shuffle(draw_pile)
		var card: Card = draw_pile.pop_back()
		hand.append(card)
		if card.id == "h_average":
			_average_down()


## 물타기 충동: 손실 중인 포지션에 1계약이 저절로 붙는다.
func _average_down() -> void:
	var qty := planned_qty()
	if qty == 0:
		return
	if position.open_profit(yesterday().close, instrument.multiplier) < 0.0:
		queued.append({"delta": signi(qty), "label": "물타기 충동"})
		messages.append("물타기 충동 — 손실 중인 포지션에 1계약이 붙었다.")
		run.notes.use("averaging_down")


## 이 카드를 지금 낼 수 없는 이유. 낼 수 있으면 빈 문자열.
func why_not(card: Card) -> String:
	if state != State.PLAYING:
		return "거래가 끝났다"
	if not card.playable():
		return "낼 수 없는 카드다"
	if cost_of(card) > energy:
		return "주문 한도가 모자란다"
	var qty := planned_qty()
	match card.id:
		"stop", "take", "trail", "option", "half", "moc", "leverage", "close":
			if qty == 0:
				return "포지션이 없다"
		"pyramid":
			if qty == 0 or position.is_flat() or signi(position.qty) != signi(qty):
				return "수익 중인 포지션이 없다"
			if position.open_profit(yesterday().close, instrument.multiplier) <= 0.0:
				return "수익 중인 포지션이 없다"
	var add := _entry_delta(card)
	if add != 0 and absi(qty + add) > absi(qty) and _max_contracts() < absi(qty + add):
		return "증거금이 모자란다"
	return ""


## 진입 카드가 더할 계약 수 (방향 포함). 진입이 아니면 0.
func _entry_delta(card: Card) -> int:
	var qty := planned_qty()
	match card.id:
		"long":
			return instrument.contracts_for(card.value("budget"))
		"short":
			return -instrument.contracts_for(card.value("budget"))
		"pyramid":
			return signi(qty) * instrument.contracts_for(card.value("budget"))
		"contra":
			return _contra_dir() * instrument.contracts_for(card.value("budget"))
		"leverage":
			return qty
	if card.type() == "pattern":
		return int(card.def()["dir"]) * instrument.contracts_for(card.def()["budget"])
	return 0


func _contra_dir() -> int:
	var prev := yesterday()
	return -1 if prev.close >= prev.open else 1


func _max_contracts() -> int:
	return int(floor(maxf(run.account, 0.0) / instrument.margin))


func play(index: int) -> String:
	if index < 0 or index >= hand.size():
		return "없는 카드"
	var card := hand[index]
	var reason := why_not(card)
	if not reason.is_empty():
		return reason
	energy -= cost_of(card)
	hand.remove_at(index)
	var span := expected_span()
	var prev_close := yesterday().close
	var qty := planned_qty()
	var dir := signi(qty)
	var entry := _entry_delta(card)
	match card.id:
		"long", "short", "pyramid", "leverage":
			_queue(entry, card.name())
		"contra":
			var d := _contra_dir()
			_queue(entry, card.name())
			orders.append(Order.stop(d, prev_close - d * card.value("dist") * span))
		"stop":
			orders.append(Order.stop(dir, prev_close - dir * card.value("dist") * span))
		"take":
			orders.append(Order.take(dir, prev_close + dir * card.value("dist") * span))
		"trail":
			orders.append(Order.trailing(dir, prev_close, card.value("dist") * span))
		"close":
			_queue(-qty, "청산")
		"half":
			var half := qty / 2 if absi(qty) > 1 else qty
			_queue(-half, "분할 청산")
		"moc":
			close_at_close = true
		"wait", "research":
			pass
		"foreign":
			forecast.add_signal("외국인 수급", card.value("acc"))
		"option":
			var premium: float = card.value("premium") * span * instrument.multiplier * absi(qty)
			run.account -= premium
			options.append({"kind": "protect", "dir": dir, "qty": absi(qty),
				"strike": prev_close - dir * card.value("strike") * span, "premium": premium})
			messages.append("보호 옵션 권리값 %s" % Fmt.signed_money(-premium))
		"straddle":
			var units: int = card.value("units")
			var paid: float = card.value("premium") * span * instrument.multiplier * units
			run.account -= paid
			options.append({"kind": "straddle", "units": units, "center": prev_close, "premium": paid})
			messages.append("스트래들 권리값 %s" % Fmt.signed_money(-paid))
	if card.id == "research":
		forecast.add_signal("리서치", card.value("acc"))
	if card.type() == "pattern":
		var d: int = card.def()["dir"]
		_queue(entry, card.name())
		if card.def().has("dist"):
			orders.append(Order.stop(d, prev_close - d * float(card.def()["dist"]) * span))
		run.notes.use(card.def()["pattern"])
	var draw: int = card.value("draw", 0)
	if draw > 0:
		_draw(draw)
	if card.is_entry() or card.type() == "pattern":
		played_entry = true
	var note: String = card.def().get("note", "")
	if not note.is_empty():
		run.notes.use(note)
	if card.ethereal:
		exhausted.append(card)
	else:
		discard.append(card)
	return ""


func _queue(delta: int, label: String) -> void:
	if delta == 0:
		return
	queued.append({"delta": delta, "label": label})


## 장을 마칠 수 없는 이유. 마칠 수 있으면 빈 문자열.
func why_not_end() -> String:
	if state != State.PLAYING:
		return "거래가 끝났다"
	if _hand_has("h_revenge") and not played_entry:
		for card in hand:
			if (card.is_entry() or card.type() == "pattern") and why_not(card).is_empty():
				return "복수 매매 — 진입을 해야 장을 마칠 수 있다"
	return ""


## 장 마감. 그날 결과를 돌려준다.
func end_day() -> Dictionary:
	if not why_not_end().is_empty():
		return {}
	var result := _resolve_day()
	for card in hand:
		if card.ethereal:
			exhausted.append(card)
		else:
			discard.append(card)
	hand.clear()
	day += 1
	if state == State.PLAYING:
		if trade_pnl() >= target:
			state = State.WON
		elif day >= days:
			state = State.FAILED
	if state != State.PLAYING and not position.is_flat():
		var bar := bars[start_index + day - 1]
		var fee := _fill_raw(-position.qty, bar.close)
		result["events"].append({"t": 3.0, "price": bar.close, "kind": "close", "text": "거래 끝 · 종가 정리", "amount": -fee})
		result["account_after"] = run.account
	result["state"] = state
	result["trade_pnl"] = trade_pnl()
	if state == State.PLAYING:
		_begin_day()
	return result


# ── 장중 처리 ─────────────────────────────────────────────────────

func _resolve_day() -> Dictionary:
	var bar := today()
	var points := bar.path()
	var events: Array[Dictionary] = []
	var mult := instrument.multiplier
	var before := run.account
	var fees := 0.0
	var realized := 0.0

	for q in queued:
		var r := _fill_event(events, int(q["delta"]), points[0], 0.0, "시가 체결 · " + String(q["label"]))
		realized += r[0]
		fees += r[1]
	queued.clear()
	for order in _active_orders():
		if position.is_flat():
			break
		if order.hit_at(points[0]):
			var r := _fill_event(events, -position.qty, points[0], 0.0, order.label() + " · 시가 갭")
			realized += r[0]
			fees += r[1]
			run.notes.use("gap")
	for order in orders:
		order.follow(points[0])
	_check_limits(events, points[0], points[0], 0.0)

	for s in 3:
		var a: float = points[s]
		var b: float = points[s + 1]
		if state == State.BUSTED:
			break
		var hits: Array[Order] = []
		for order in _active_orders():
			var favorable := (b - a) * order.dir > 0.0
			if order.kind == Order.Kind.TRAIL and favorable:
				continue
			if order.crossed(a, b):
				hits.append(order)
		hits.sort_custom(func(x: Order, y: Order) -> bool: return absf(x.price - a) < absf(y.price - a))
		for order in hits:
			if position.is_flat() or order.dir != position.direction():
				continue
			var t := s + absf(order.price - a) / maxf(absf(b - a), 0.000001)
			var r := _fill_event(events, -position.qty, order.price, t, order.label() + " 체결")
			realized += r[0]
			fees += r[1]
		_check_limits(events, a, b, float(s))
		for order in orders:
			order.follow(b)

	var close := points[3]
	if state != State.BUSTED:
		if close_at_close and not position.is_flat():
			var r := _fill_event(events, -position.qty, close, 3.0, "종가 청산")
			realized += r[0]
			fees += r[1]
		var option_pay := 0.0
		for option in options:
			var pay := 0.0
			if option["kind"] == "protect":
				var gap: float = (option["strike"] - close) * option["dir"]
				pay = maxf(0.0, gap) * option["qty"] * mult
			else:
				pay = absf(close - float(option["center"])) * option["units"] * mult
			if pay > 0.0:
				run.account += pay
				option_pay += pay
				events.append({"t": 3.0, "price": close, "kind": "option", "text": "옵션 행사", "amount": pay})
		var settle := position.settle(close, mult)
		run.account += settle
		events.append({"t": 3.0, "price": close, "kind": "settle", "text": "일일정산", "amount": settle})
		if run.account < run.margin_line:
			state = State.BUSTED
	var summary := {
		"bar": bar,
		"points": points,
		"events": events,
		"account_before": before,
		"account_after": run.account,
		"day_pnl": run.account - day_start_account,
		"fees": fees,
		"realized": realized,
		"state": state,
	}
	days_log.append({"date": bar.date, "account": run.account, "pnl": run.account - day_start_account})
	run.record(bar.date)
	var loss_line := -maxf(150.0, run.account * 0.05)
	if state == State.PLAYING and summary["day_pnl"] < loss_line and not revenge_given:
		revenge_given = true
		run.deck.append(Card.new("h_revenge"))
		messages.append("크게 잃었다. 덱에 복수 매매가 들어왔다.")
		run.notes.use("revenge")
	return summary


func _active_orders() -> Array[Order]:
	var list: Array[Order] = []
	for order in orders:
		if not position.is_flat() and order.dir == position.direction():
			list.append(order)
	return list


## 계좌 선(마진콜)과 리스크 매니저 손실 한도를 a→b 구간에서 확인한다.
func _check_limits(events: Array[Dictionary], a: float, b: float, s: float) -> void:
	if position.is_flat():
		return
	var lines: Array = []
	if run.has_member("risk"):
		lines.append(["risk", day_start_account - maxf(100.0, day_start_account * 0.05)])
	lines.append(["floor", run.margin_line])
	for line: Array in lines:
		if position.is_flat():
			return
		var threshold: float = line[1]
		var hit := _first_below(a, b, threshold)
		if hit < 0.0:
			continue
		var price := lerpf(a, b, hit)
		var t := s + hit
		if line[0] == "risk":
			_fill_event(events, -position.qty, price, t, "리스크 매니저 손절")
		else:
			_fill_event(events, -position.qty, price, t, "마진콜 · 반대매매")
			var salvage := option_value(price)
			if salvage > 0.0:
				run.account += salvage
				events.append({"t": t, "price": price, "kind": "option", "text": "옵션 정리", "amount": salvage})
			options.clear()
			state = State.BUSTED
			run.notes.learn("margin_call")


## a→b 구간에서 평가 계좌가 threshold 아래로 처음 내려가는 위치 (0~1). 없으면 -1.
## 옵션이 있으면 직선이 아니라서 잘게 나눠 찾고 이분법으로 다듬는다.
func _first_below(a: float, b: float, threshold: float) -> float:
	if equity_at(a) < threshold:
		return 0.0
	const STEPS := 48
	var previous := 0.0
	for i in range(1, STEPS + 1):
		var t := float(i) / STEPS
		if equity_at(lerpf(a, b, t)) < threshold:
			var lo := previous
			var hi := t
			for k in 20:
				var mid := (lo + hi) * 0.5
				if equity_at(lerpf(a, b, mid)) < threshold:
					hi = mid
				else:
					lo = mid
			return hi
		previous = t
	return -1.0


## 체결하고 사건을 남긴다. [실현 손익, 수수료]
func _fill_event(events: Array[Dictionary], delta: int, price: float, t: float, text: String) -> Array:
	if delta == 0:
		return [0.0, 0.0]
	var before := run.account
	var fee := _fill_raw(delta, price)
	var realized := run.account - before + fee
	events.append({"t": t, "price": price, "kind": "fill", "delta": delta, "text": text, "amount": realized, "fee": fee})
	return [realized, fee]


## 체결만 한다. 수수료를 돌려준다.
func _fill_raw(delta: int, price: float) -> float:
	var realized := position.fill(delta, price, instrument.multiplier)
	var fee := FEE * absi(delta) * (0.5 if run.has_member("broker") else 1.0)
	run.account += realized - fee
	if position.is_flat():
		orders.clear()
	return fee


func _hand_has(id: String) -> bool:
	return _count_in_hand(id) > 0


func _count_in_hand(id: String) -> int:
	var count := 0
	for card in hand:
		if card.id == id:
			count += 1
	return count


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp

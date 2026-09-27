extends SceneTree
## 밸런스 시뮬레이터: 거래 칸마다 봇 두 종류로 여러 번 돌려 목표 달성률을 본다.
##   godot --headless --path chart_dungeon --script res://tools/balance_sim.gd -- [판 수]
##
## 봇
##   careful  전망 확률이 55%를 넘는 쪽으로 들어가고 손절·익절을 건다.
##   random   아무 진입 카드나 낸다.


func _initialize() -> void:
	var runs := 30
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		runs = int(args[0])
	var acts := Era2020.acts()
	for act: Dictionary in acts:
		print("== ", act["title"])
		for column: Array in act["columns"]:
			for node: Dictionary in column:
				if not node.has("inst"):
					continue
				var line := "%-10s %-4s %-7s 목표 %4d 잠재 %5d" % [node["id"], node["kind"], node["inst"], int(node["target"]), roundi(_potential(node))]
				for bot in ["careful", "random"]:
					var wins := 0
					var busts := 0
					var pnl := 0.0
					for i in runs:
						var result := _play(node, bot, 100 + i)
						if result[0] == Trade.State.WON:
							wins += 1
						elif result[0] == Trade.State.BUSTED:
							busts += 1
						pnl += result[1]
					line += "  %s %3d%% 평균 %6.1f 파산 %d" % [bot, roundi(100.0 * wins / runs), pnl / runs, busts]
				print(line)
	quit()


func _play(node: Dictionary, bot: String, seed_value: int) -> Array:
	var notes := Notes.new()
	notes.autosave = false
	for id in ["hammer", "shooting_star", "bullish_engulfing", "bearish_engulfing", "golden_cross", "dead_cross", "double_bottom", "double_top"]:
		notes.learn(id)
	var run := Run.new(seed_value, notes)
	var trade := run.start_trade(node)
	while not trade.is_over():
		if bot == "careful":
			_careful(trade)
		else:
			_random(trade)
		if not trade.why_not_end().is_empty():
			for i in trade.hand.size():
				if trade.hand[i].is_entry() and trade.why_not(trade.hand[i]).is_empty():
					trade.play(i)
					break
		trade.end_day()
	return [trade.state, trade.trade_pnl()]


## 매일 방향을 다 맞히고 기본 진입(증거금 250만)으로 종가까지 들고 갔을 때의 손익.
func _potential(node: Dictionary) -> float:
	var inst := Instrument.of(node["inst"])
	var bars := Market.bars(node["inst"])
	var start := Market.index_on_or_after(node["inst"], node["date"])
	var qty := inst.contracts_for(250.0)
	var total := 0.0
	for i in range(start, start + int(node["days"])):
		total += absf(bars[i].close - bars[i].open) * qty * inst.multiplier
	return total


func _careful(trade: Trade) -> void:
	var p := trade.forecast.up_probability()
	var want := 0
	if p > 0.55:
		want = 1
	elif p < 0.45:
		want = -1
	if want != 0 and trade.planned_qty() * want < 0:
		_play_id(trade, "close")
	for order in ["foreign", "research", "wait"]:
		_play_id(trade, order)
	p = trade.forecast.up_probability()
	want = 1 if p > 0.55 else (-1 if p < 0.45 else 0)
	if want != 0 and trade.planned_qty() * want <= 0:
		for card_id in (["long", "p_rebound", "p_trend_up", "p_golden", "p_w"] if want > 0 else ["short", "p_fall", "p_trend_down", "p_dead", "p_m"]):
			if _play_id(trade, card_id):
				break
	if trade.planned_qty() != 0 and trade.orders.is_empty():
		_play_id(trade, "stop")
		_play_id(trade, "take")


func _random(trade: Trade) -> void:
	var tries := 0
	while tries < 6:
		tries += 1
		if trade.hand.is_empty():
			return
		var i := randi() % trade.hand.size()
		trade.play(i)


func _play_id(trade: Trade, id: String) -> bool:
	for i in trade.hand.size():
		if trade.hand[i].id == id and trade.why_not(trade.hand[i]).is_empty():
			return trade.play(i).is_empty()
	return false

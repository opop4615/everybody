extends TestCase
## 거래 엔진: 체결 순서, 일일정산, 갭, 마진콜, 신호, 습관.


func _run(account := 3000.0) -> Run:
	var notes := Notes.new()
	notes.autosave = false
	var run := Run.new(7, notes)
	run.account = account
	return run


func _trade(run: Run, inst: String, date: String, days := 3, target := 10000.0) -> Trade:
	var trade := Trade.new(run, {"id": "t_" + date, "kind": "trade", "inst": inst, "date": date, "days": days, "target": target})
	trade.start()
	trade.hand.clear()
	trade.energy = 3
	return trade


func _give(trade: Trade, id: String) -> int:
	trade.hand.append(Card.new(id))
	return trade.hand.size() - 1


func test_long_settles_at_close() -> void:
	var run := _run()
	var trade := _trade(run, "usdkrw", "2020-03-16")
	var bar := trade.today()
	eq(trade.play(_give(trade, "long")), "", "롱을 낼 수 있다")
	eq(trade.planned_qty(), 6, "증거금 250만이면 달러 6계약")
	var result := trade.end_day()
	var expected := (bar.close - bar.open) * 6 - 6 * Trade.FEE
	check(absf(run.account - 3000.0 - expected) < 0.001, "시가에 사서 종가 정산: %s vs %s" % [run.account - 3000.0, expected])
	eq(trade.position.qty, 6)
	check(absf(trade.position.basis - bar.close) < 0.0001, "정산 뒤 basis 는 종가")
	check(result["events"].size() >= 2, "시가 체결과 정산 사건")


func test_take_profit_fills_on_the_way_up() -> void:
	var run := _run()
	var trade := _trade(run, "usdkrw", "2020-03-16")
	var bar := trade.today()
	trade.play(_give(trade, "long"))
	trade.orders.append(Order.take(1, 1220.0))
	trade.end_day()
	eq(trade.position.qty, 0, "익절이 체결돼 포지션이 없다")
	var expected := (1220.0 - bar.open) * 6 - 12 * Trade.FEE
	check(absf(run.account - 3000.0 - expected) < 0.001, "1,220에 익절: %s vs %s" % [run.account - 3000.0, expected])


func test_stop_gap_fills_at_open() -> void:
	var run := _run()
	var trade := _trade(run, "wti", "2020-04-17", 2)
	trade.play(_give(trade, "long"))
	trade.end_day()
	eq(trade.position.qty, 2, "4월 17일 롱 2계약")
	var friday := trade.yesterday().close
	trade.orders.append(Order.stop(1, 18.0))
	var result := trade.end_day()
	eq(trade.position.qty, 0, "손절로 나갔다")
	var gap_event: Dictionary = {}
	for event: Dictionary in result["events"]:
		if String(event["text"]).contains("갭"):
			gap_event = event
	check(not gap_event.is_empty(), "갭 손절 사건이 있다")
	var open := trade.bars[trade.start_index + 1].open
	check(absf(float(gap_event.get("price", 0.0)) - open) < 0.0001, "손절 18이 아니라 시가에 체결")
	check(open < 18.0 and friday > 18.0, "시가가 손절선 아래에서 열렸다")


func test_margin_line_busts_the_run() -> void:
	var run := _run(2000.0)
	var trade := _trade(run, "wti", "2020-04-17", 2)
	trade.play(_give(trade, "long"))
	trade.end_day()
	check(trade.state == Trade.State.PLAYING, "하루는 버틴다")
	var result := trade.end_day()
	eq(result["state"], Trade.State.BUSTED, "4월 20일 마진콜")
	eq(trade.position.qty, 0, "반대매매로 정리")
	check(run.account < run.margin_line + 1.0, "계좌가 선 근처에서 멈춘다")
	var reward := run.finish_trade(trade)
	check(run.over, "판이 끝난다")
	check(reward["cards"].is_empty(), "보상 없음")


func test_risk_manager_cuts_daily_loss() -> void:
	var run := _run()
	run.members.append("risk")
	var trade := _trade(run, "wti", "2020-04-17", 2)
	trade.play(_give(trade, "long"))
	trade.end_day()
	var before := run.account
	var result := trade.end_day()
	check(result["state"] != Trade.State.BUSTED, "리스크 매니저가 있으면 살아남는다")
	check(before - run.account < 400.0, "하루 손실이 한도 근처에서 멈춘다: %s" % (before - run.account))


func test_win_closes_positions() -> void:
	var run := _run()
	var trade := _trade(run, "usdkrw", "2020-03-16", 3, 20.0)
	trade.play(_give(trade, "long"))
	var result := trade.end_day()
	eq(result["state"], Trade.State.WON, "목표 20만을 넘겼다")
	eq(trade.position.qty, 0, "이기면 포지션을 정리한다")
	var reward := run.finish_trade(trade)
	eq(reward["cards"].size(), 3, "카드 셋 중 하나를 고른다")
	check(int(reward["bonus"]) >= 20, "성과급")


func test_deadline_fails_and_adds_habit() -> void:
	var run := _run()
	var habits_before := run.habits().size()
	var trade := _trade(run, "usdkrw", "2020-03-16", 1, 9999.0)
	var result := trade.end_day()
	eq(result["state"], Trade.State.FAILED, "기한이 지났다")
	run.finish_trade(trade)
	eq(run.habits().size(), habits_before + 1, "미달이면 습관 카드")


func test_forecast_is_calibrated() -> void:
	var hits := 0
	var total := 0
	var bars := Market.bars("usdkrw")
	for seed_value in 12:
		for i in range(20, bars.size()):
			var f := Forecast.new(bars[i], bars[i - 1], 5.0, "cal|%d|%d" % [seed_value, i])
			var s := f.add_signal("퀀트", 0.62)
			total += 1
			if s["says_up"] == f.true_up:
				hits += 1
	var rate := float(hits) / total
	check(absf(rate - 0.62) < 0.03, "신호 적중률 %.3f (%d개)" % [rate, total])
	var both := Forecast.new(bars[40], bars[39], 5.0, "x")
	both.signals = [{"source": "a", "says_up": true, "accuracy": 0.62, "contrarian": false},
		{"source": "b", "says_up": true, "accuracy": 0.62, "contrarian": false}]
	check(both.up_probability() > 0.7, "같은 쪽 신호 둘이면 확률이 오른다")
	both.signals = [{"source": "c", "says_up": false, "accuracy": 0.6, "contrarian": true}]
	check(both.up_probability() > 0.5, "역지표: 개미가 내린다고 하면 오를 쪽")


func test_revenge_blocks_end_until_entry() -> void:
	var run := _run()
	var trade := _trade(run, "gold", "2020-03-02")
	_give(trade, "h_revenge")
	var entry := _give(trade, "long")
	check(not trade.why_not_end().is_empty(), "진입 전에는 장을 못 마친다")
	trade.play(entry)
	eq(trade.why_not_end(), "", "진입하면 마칠 수 있다")


func test_fomo_and_fear_cut_energy() -> void:
	var run := _run()
	run.deck = [Card.new("h_fomo"), Card.new("h_fear"), Card.new("long"), Card.new("long"), Card.new("short")]
	var trade := Trade.new(run, {"id": "x", "kind": "trade", "inst": "gold", "date": "2020-03-02", "days": 2, "target": 999})
	trade.start()
	eq(trade.energy, 1, "3 - 1 - 1")
	var long_index := -1
	for i in trade.hand.size():
		if trade.hand[i].id == "long":
			long_index = i
	eq(trade.cost_of(trade.hand[long_index]), 0, "FOMO면 진입 비용 0")


func test_pattern_cards_need_notes() -> void:
	var run := _run()
	var bars := Market.bars("gold")
	var found_day := ""
	for i in range(30, bars.size()):
		if Patterns.detect(bars, i).has("hammer"):
			found_day = bars[i].date
			break
	check(not found_day.is_empty(), "금 일봉 어딘가에 망치형이 있다")
	var unknown := _trade(run, "gold", found_day)
	check(unknown.unknown_patterns.has("hammer"), "모르면 카드 없이 기록만")
	run.notes.learn("hammer")
	var trade := Trade.new(run, {"id": "y", "kind": "trade", "inst": "gold", "date": found_day, "days": 2, "target": 999})
	trade.start()
	var has_card := false
	for card in trade.hand:
		if card.id == "p_rebound":
			has_card = true
	check(has_card, "알면 반등 매수 카드가 들어온다")


func test_protective_option_pays_on_drop() -> void:
	var run := _run()
	var trade := _trade(run, "wti", "2020-04-17", 2)
	trade.play(_give(trade, "long"))
	trade.end_day()
	var before := run.account
	trade.play(_give(trade, "option"))
	var result := trade.end_day()
	var paid := false
	for event: Dictionary in result["events"]:
		if event["kind"] == "option" and float(event["amount"]) > 0.0:
			paid = true
	check(paid, "폭락한 날 보호 옵션이 행사된다")
	check(before - run.account < 700.0, "옵션이 손실을 줄였다: %s" % (before - run.account))

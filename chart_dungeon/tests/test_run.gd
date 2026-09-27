extends TestCase
## 판 진행: 지도, 뉴스, 데스크, 노트.


func _run() -> Run:
	var notes := Notes.new()
	notes.autosave = false
	return Run.new(11, notes)


func test_map_moves_to_neighbours() -> void:
	var run := _run()
	var first := run.available()
	eq(first.size(), run.columns()[1].size(), "처음엔 둘째 열 어디든")
	run.enter(first[2])
	for node in run.available():
		check(absi(int(node["lane"]) - 2) <= 1, "이웃 줄만")
	var last_column: Array = run.columns().back()
	eq(last_column.size(), 1, "마지막 열은 보스 하나")
	eq(last_column[0]["kind"], "boss")


func test_every_trade_node_has_enough_days() -> void:
	var run := _run()
	for act in run.acts:
		var previous := ""
		for column: Array in act["columns"]:
			var date: String = column[0]["date"]
			check(date >= previous, "열 날짜가 앞으로 간다: %s" % date)
			previous = date
			for node: Dictionary in column:
				if node.has("inst"):
					var start := Market.index_on_or_after(node["inst"], node["date"])
					check(start > 25, "%s 앞에 차트가 충분하다" % node["id"])
					check(start + int(node["days"]) <= Market.bars(node["inst"]).size(), "%s 기한 안에 시세가 있다" % node["id"])


func test_news_choices_apply() -> void:
	var run := _run()
	var news: Dictionary = run.news("n_0223")
	var locked: Dictionary = news["choices"][2]
	check(run.choice_locked(locked), "변동성을 모르면 잠겨 있다")
	run.notes.learn("volatility")
	check(not run.choice_locked(locked), "알면 열린다")
	var deck_size := run.deck.size()
	var text := run.apply_choice(news["choices"][0])
	eq(run.deck.size(), deck_size + 2, "스트래들과 FOMO")
	check(text.contains("스트래들"), text)
	run.apply_choice(news["choices"][1])
	eq(run.deck.size(), deck_size + 1, "습관 하나를 지웠다")


func test_desk_buy_hire_remove_deposit() -> void:
	var run := _run()
	run.bonus = 500
	run.enter({"id": "d", "kind": "desk", "date": "2020-01-03", "lane": 1})
	eq(run.shop["cards"].size(), 4, "카드 넷")
	var price: int = run.shop["cards"][0]["price"]
	check(run.buy_card(0), "산다")
	eq(run.bonus, 500 - price)
	check(not run.buy_card(0), "두 번은 못 산다")
	var hire: String = run.shop["hire"]
	if not hire.is_empty():
		check(run.hire(hire), "채용")
		check(run.has_member(hire))
	var before := run.deck.size()
	check(run.remove_card(run.deck[0]), "소각")
	eq(run.deck.size(), before - 1)
	eq(run.removal_cost, 100, "다음 소각은 더 비싸다")
	var account := run.account
	check(run.deposit(), "입금")
	check(is_equal_approx(run.account, account + Run.DEPOSIT_AMOUNT))


func test_notes_levels_and_rank() -> void:
	var notes := Notes.new()
	notes.autosave = false
	check(notes.use("stop"), "처음 쓰면 1단계")
	eq(notes.level("stop"), 1)
	notes.use("stop")
	notes.use("stop")
	notes.use("stop")
	eq(notes.level("stop"), 2, "네 번 쓰면 2단계")
	check(notes.study("stop"), "공부로 3단계")
	check(not notes.study("stop"), "3단계가 끝")
	notes.learn("wait")
	check(not notes.learn("wait", 3), "설명이 한 단계뿐이면 더 못 오른다")
	eq(notes.rank_name(), "개미")
	for id: String in NoteDB.ENTRIES.keys().slice(0, 12):
		notes.learn(id)
	eq(notes.rank_name(), "파생상품투자권유자문인력")


func test_full_act_can_be_walked() -> void:
	var run := _run()
	var guard := 0
	while not run.available().is_empty() and guard < 30:
		guard += 1
		var node: Dictionary = run.available()[0]
		var kind := run.enter(node)
		if kind in ["trade", "elite", "boss"]:
			var trade := run.start_trade(node)
			while not trade.is_over():
				trade.end_day()
			run.finish_trade(trade)
	check(run.at_boss_done(), "막 끝까지 갔다")

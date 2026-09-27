extends TestCase
## 화면 흐름: 실제 main 장면을 띄워 타이틀부터 판 끝까지 화면 조작만으로 간다.
## 트윈은 Engine.time_scale 로 빨리 돌린다.

var require_end := true


func _main() -> Control:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	main.notes.autosave = false
	main.notes.levels = {}
	main.notes.uses = {}
	main.sfx.muted = true
	return main


func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


func test_title_to_first_trade() -> void:
	Engine.time_scale = 20.0
	var main := await _main()
	check(main.screen is TitleScreen, "타이틀부터")
	main.new_run(21)
	check(main.screen is BriefingScreen, "브리핑")
	main.show_map()
	await tree.process_frame
	check(main.screen is MapScreen, "지도")
	var node: Dictionary = {}
	for item in main.run.available():
		if item["kind"] == "trade":
			node = item
	check(not node.is_empty(), "첫 열에 거래 칸이 있다")
	main.open_node(node)
	await tree.process_frame
	var screen: TradeScreen = main.screen
	check(screen is TradeScreen, "거래 화면")
	eq(screen._views.size(), screen.trade.hand.size(), "손패 카드가 다 그려졌다")
	var energy := screen.trade.energy
	var played := false
	for view in screen._views.duplicate():
		if view.card.is_entry() and screen.trade.why_not(view.card).is_empty():
			screen._on_hover(view)
			check(not screen._preview_rows.get_children().is_empty() or not screen._preview_head.text.is_empty(), "미리 보기")
			screen.play_view(view)
			played = true
			break
	check(played, "진입 카드를 냈다")
	check(screen.trade.energy < energy, "주문 한도가 줄었다")
	check(screen.trade.planned_qty() != 0, "시가 체결 대기")
	screen.end_day()
	check(screen.busy, "장중 재생 중")
	await _wait(5.0)
	check(screen._settle != null, "정산표가 떴다")
	var trade := screen.trade
	screen._continue()
	screen._continue()
	await tree.process_frame
	if not trade.is_over():
		check(not screen.busy, "다음 날로 넘어갔다")
		eq(screen._views.size(), trade.hand.size(), "새 손패")
	main.open_codex()
	await tree.process_frame
	check(main.overlay is CodexOverlay, "투자 노트 창")
	main.open_deck()
	await tree.process_frame
	check(main.overlay is DeckOverlay, "덱 창")
	main.close_overlay()
	main.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0
	end()


func test_whole_run_through_screens() -> void:
	Engine.time_scale = 40.0
	var main := await _main()
	main.new_run(33)
	main.show_map()
	await tree.process_frame
	var seen := {}
	var steps := 0
	while steps < 400 and not (main.screen is EndScreen):
		steps += 1
		var screen: Screen = main.screen
		seen[String(screen.get_script().get_global_name())] = true
		if screen is MapScreen:
			var list: Array[Dictionary] = main.run.available()
			var pick: Dictionary = list[steps % list.size()]
			main.open_node(pick)
		elif screen is TradeScreen:
			await _drive_trade(screen)
		elif screen is ResultScreen:
			var result: ResultScreen = screen
			if result._cards_row:
				result._take(result.reward["cards"][0])
			result._next.pressed.emit()
		elif screen is NewsScreen:
			var news: NewsScreen = screen
			for choice: Dictionary in news.news["choices"]:
				if not main.run.choice_locked(choice):
					news._choose(choice)
					break
			main.show_map()
		elif screen is DeskScreen:
			var desk: DeskScreen = screen
			for i in main.run.shop["cards"].size():
				desk._buy(i)
			main.show_map()
		elif screen is RestScreen:
			(screen as RestScreen)._study()
			main.show_map()
		elif screen is ReviewScreen:
			var review: ReviewScreen = screen
			review._answer(int(review._quiz["answer"]))
			review._go_next()
		else:
			check(false, "모르는 화면 %s" % screen)
			break
		await tree.process_frame
	check(main.screen is EndScreen, "판 끝까지 갔다 (%d걸음)" % steps)
	for name in ["MapScreen", "TradeScreen", "ResultScreen", "NewsScreen"]:
		check(seen.has(name), "%s 를 지났다" % name)
	check(main.run.stats["trades"] >= 3, "거래를 여러 번 했다")
	print("  판 끝: 걸음 %d, 거래 %d, 달성 %d, 계좌 %.1f, 화면 %s" % [steps, main.run.stats["trades"], main.run.stats["won"], main.run.account, seen.keys()])
	main.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0
	end()


## 전망을 따라 들어가고 손절·익절을 건다.
func _drive_trade(screen: TradeScreen) -> void:
	var trade := screen.trade
	var guard := 0
	while not trade.is_over() and guard < 12:
		guard += 1
		var up := trade.forecast.up_probability() >= 0.5
		for id in (["long", "p_rebound", "p_trend_up"] if up else ["short", "p_fall", "p_trend_down"]) + ["stop", "take"]:
			for view in screen._views.duplicate():
				if view.card.id == id and trade.why_not(view.card).is_empty():
					screen.play_view(view)
					break
		if not trade.why_not_end().is_empty():
			for view in screen._views.duplicate():
				if (view.card.is_entry() or view.card.type() == "pattern") and trade.why_not(view.card).is_empty():
					screen.play_view(view)
					break
		screen.end_day()
		while screen._settle == null:
			await tree.process_frame
		screen._continue()
		screen._continue()
		await tree.process_frame

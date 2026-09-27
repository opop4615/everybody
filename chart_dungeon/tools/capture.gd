extends SceneTree
## 화면 캡처. 화면을 차례로 띄워 PNG로 저장한다 (README 스크린샷, 눈으로 확인하기).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path chart_dungeon --rendering-driver opengl3 \
##     --script res://tools/capture.gd -- <저장할 폴더>

var out := "user://shots"
var main: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _shot(name: String, frames := 24) -> void:
	for i in frames:
		await process_frame
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.notes.autosave = false
	main.notes.levels = {}
	main.notes.uses = {}
	main.sfx.muted = true
	for id in ["futures", "long", "short", "stop", "limit", "volatility", "moving_average", "hammer", "settlement", "safe_haven", "day_0103", "leverage"]:
		main.notes.learn(id)
	main.notes.learn("margin_call", 2)
	main.notes.learn("leverage", 2)
	main.show_title()
	await _shot("01_title")
	main.new_run(7)
	main.run.members.append("crowd")
	main.run.members.append("risk")
	await _shot("02_briefing")
	main.show_map()
	await _shot("03_map")
	# 뉴스 칸
	var news_node: Dictionary = main.run.available()[0]
	main.open_node(news_node)
	await _shot("04_news")
	main.screen.call("_choose", main.run.news(news_node["news"])["choices"][1])
	await _shot("05_news_choice")
	# 거래: 3월 보스 금 (크게 흔들리는 날)
	main.run.column = 8
	main.run.lane = 1
	var boss: Dictionary = main.run.columns()[9][0]
	main.run.account = 2840.0
	main.open_node(boss)
	await _wait(0.8)
	var screen: TradeScreen = main.screen
	var entry: CardView = null
	for view in screen._views:
		if view.card.id in ["long", "short"]:
			entry = view
	if entry:
		screen._on_hover(entry)
	await _shot("06_trade_hover", 20)
	if entry:
		screen.play_view(entry)
	await _wait(0.5)
	for view in screen._views.duplicate():
		if view.card.id == "stop" and screen.trade.why_not(view.card).is_empty():
			screen.play_view(view)
			break
	await _wait(0.5)
	for view in screen._views:
		if view.card.id in ["take", "close", "wait"]:
			screen._on_hover(view)
			break
	await _shot("07_trade_orders", 10)
	screen.end_day()
	await _wait(1.9)
	await _shot("08_replay", 1)
	await _wait(3.5)
	await _shot("09_settlement")
	screen._continue()
	await _wait(1.0)
	await _shot("10_next_day")
	var guard := 0
	while main.screen == screen and guard < 8:
		guard += 1
		screen.end_day()
		await _wait(4.5)
		screen._continue()
		screen._continue()
		await _wait(0.6)
	await _wait(0.6)
	await _shot("11_result")
	main.open_codex("hammer")
	await _shot("12_codex")
	main.close_overlay()
	main.open_deck()
	await _shot("13_deck")
	main.close_overlay()
	main.run.bonus = 260
	_open_desk()
	await _shot("14_desk")
	main.set_screen(RestScreen.new().with_node({"id": "cap_rest", "kind": "rest", "date": "2020-03-16", "lane": 2}))
	await _shot("15_rest")
	main.run.column = main.run.columns().size() - 1
	main.show_review()
	await _shot("16_review")
	main.screen.call("_answer", 1)
	await _shot("17_review_answer")
	main.run.victory = true
	main.run.over = true
	main.show_end()
	await _shot("18_end")
	quit()


func _open_desk() -> void:
	main.run._stock_shop()
	main.set_screen(DeskScreen.new().with_node({"id": "cap_desk", "kind": "desk", "date": "2020-03-12", "lane": 1}))

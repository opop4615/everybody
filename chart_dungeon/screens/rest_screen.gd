class_name RestScreen
extends Screen
## 퇴근 (쉬는 칸). 셋 중 하나를 한다.
##   공부     투자 노트에서 가장 덜 아는 항목 하나가 한 단계 오른다.
##   복기     나쁜 습관 카드 한 장을 지운다.
##   백테스트 카드 한 장을 공짜로 강화한다.

var node: Dictionary
var _done := false
var _row: HBoxContainer
var _result: VBoxContainer


func with_node(p_node: Dictionary) -> RestScreen:
	node = p_node
	return self


func _ready() -> void:
	background()
	top_bar(Bar.new(node["date"]).long_date() + " · 퇴근길", [["퇴근", Look.kind_color("rest")]])
	var title := Look.label("퇴근", 30, Look.TEXT, "display")
	Look.place(title, 40, 66)
	add_child(title)
	var sub := Look.label("오늘은 거래하지 않는다. 한 가지만 한다.", 13, Look.DIM)
	Look.place(sub, 42, 110)
	add_child(sub)
	_row = Look.hbox(24)
	Look.place(_row, 110, 170)
	add_child(_row)
	var habits := run().habits().size()
	_row.add_child(_option("공부", "책을 편다", "투자 노트에서 가장 덜 아는 항목 하나가 한 단계 오른다. 단계가 오르면 화면에 보이는 정보도 늘어난다.", true, _study))
	_row.add_child(_option("복기", "매매 일지를 다시 읽는다", "덱에서 나쁜 습관 카드 한 장을 지운다. (지금 %d장)" % habits, habits > 0, _review))
	_row.add_child(_option("백테스트", "지난 차트로 전략을 돌려 본다", "카드 한 장을 골라 공짜로 강화한다.", true, _backtest))
	_result = Look.vbox(12)
	Look.place(_result, 110, 520, 1060, 0)
	add_child(_result)


func _option(title: String, flavor: String, text: String, enabled: bool, action: Callable) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(336, 300)
	button.disabled = not enabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", Look.box(Look.PANEL, Look.LINE_2, 10, 1, 20))
	button.add_theme_stylebox_override("hover", Look.box(Look.RAISED, Look.GOLD, 10, 2, 20))
	button.add_theme_stylebox_override("pressed", Look.box(Look.RAISED, Look.GOLD, 10, 2, 20))
	button.add_theme_stylebox_override("disabled", Look.box(Look.BG, Look.LINE, 10, 1, 20))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var box := Look.vbox(10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_top = 22
	box.offset_right = -22
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(Look.label(title, 30, Look.GOLD if enabled else Look.FAINT, "display"))
	box.add_child(Look.label(flavor, 13, Look.SOFT if enabled else Look.FAINT, "bold"))
	box.add_child(Look.wrap_label(text, 14, Look.TEXT if enabled else Look.FAINT, 290))
	button.add_child(box)
	button.pressed.connect(action)
	return button


func _finish(text: String) -> void:
	_done = true
	for child in _row.get_children():
		(child as Button).disabled = true
	for child in _result.get_children():
		child.queue_free()
	_result.add_child(Look.wrap_label(text, 16, Look.GOLD, 1000, "bold"))
	var next := Look.button("지도로", "primary", 18, "Space")
	next.custom_minimum_size = Vector2(220, 56)
	next.pressed.connect(func() -> void: app.show_map())
	_result.add_child(next)


func _study() -> void:
	if _done:
		return
	var id := run().study_something()
	app.sfx.play("page", -6.0)
	if id.is_empty():
		run().bonus += 20
		_finish("더 공부할 항목이 없다. 대신 성과급 +20.")
	else:
		_finish("투자 노트 · %s %s" % [NoteDB.name_of(id), Look.stars(run().notes.level(id), run().notes._cap(id))])


func _review() -> void:
	if _done:
		return
	var list := run().habits()
	if list.is_empty():
		return
	var name := list[0].name()
	run().remove_habit()
	app.sfx.play("card", -6.0)
	_finish("%s 카드를 덱에서 지웠다." % name)


func _backtest() -> void:
	if _done:
		return
	app.open_deck("강화할 카드를 고른다 · 공짜", func(card: Card) -> void:
		if run().upgrade_card(card, false):
			app.sfx.play("win", -10.0)
			_finish("%s 로 강화했다." % card.name()),
		func(card: Card) -> bool: return card.can_upgrade())


func handle_key(event: InputEventKey) -> bool:
	if _done and event.keycode in [KEY_SPACE, KEY_ENTER]:
		app.show_map()
		return true
	return false

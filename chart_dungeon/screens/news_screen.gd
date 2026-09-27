class_name NewsScreen
extends Screen
## 뉴스 칸. 실제 그날의 기사 한 장과 선택지 셋.
## 어떤 선택지는 투자 노트 단계가 있어야 열린다 (아는 만큼 보인다).

var node: Dictionary
var news: Dictionary
var _choices: VBoxContainer
var _done := false


func with_node(p_node: Dictionary) -> NewsScreen:
	node = p_node
	return self


func _ready() -> void:
	background()
	news = run().news(node["news"])
	run().open_news(node["news"])
	top_bar(String(news["date"]), [["뉴스", Look.kind_color("news")]])
	var paper := PanelContainer.new()
	var style := Look.box(Look.PAPER, Color("d8ccb0"), 4, 1, 34)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	paper.add_theme_stylebox_override("panel", style)
	Look.place(paper, 190, 70, 900, 0)
	add_child(paper)
	var box := Look.vbox(10)
	paper.add_child(box)
	var mast := Look.hbox(10)
	mast.add_child(Look.label("경제 속보", 22, Look.INK, "display"))
	mast.add_child(Look.spacer())
	mast.add_child(Look.label(String(news["date"]), 13, Look.INK_SOFT, "bold"))
	box.add_child(mast)
	var rule := ColorRect.new()
	rule.color = Look.INK
	rule.custom_minimum_size = Vector2(830, 3)
	box.add_child(rule)
	box.add_child(Look.wrap_label(String(news["headline"]), 34, Look.INK, 830, "display"))
	box.add_child(Look.wrap_label(String(news["body"]), 15, Look.INK, 830))
	var learned: Array[String] = []
	for id: String in news.get("notes", []):
		learned.append(NoteDB.name_of(id))
	if not learned.is_empty():
		box.add_child(Look.label("투자 노트에 적힘 · " + ", ".join(learned), 12, Look.GOLD_DARK, "bold"))
	var line := ColorRect.new()
	line.color = Color("d8ccb0")
	line.custom_minimum_size = Vector2(830, 1)
	box.add_child(line)
	box.add_child(Look.label("당신은 무엇을 하나", 14, Look.INK_SOFT, "bold"))
	_choices = Look.vbox(8)
	box.add_child(_choices)
	for i in news["choices"].size():
		_choices.add_child(_choice_button(i, news["choices"][i]))


func _choice_button(index: int, choice: Dictionary) -> Control:
	var locked := run().choice_locked(choice)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(830, 56)
	button.disabled = locked
	var normal := Look.box(Color("fbf6ea"), Color("c9bc9c"), 6, 1, 10)
	var hover := Look.box(Color.WHITE, Look.GOLD_DARK, 6, 2, 10)
	var disabled := Look.box(Color("e8e0cc"), Color("d8ccb0"), 6, 1, 10)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not locked else Control.CURSOR_ARROW
	var row := Look.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var number := Look.label(str(index + 1), 20, Look.GOLD_DARK if not locked else Look.DIM_2, "display")
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(number)
	var texts := Look.vbox(0)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_child(Look.label(String(choice["text"]), 16, Look.INK if not locked else Look.DIM_2, "bold"))
	var detail := String(choice["detail"])
	if locked:
		var need: Array = choice["need"]
		detail = "투자 노트 · %s %d단계가 있어야 고를 수 있다" % [NoteDB.name_of(need[0]), int(need[1])]
	texts.add_child(Look.label(detail, 12, Look.INK_SOFT if not locked else Look.DIM_2))
	row.add_child(texts)
	button.add_child(row)
	button.pressed.connect(_choose.bind(choice))
	return button


func _choose(choice: Dictionary) -> void:
	if _done:
		return
	_done = true
	var text := run().apply_choice(choice)
	app.sfx.play("card", -6.0)
	for child in _choices.get_children():
		child.queue_free()
	var result := Look.panel(Color("fbf6ea"), Look.GOLD_DARK, 6, 14)
	var box := Look.vbox(8)
	box.add_child(Look.label(String(choice["text"]), 16, Look.INK, "bold"))
	box.add_child(Look.wrap_label(text if not text.is_empty() else "아무 일도 일어나지 않았다.", 14, Look.GOLD_DARK, 790, "bold"))
	result.add_child(box)
	_choices.add_child(result)
	var next := Look.button("지도로", "primary", 18, "Space")
	next.pressed.connect(func() -> void: app.show_map())
	_choices.add_child(next)


func handle_key(event: InputEventKey) -> bool:
	if _done and event.keycode in [KEY_SPACE, KEY_ENTER]:
		app.show_map()
		return true
	if not _done and event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index := event.keycode - KEY_1
		var choice: Dictionary = news["choices"][index]
		if not run().choice_locked(choice):
			_choose(choice)
		return true
	return false

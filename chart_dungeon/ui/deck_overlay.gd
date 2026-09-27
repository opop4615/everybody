class_name DeckOverlay
extends Control
## 덱 보기. picker 가 있으면 카드 한 장을 고르는 창이 된다 (소각, 강화).

var app: Node
var _picker: Callable
var _filter: Callable


func setup(p_app: Node, title := "", picker: Callable = Callable(), filter: Callable = Callable()) -> DeckOverlay:
	app = p_app
	_picker = picker
	_filter = filter
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Look.dim_layer(0.8))
	var run: Run = app.run
	var head := Look.hbox(14)
	Look.place(head, 60, 30, 1160, 40)
	var heading := title if not title.is_empty() else "덱 %d장" % run.deck.size()
	head.add_child(Look.label(heading, 26, Look.GOLD, "display"))
	if title.is_empty():
		var counts := {}
		for card in run.deck:
			var t: String = CardDB.TYPE_LABEL.get(card.type(), "")
			counts[t] = int(counts.get(t, 0)) + 1
		var parts: Array[String] = []
		for key: String in counts:
			parts.append("%s %d" % [key, counts[key]])
		var summary := Look.label(" · ".join(parts), 13, Look.SOFT)
		summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(summary)
	head.add_child(Look.spacer())
	var close := Look.button("닫기", "plain", 13, "Esc")
	close.pressed.connect(func() -> void: app.close_overlay())
	head.add_child(close)
	add_child(head)
	var scroll := ScrollContainer.new()
	Look.place(scroll, 60, 90, 1170, 610)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)
	var cards := run.deck.duplicate()
	cards.sort_custom(func(a: Card, b: Card) -> bool: return _order(a) < _order(b))
	for card: Card in cards:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CardView.W, CardView.H + 8)
		var view := CardView.new().setup(card)
		view.position = Vector2(0, 8)
		holder.add_child(view)
		var allowed: bool = _picker.is_valid() and (not _filter.is_valid() or bool(_filter.call(card)))
		if _picker.is_valid() and not allowed:
			view.modulate = Color(1, 1, 1, 0.3)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif allowed:
			view.hovered.connect(func(v: CardView) -> void:
				v.selected = true
				v.queue_redraw())
			view.unhovered.connect(func(v: CardView) -> void:
				v.selected = false
				v.queue_redraw())
			view.clicked.connect(func(v: CardView) -> void:
				_picker.call(v.card)
				app.close_overlay())
		else:
			view.mouse_default_cursor_shape = Control.CURSOR_ARROW
		grid.add_child(holder)
	return self


func _order(card: Card) -> String:
	var types := ["long", "short", "entry", "pattern", "order", "hedge", "info", "habit"]
	return "%d_%s_%d" % [types.find(card.type()), card.id, 0 if card.upgraded else 1]

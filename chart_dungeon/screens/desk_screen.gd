class_name DeskScreen
extends Screen
## 데스크 (상점). 성과급으로 카드를 사고, 팀원을 뽑고, 카드를 지우거나 강화하고, 계좌에 입금한다.

var node: Dictionary
var bar: TopBar
var _shop_row: HBoxContainer
var _side: VBoxContainer


func with_node(p_node: Dictionary) -> DeskScreen:
	node = p_node
	return self


func _ready() -> void:
	background()
	bar = top_bar(Bar.new(node["date"]).long_date() + " · 장 끝나고", [["데스크", Look.kind_color("desk")]])
	var title := Look.label("데스크", 30, Look.TEXT, "display")
	Look.place(title, 40, 66)
	add_child(title)
	var sub := Look.label("성과급으로 카드를 사고 사람을 뽑는다. 덱은 가벼울수록 좋은 카드가 자주 온다.", 13, Look.DIM)
	Look.place(sub, 42, 110)
	add_child(sub)
	var shop := Look.panel(Look.PANEL, Look.LINE, 8, 18)
	Look.place(shop, 40, 146, 760, 330)
	var shop_box := Look.vbox(12)
	shop_box.add_child(Look.label("카드 · 클릭해서 산다", 12, Look.DIM, "bold"))
	_shop_row = Look.hbox(34)
	shop_box.add_child(_shop_row)
	shop.add_child(shop_box)
	add_child(shop)
	var side := Look.panel(Look.PANEL, Look.LINE, 8, 18)
	Look.place(side, 812, 146, 428, 540)
	_side = Look.vbox(10)
	side.add_child(_side)
	add_child(side)
	var leave := Look.button("나간다", "primary", 20, "Space")
	Look.place(leave, 40, 620, 220, 60)
	leave.pressed.connect(func() -> void: app.show_map())
	add_child(leave)
	refresh()


func refresh() -> void:
	bar.refresh()
	for child in _shop_row.get_children():
		child.queue_free()
	var items: Array = run().shop.get("cards", [])
	for i in items.size():
		var item: Dictionary = items[i]
		var column := Look.vbox(10)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CardView.W, CardView.H + 14)
		var view := CardView.new().setup(item["card"])
		view.position = Vector2(0, 14)
		holder.add_child(view)
		column.add_child(holder)
		var price := Look.label("판매 완료" if item["sold"] else "성과급 %d" % int(item["price"]), 15, Look.DIM if item["sold"] else (Look.GOLD if run().bonus >= int(item["price"]) else Look.UP_TEXT), "display")
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(price)
		if item["sold"]:
			view.modulate = Color(1, 1, 1, 0.25)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			view.clicked.connect(func(_v: CardView) -> void: _buy(i))
			view.hovered.connect(func(v: CardView) -> void:
				v.selected = true
				v.queue_redraw())
			view.unhovered.connect(func(v: CardView) -> void:
				v.selected = false
				v.queue_redraw())
		_shop_row.add_child(column)
	for child in _side.get_children():
		child.queue_free()
	var hire: String = run().shop.get("hire", "")
	_side.add_child(Look.label("사람 뽑기", 12, Look.DIM, "bold"))
	if hire.is_empty() or run().shop.get("hired", false):
		_side.add_child(Look.wrap_label("오늘은 찾아온 사람이 없다." if hire.is_empty() else "새 팀원이 합류했다.", 13, Look.SOFT, 390))
	else:
		var info: Dictionary = Run.MEMBERS[hire]
		var row := Look.hbox(12)
		row.add_child(Sprites.portrait(info["sprite"], 4))
		var texts := Look.vbox(4)
		texts.add_child(Look.label(info["name"], 18, Look.TEXT, "display"))
		texts.add_child(Look.wrap_label(info["text"], 12, Look.SOFT, 300))
		row.add_child(texts)
		_side.add_child(row)
		var cost: int = info["cost"]
		var full := run().members.size() >= Run.MAX_MEMBERS
		var button := Look.button("채용 · 성과급 %d" % cost if not full else "자리가 없다 (최대 %d명)" % Run.MAX_MEMBERS, "plain", 14)
		button.disabled = full or run().bonus < cost
		button.pressed.connect(func() -> void:
			if run().hire(hire):
				app.sfx.play("win", -10.0)
				app.toast("%s 합류" % info["name"])
				refresh())
		_side.add_child(button)
	var line := ColorRect.new()
	line.color = Look.LINE
	line.custom_minimum_size = Vector2(390, 1)
	_side.add_child(line)
	_side.add_child(Look.label("서비스", 12, Look.DIM, "bold"))
	_side.add_child(_service("카드 소각", "덱에서 카드 한 장을 영구히 지운다. 나쁜 습관 카드도 지울 수 있다.", run().removal_cost, _remove))
	_side.add_child(_service("카드 강화", "카드 한 장을 강화한다. 계약이 늘거나 비용이 줄거나 카드를 더 뽑는다.", Run.UPGRADE_COST, _upgrade))
	_side.add_child(_service("계좌 입금", "성과급을 헐어 계좌에 %s을 넣는다. 마진콜 선에서 멀어진다." % Fmt.money(Run.DEPOSIT_AMOUNT), Run.DEPOSIT_COST, _deposit))


func _service(title: String, text: String, cost: int, action: Callable) -> Control:
	var box := Look.hbox(10)
	var texts := Look.vbox(2)
	texts.add_child(Look.label(title, 14, Look.TEXT, "bold"))
	texts.add_child(Look.wrap_label(text, 11, Look.DIM, 250))
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(texts)
	var button := Look.button("성과급 %d" % cost, "plain", 13)
	button.disabled = run().bonus < cost
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	box.add_child(button)
	return box


func _buy(index: int) -> void:
	var item: Dictionary = run().shop["cards"][index]
	if run().buy_card(index):
		app.sfx.play("coin", -6.0)
		app.toast("%s 카드를 샀다" % (item["card"] as Card).name())
	else:
		app.toast("성과급이 모자란다", Look.UP_TEXT)
	refresh()


func _remove() -> void:
	app.open_deck("지울 카드를 고른다 · 성과급 %d" % run().removal_cost, func(card: Card) -> void:
		if run().remove_card(card):
			app.sfx.play("card", -6.0)
			app.toast("%s 카드를 지웠다" % card.name()))


func _upgrade() -> void:
	app.open_deck("강화할 카드를 고른다 · 성과급 %d" % Run.UPGRADE_COST, func(card: Card) -> void:
		if run().upgrade_card(card):
			app.sfx.play("win", -10.0)
			app.toast("%s 로 강화했다" % card.name()),
		func(card: Card) -> bool: return card.can_upgrade())


func _deposit() -> void:
	if run().deposit():
		app.sfx.play("coin", -6.0)
		app.toast("계좌에 %s 입금" % Fmt.money(Run.DEPOSIT_AMOUNT))
	refresh()


func handle_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_SPACE, KEY_ENTER]:
		app.show_map()
		return true
	return false

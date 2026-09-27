class_name ResultScreen
extends Screen
## 거래가 끝난 뒤. 결과, 역사 복기(그때 실제로 무슨 일이 있었나), 새로 적힌 노트, 보상 카드 고르기.

var trade: Trade
var reward: Dictionary
var fresh_start := 0
var _picked := false
var _cards_row: HBoxContainer
var _next: Button
var _left: VBoxContainer
var _right: VBoxContainer


func with_result(p_trade: Trade, p_reward: Dictionary, p_fresh_start := 0) -> ResultScreen:
	trade = p_trade
	reward = p_reward
	fresh_start = p_fresh_start
	return self


func _ready() -> void:
	background()
	var last := trade.bars[trade.start_index + maxi(trade.day - 1, 0)]
	top_bar(last.long_date() + " · 거래 끝", [[Look.kind_name(trade.kind), Look.kind_color(trade.kind)]])
	var verdict := ""
	var color := Look.GOLD
	match trade.state:
		Trade.State.WON:
			verdict = "목표 달성"
		Trade.State.FAILED:
			verdict = "기한 끝 · 목표 미달"
			color = Look.DOWN_TEXT
		Trade.State.BUSTED:
			verdict = "마진콜 · 반대매매"
			color = Look.UP
	var head := Look.hbox(16)
	Look.place(head, 40, 64)
	head.add_child(Look.label(verdict, 34, color, "display"))
	var pnl := trade.trade_pnl()
	var sub := Look.label("%s  ·  %s  %s / 목표 +%s" % [trade.title, trade.instrument.name, Fmt.signed_money(pnl), Fmt.money(trade.target)], 15, Look.SOFT, "bold")
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sub)
	add_child(head)
	_left = Look.vbox(12)
	Look.place(_left, 40, 124, 580, 0)
	add_child(_left)
	_right = Look.vbox(12)
	Look.place(_right, 632, 124, 608, 0)
	add_child(_right)
	_build_days()
	_build_history()
	_build_learning()
	_build_rewards()


## 날마다 캔들과 그날 손익.
func _build_days() -> void:
	var panel := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	panel.custom_minimum_size = Vector2(580, 0)
	var box := Look.vbox(8)
	box.add_child(Look.label("날마다", 12, Look.DIM, "bold"))
	var row := Look.hbox(10)
	for i in trade.days_log.size():
		var log: Dictionary = trade.days_log[i]
		var bar := trade.bars[trade.start_index + i]
		var column := Look.vbox(4)
		var candle := Control.new()
		candle.custom_minimum_size = Vector2(96, 86)
		candle.draw.connect(_draw_mini.bind(candle, bar))
		column.add_child(candle)
		column.add_child(Look.label(bar.short_date() + " " + bar.weekday_name(), 12, Look.DIM, "mono"))
		var day_pnl: float = log["pnl"]
		column.add_child(Look.label(Fmt.signed_money(day_pnl), 15, Look.up_down(day_pnl), "display"))
		row.add_child(column)
	box.add_child(row)
	panel.add_child(box)
	_left.add_child(panel)


func _draw_mini(node: Control, bar: Bar) -> void:
	var prev := trade.bars[trade.bars.find(bar) - 1]
	var lo := minf(bar.low, prev.close)
	var hi := maxf(bar.high, prev.close)
	var h := node.size.y
	var y := func(v: float) -> float: return 4 + (h - 8) * (1.0 - (v - lo) / maxf(hi - lo, 0.0001))
	var x := node.size.x * 0.5
	var color := Look.UP if bar.is_up() else Look.DOWN
	node.draw_dashed_line(Vector2(4, y.call(prev.close)), Vector2(node.size.x - 4, y.call(prev.close)), Look.LINE_2, 1.0, 3.0)
	node.draw_line(Vector2(x, y.call(bar.high)), Vector2(x, y.call(bar.low)), color, 2.0)
	var top: float = y.call(maxf(bar.open, bar.close))
	var bottom: float = y.call(minf(bar.open, bar.close))
	node.draw_rect(Rect2(x - 9, top, 18, maxf(bottom - top, 2.0)), color)


## 역사 복기: 그 기간 실제 시세와 그 무렵 있었던 일.
func _build_history() -> void:
	var panel := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	panel.custom_minimum_size = Vector2(608, 0)
	var box := Look.vbox(6)
	box.add_child(Look.label("역사 복기 · 그때 실제로는", 12, Look.GOLD, "bold"))
	var inst := trade.instrument
	var first := trade.bars[trade.start_index - 1]
	var played := maxi(trade.day, 1)
	var last := trade.bars[trade.start_index + played - 1]
	var change := last.close - first.close
	var pct := change / absf(first.close) * 100.0
	box.add_child(Look.wrap_label("%s ~ %s  %s  %s → %s (%+.1f%%)" % [
		trade.bars[trade.start_index].short_date(), last.short_date(), inst.name,
		inst.price_text(first.close), inst.price_text(last.close), pct], 15, Look.up_down(change), 580, "bold"))
	var high := -INF
	var low := INF
	for i in played:
		high = maxf(high, trade.bars[trade.start_index + i].high)
		low = minf(low, trade.bars[trade.start_index + i].low)
	box.add_child(Look.label("기간 고가 %s · 저가 %s" % [inst.price_text(high), inst.price_text(low)], 12, Look.SOFT, "mono"))
	var notes := _history_notes(trade.bars[trade.start_index - 3].date, last.date)
	for id in notes.slice(maxi(0, notes.size() - 2)):
		var text: String = NoteDB.ENTRIES[id]["texts"][0]
		box.add_child(Look.wrap_label("%s — %s" % [NoteDB.name_of(id), text], 12, Look.SOFT, 580))
		run().notes.learn(id)
	box.add_child(Look.wrap_label("출처: " + inst.source, 11, Look.FAINT, 580))
	panel.add_child(box)
	_right.add_child(panel)


## 이 기간과 겹치는 '역사의 날' 항목.
func _history_notes(from: String, to: String) -> Array[String]:
	var list: Array[String] = []
	for id: String in NoteDB.ENTRIES:
		if not id.begins_with("day_"):
			continue
		var date := "2020-%s-%s" % [id.substr(4, 2), id.substr(6, 2)]
		if date >= from and date <= to:
			list.append(id)
	return list


func _build_learning() -> void:
	var panel := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	panel.custom_minimum_size = Vector2(580, 0)
	var box := Look.vbox(6)
	box.add_child(Look.label("배운 것", 12, Look.DIM, "bold"))
	var notes := run().notes
	var fresh: Array = notes.fresh.slice(fresh_start)
	if fresh.is_empty():
		box.add_child(Look.wrap_label("새로 적힌 항목은 없다. 카드를 쓸수록 아는 항목의 단계가 오른다.", 13, Look.SOFT, 550))
	else:
		var names: Array[String] = []
		for id: String in fresh:
			names.append("%s %s" % [NoteDB.name_of(id), Look.stars(notes.level(id), notes._cap(id))])
		box.add_child(Look.wrap_label("투자 노트에 새로 적힘 · " + ", ".join(names), 13, Look.GOLD, 550, "bold"))
	for id: String in reward.get("learned", []):
		box.add_child(Look.wrap_label("차트에서 본 모양이 무엇인지 알게 됐다: %s. 다음부터 이 모양이 나오면 카드가 들어온다." % Patterns.label(id), 12, Look.SOFT, 550))
	box.add_child(Look.label("투자 노트 %d/%d · %s" % [notes.known_count(), NoteDB.total(), notes.rank_name()], 12, Look.DIM))
	panel.add_child(box)
	_left.add_child(panel)


func _build_rewards() -> void:
	var panel := Look.panel(Look.PANEL_2, Look.GOLD if reward["won"] else Look.LINE, 8, 14)
	panel.custom_minimum_size = Vector2(608, 0)
	var box := Look.vbox(10)
	panel.add_child(box)
	_right.add_child(panel)
	if trade.state == Trade.State.BUSTED:
		box.add_child(Look.label("판이 끝났다", 18, Look.UP, "display"))
		box.add_child(Look.wrap_label("계좌가 마진콜 선 아래로 떨어져 증권사가 포지션을 강제로 정리했다. 방향이 맞았어도 흔들림을 버틸 계좌가 없으면 끝이다.", 13, Look.TEXT, 580))
		_next = Look.button("판 결과", "primary", 18, "Space")
		_next.pressed.connect(func() -> void: app.show_end())
		box.add_child(_next)
		return
	if reward["won"]:
		box.add_child(Look.label("성과급 +%d · 카드 한 장을 고른다" % int(reward["bonus"]), 16, Look.GOLD, "display"))
		_cards_row = Look.hbox(28)
		for card: Card in reward["cards"]:
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(CardView.W, CardView.H)
			var view := CardView.new().setup(card)
			holder.add_child(view)
			view.clicked.connect(func(v: CardView) -> void: _take(v.card))
			view.hovered.connect(func(v: CardView) -> void:
				v.selected = true
				v.queue_redraw())
			view.unhovered.connect(func(v: CardView) -> void:
				v.selected = false
				v.queue_redraw())
			_cards_row.add_child(holder)
		box.add_child(_cards_row)
		var row := Look.hbox(10)
		var skip := Look.button("건너뛴다", "ghost", 13)
		skip.pressed.connect(func() -> void: _take(null))
		row.add_child(skip)
		row.add_child(Look.spacer())
		_next = Look.button("지도로", "primary", 18, "Space")
		_next.visible = false
		_next.pressed.connect(func() -> void: app.show_map())
		row.add_child(_next)
		box.add_child(row)
	else:
		var habit := Card.new(reward.get("habit", "h_average"))
		box.add_child(Look.label("덱에 나쁜 습관이 들어왔다", 16, Look.DOWN_TEXT, "display"))
		var row := Look.hbox(18)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(CardView.W, CardView.H)
		holder.add_child(CardView.new().setup(habit))
		row.add_child(holder)
		row.add_child(Look.wrap_label("목표에 못 미친 거래는 버릇을 남긴다. 습관 카드는 낼 수 없고 손을 차지한다. 데스크의 소각이나 퇴근길 복기로 지울 수 있다.", 13, Look.SOFT, 380))
		box.add_child(row)
		_next = Look.button("지도로", "primary", 18, "Space")
		_next.pressed.connect(func() -> void: app.show_map())
		box.add_child(_next)
		_picked = true


func _take(card: Card) -> void:
	if _picked:
		return
	_picked = true
	if card:
		run().take_card(card)
		app.sfx.play("card", -4.0)
		app.toast("%s 카드를 덱에 넣었다" % card.name())
	for holder in _cards_row.get_children():
		var view := holder.get_child(0) as CardView
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if view.card != card:
			create_tween().tween_property(view, "modulate:a", 0.2, 0.2)
	_next.visible = true


func handle_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_SPACE, KEY_ENTER] and _next and _next.visible:
		_next.pressed.emit()
		return true
	if not _picked and _cards_row and event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index := event.keycode - KEY_1
		if index < reward["cards"].size():
			_take(reward["cards"][index])
		return true
	return false

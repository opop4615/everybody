class_name TradeScreen
extends Screen
## 거래 화면 (전투). 하루가 한 턴이다.
##   왼쪽: 데스크 팀원이 전망을 말한다.  가운데: 차트와 시장 전망표.  오른쪽: 포지션, 목표, 카드 미리 보기.
##   아래: 주문 한도, 손패, 장 마감.
## 장 마감을 누르면 오늘 캔들이 시가 → (저가·고가) → 종가로 움직이고, 닿은 주문이 차례로 체결된 뒤 정산표가 뜬다.

const HAND_Y := 498.0
const HAND_CENTER := 600.0
const HISTORY := 24

var trade: Trade
var bar: TopBar
var chart: ChartView
var _desk_box: VBoxContainer
var _sticky: PanelContainer
var _sticky_box: VBoxContainer
var _chart_head: HBoxContainer
var _chart_note: Label
var _position_box: VBoxContainer
var _goal_value: Label
var _goal_target: Label
var _goal_days: Label
var _goal_bar: Control
var _goal_ghost := NAN
var _preview_title: Label
var _preview_head: Label
var _preview_rows: VBoxContainer
var _energy: Control
var _pile_label: Label
var _discard_label: Label
var _hand_layer: Control
var _views: Array[CardView] = []
var _end_button: Button
var _end_reason: Label
var _tip: PanelContainer
var _hovered: CardView
var busy := false
var _result := {}
var _event_index := 0
var _mark_count := 0
var _running_account := 0.0
var _settle: Control
var _settle_rows: VBoxContainer
var _settle_tween: Tween
var _settle_ready := false
var _message_index := 0
var _fresh_start := 0


func with_trade(p_trade: Trade) -> TradeScreen:
	trade = p_trade
	return self


func _ready() -> void:
	_fresh_start = run().notes.fresh.size()
	background()
	var kind_tag := [Look.kind_name(trade.kind), Look.kind_color(trade.kind)]
	bar = top_bar(trade.today().long_date() + " · 장 시작 전", [kind_tag])
	_build_strip()
	_build_desk()
	_build_chart()
	_build_right()
	_build_bottom()
	refresh()
	_deal()
	app.sfx.play("bell", -16.0)
	if run().notes.level("settlement") == 0 and int(run().stats["trades"]) == 0:
		_start_coach()


# ── 처음 거래 안내 ────────────────────────────────────────────────

const COACH := [
	[Vector2(250, 140), "시장 전망표", "금색 상자는 오늘 가격이 움직일 예상 범위, 화살표와 %는 오를 확률이다. 퀀트 신호는 62%만 맞는다. 신호가 여럿이면 확률이 더 또렷해진다."],
	[Vector2(470, 300), "카드 = 주문", "카드를 클릭하거나 숫자 키로 낸다. 롱은 오르면, 숏은 내리면 번다. 진입은 오늘 시가에 체결된다. 동전 숫자는 주문 한도를 얼마나 쓰는지다."],
	[Vector2(900, 440), "손절과 익절", "손절·익절 카드는 가격선을 걸어 둔다. 장중에 그 값에 닿으면 알아서 정리된다. 카드에 마우스를 올리면 오른쪽에 결과가 미리 나온다."],
	[Vector2(690, 470), "장 마감", "다 냈으면 장 마감. 오늘 캔들이 시가 → 저가·고가 → 종가로 움직이며 닿은 주문이 체결되고, 종가로 손익이 계좌에 들어간다(일일정산)."],
]
var _coach: Control
var _coach_step := 0


func _start_coach() -> void:
	_coach = Control.new()
	_coach.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	_coach.z_index = 80
	_coach.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_next_coach())
	add_child(_coach)
	_coach_step = 0
	_show_coach()


func _show_coach() -> void:
	for child in _coach.get_children():
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.add_child(shade)
	var step: Array = COACH[_coach_step]
	var panel := Look.panel(Look.PAPER, Look.GOLD, 8, 16)
	Look.place(panel, step[0].x, step[0].y, 380, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Look.vbox(6)
	box.add_child(Look.label("처음 거래 · %d/%d" % [_coach_step + 1, COACH.size()], 11, Look.GOLD_DARK, "bold"))
	box.add_child(Look.label(step[1], 20, Look.INK, "display"))
	box.add_child(Look.wrap_label(step[2], 13, Look.INK, 348))
	box.add_child(Look.label("클릭 또는 Space — 다음", 11, Look.INK_SOFT))
	panel.add_child(box)
	_coach.add_child(panel)


func _next_coach() -> void:
	_coach_step += 1
	if _coach_step >= COACH.size():
		_coach.queue_free()
		_coach = null
		return
	_show_coach()


# ── 만들기 ────────────────────────────────────────────────────────

func _build_strip() -> void:
	var strip := PanelContainer.new()
	var style := Look.box(Look.PANEL_2, Look.LINE, 0, 0, 0)
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 20
	strip.add_theme_stylebox_override("panel", style)
	Look.place(strip, 0, 46, 1280, 30)
	var row := Look.hbox(10)
	strip.add_child(row)
	row.add_child(Look.label(trade.title, 13, Look.TEXT, "bold"))
	row.add_child(Look.label("|", 12, Look.FAINT))
	row.add_child(Look.label(trade.instrument.name + " · " + trade.instrument.spec, 12, Look.SOFT))
	for rule in trade.rules:
		row.add_child(Look.label("|", 12, Look.FAINT))
		row.add_child(Look.label(rule, 12, Look.DOWN_TEXT if rule.begins_with("보스") else Look.SOFT, "bold" if rule.begins_with("보스") else "body"))
	for child in row.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(strip)


func _build_desk() -> void:
	var panel := Look.panel(Look.PANEL, Look.LINE, 8, 12)
	Look.place(panel, 16, 86, 212, 336)
	_desk_box = Look.vbox(8)
	panel.add_child(_desk_box)
	add_child(panel)


func _build_chart() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Look.box(Look.PANEL, Look.LINE, 8, 0))
	Look.place(panel, 238, 86, 640, 336)
	add_child(panel)
	chart = ChartView.new()
	Look.place(chart, 0, 0, 640, 336)
	chart.instrument = trade.instrument
	panel.add_child(chart)
	_chart_head = Look.hbox(10)
	Look.place(_chart_head, 14, 8)
	panel.add_child(_chart_head)
	_chart_note = Look.label("", 11, Look.DIM)
	Look.place(_chart_note, 14, 314, 560, 16)
	panel.add_child(_chart_note)
	_sticky = PanelContainer.new()
	var paper := Look.box(Color.WHITE, Look.GOLD, 2, 0, 9)
	paper.border_width_top = 4
	paper.shadow_color = Color(0, 0, 0, 0.35)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(2, 3)
	_sticky.add_theme_stylebox_override("panel", paper)
	_sticky.rotation_degrees = 1.2
	Look.place(_sticky, 22, 44)
	_sticky.custom_minimum_size = Vector2(178, 0)
	_sticky_box = Look.vbox(2)
	_sticky.add_child(_sticky_box)
	panel.add_child(_sticky)


func _build_right() -> void:
	var position_panel := Look.panel(Look.PANEL, Look.LINE, 8, 12)
	Look.place(position_panel, 888, 86, 376, 128)
	_position_box = Look.vbox(5)
	position_panel.add_child(_position_box)
	add_child(position_panel)

	var goal_panel := Look.panel(Look.PANEL, Look.LINE, 8, 12)
	Look.place(goal_panel, 888, 222, 376, 70)
	var goal := Look.vbox(6)
	var goal_row := Look.hbox(8)
	goal_row.add_child(Look.label("목표", 12, Look.DIM, "bold"))
	_goal_value = Look.label("", 20, Look.TEXT, "display")
	goal_row.add_child(_goal_value)
	_goal_target = Look.label("", 13, Look.SOFT)
	goal_row.add_child(_goal_target)
	goal_row.add_child(Look.spacer())
	_goal_days = Look.label("", 13, Look.GOLD, "bold")
	goal_row.add_child(_goal_days)
	for child in goal_row.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_END
	goal.add_child(goal_row)
	_goal_bar = Control.new()
	_goal_bar.custom_minimum_size = Vector2(350, 8)
	_goal_bar.draw.connect(_draw_goal_bar)
	goal.add_child(_goal_bar)
	goal_panel.add_child(goal)
	add_child(goal_panel)

	var preview := Look.panel(Look.GOLD_BG, Color(Look.GOLD, 0.7), 8, 12)
	Look.place(preview, 888, 300, 376, 122)
	var box := Look.vbox(5)
	_preview_title = Look.label("", 12, Look.GOLD, "bold")
	box.add_child(_preview_title)
	_preview_head = Look.wrap_label("", 12, Look.TEXT, 350)
	box.add_child(_preview_head)
	_preview_rows = Look.vbox(3)
	box.add_child(_preview_rows)
	preview.add_child(box)
	preview.clip_contents = true
	add_child(preview)


func _build_bottom() -> void:
	_energy = Control.new()
	Look.place(_energy, 34, 456, 96, 96)
	_energy.draw.connect(_draw_energy)
	add_child(_energy)
	var energy_label := Look.label("주문 한도", 12, Look.TEXT, "bold")
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Look.place(energy_label, 34, 556, 96, 18)
	add_child(energy_label)
	var pile := Control.new()
	Look.place(pile, 30, 604, 44, 58)
	pile.draw.connect(func() -> void:
		for k in 3:
			var r := Rect2(Vector2(6 - k * 3, 6 - k * 3), Vector2(36, 50))
			pile.draw_style_box(Look.box(Look.RAISED, Look.GOLD if k == 2 else Look.LINE_2, 5, 2, 0), r))
	add_child(pile)
	_pile_label = Look.label("", 12, Look.TEXT)
	Look.place(_pile_label, 82, 610, 80, 40)
	add_child(_pile_label)
	_discard_label = Look.label("", 11, Look.DIM)
	Look.place(_discard_label, 30, 670, 160, 18)
	add_child(_discard_label)

	_hand_layer = Control.new()
	_hand_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	var hint := Look.wrap_label("장 마감을 누르면 오늘 캔들이 시가부터 움직이고, 닿은 주문이 차례로 체결된다.", 12, Look.SOFT, 180)
	Look.place(hint, 1082, 482, 182, 0)
	add_child(hint)
	_end_button = Look.button("장 마감", "primary", 22)
	Look.place(_end_button, 1082, 560, 182, 60)
	_end_button.pressed.connect(end_day)
	add_child(_end_button)
	var keys := Look.label("1–9 카드 · E 장 마감", 11, Look.DIM)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Look.place(keys, 1082, 626, 182, 16)
	add_child(keys)
	_end_reason = Look.wrap_label("", 12, Look.UP_TEXT, 182)
	Look.place(_end_reason, 1082, 646, 182, 0)
	add_child(_end_reason)

	_tip = Look.panel(Look.PANEL_2, Look.GOLD, 8, 12)
	_tip.visible = false
	_tip.z_index = 50
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)


# ── 새로 그리기 ───────────────────────────────────────────────────

func refresh() -> void:
	if trade == null:
		return
	bar.refresh()
	_refresh_desk()
	_refresh_chart()
	_refresh_position()
	_refresh_goal()
	if _hovered == null:
		_show_preview(null)
	_energy.queue_redraw()
	_pile_label.text = "대기\n%d장" % trade.draw_pile.size()
	_discard_label.text = "버린 카드 %d장%s" % [trade.discard.size(), (" · 사라진 %d" % trade.exhausted.size()) if trade.exhausted.size() > 0 else ""]
	var reason := trade.why_not_end()
	_end_reason.text = reason
	for view in _views:
		view.refresh()
	_flush_messages()


func _refresh_desk() -> void:
	for child in _desk_box.get_children():
		child.queue_free()
	_desk_box.add_child(Look.label("데스크", 12, Look.DIM, "bold"))
	for id in run().members:
		var info: Dictionary = Run.MEMBERS[id]
		var head := Look.hbox(8)
		head.add_child(Sprites.portrait(info["sprite"]))
		var names := Look.vbox(0)
		names.add_child(Look.label(info["name"], 13, Look.TEXT, "bold"))
		var role := _member_role(id)
		names.add_child(Look.label(role, 11, Look.GOLD if id == "crowd" else Look.DIM))
		names.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(names)
		_desk_box.add_child(head)
		var say := _member_says(id)
		if not say.is_empty():
			var bubble := PanelContainer.new()
			var style := Look.box(Look.PAPER, Look.PAPER, 6, 0, 7)
			bubble.add_theme_stylebox_override("panel", style)
			bubble.add_child(Look.wrap_label(say, 11, Look.INK, 172))
			_desk_box.add_child(bubble)


func _member_role(id: String) -> String:
	return {"quant": "확률을 본다", "risk": "손실을 끊는다", "crowd": "역지표", "macro": "발표일에 강하다",
		"broker": "수수료 절반", "foreign_desk": "달러 수급"}.get(id, "")


func _signal_of(source: String) -> Dictionary:
	for s in trade.forecast.signals:
		if s["source"] == source:
			return s
	return {}


func _member_says(id: String) -> String:
	var name := trade.instrument.name.replace(" 선물", "")
	match id:
		"quant":
			var s := _signal_of("퀀트")
			if s.is_empty():
				return ""
			return "내일 %s %s 쪽. 제 신호는 %d%% 맞습니다." % [name, "오를" if s["says_up"] else "내릴", roundi(s["accuracy"] * 100)]
		"crowd":
			var s := _signal_of("개미 커뮤니티")
			if s.is_empty():
				return ""
			return "\"%s 무조건 %s\" 글이 폭주 중. 반대로 읽을 것." % [name, "간다" if s["says_up"] else "빠진다"]
		"foreign_desk":
			var s := _signal_of("외국계 데스크")
			if s.is_empty():
				return "달러 선물 거래에서만 신호를 드립니다."
			return "역외에서 달러 %s 우위입니다 (%d%%)." % ["매수" if s["says_up"] else "매도", roundi(s["accuracy"] * 100)]
		"risk":
			return "하루 손실이 %s을 넘으면 제가 정리합니다." % Fmt.money(maxf(100.0, trade.day_start_account * 0.05))
		"broker":
			return "수수료는 절반만 받겠습니다."
		"macro":
			if trade.kind != "trade":
				return "발표일입니다. 퀀트 신호가 5%p 더 정확합니다."
			return "평범한 날엔 조용히 있겠습니다."
	return ""


func _refresh_chart() -> void:
	chart.bars = trade.history_bars(HISTORY)
	var f := trade.forecast
	chart.forecast = {"low": f.low(), "high": f.high(), "up": f.up_probability() if f.has_direction() else -1.0}
	chart.show_ma = run().notes.level("moving_average") >= 1
	chart.today_label = trade.today().short_date()
	chart.lines = _order_lines()
	chart.queue_redraw()
	for child in _chart_head.get_children():
		child.queue_free()
	_chart_head.add_child(Look.label(trade.instrument.name, 18, Look.TEXT, "display"))
	var prev := trade.yesterday()
	var change := prev.close - trade.bars[trade.start_index + trade.day - 1 - 1].close if trade.start_index + trade.day >= 2 else 0.0
	var head := Look.label("전일 종가", 12, Look.DIM)
	_chart_head.add_child(head)
	var close := Look.label(trade.instrument.price_text(prev.close), 13, Look.up_down(change), "mono_bold")
	_chart_head.add_child(close)
	var diff := Look.label(("%s%s" % ["+" if change >= 0 else "", trade.instrument.price_text(change)]), 12, Look.up_down(change), "mono")
	_chart_head.add_child(diff)
	for child in _chart_head.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_END
	var note := "일봉 · 캔들은 실제 종가"
	if prev.estimated:
		note += ", 시가·고가·저가는 추정"
	if chart.show_ma:
		note += " · 금색 선 5일 이동평균"
	var unknown := _unknown_today()
	if not unknown.is_empty():
		note = "차트에 모르는 모양이 보인다. 거래가 끝나면 투자 노트에 적힌다."
	_chart_note.text = note
	_chart_note.add_theme_color_override("font_color", Look.GOLD if not unknown.is_empty() else Look.DIM)
	_refresh_sticky()


func _unknown_today() -> Array:
	var list := []
	for id in Patterns.detect(trade.bars, trade.start_index + trade.day):
		if run().notes.level(id) < 1:
			list.append(id)
	return list


func _refresh_sticky() -> void:
	for child in _sticky_box.get_children():
		child.queue_free()
	var f := trade.forecast
	_sticky_box.add_child(Look.label("시장 전망표 · " + trade.today().short_date(), 11, Look.GOLD_DARK, "bold"))
	if f.has_direction():
		var p := f.up_probability()
		var up := p >= 0.5
		var row := Look.hbox(4)
		row.add_child(Look.label("방향", 13, Look.INK, "bold"))
		row.add_child(Look.label("%s %s %d%%" % ["▲" if up else "▼", "상승" if up else "하락", roundi((p if up else 1.0 - p) * 100)], 13, Look.UP_STRONG if up else Look.DOWN_STRONG, "bold"))
		_sticky_box.add_child(row)
	else:
		_sticky_box.add_child(Look.label("방향 신호 없음", 13, Look.INK, "bold"))
	if run().notes.level("volatility") >= 1:
		_sticky_box.add_child(Look.label("범위 %s ~ %s" % [trade.instrument.price_text(f.low()), trade.instrument.price_text(f.high())], 12, Look.INK, "mono"))
	else:
		_sticky_box.add_child(Look.label("금색 상자 = 오늘 예상 범위", 11, Look.INK_SOFT))
	for s in f.signals:
		var arrow := "▲" if s["says_up"] else "▼"
		var extra := " 역지표" if s["contrarian"] else ""
		_sticky_box.add_child(Look.label("%s %s%s · %d%%" % [s["source"], arrow, extra, roundi(s["accuracy"] * 100)], 11, Look.INK_SOFT))


func _order_lines() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var pos := trade.position
	if not pos.is_flat():
		list.append({"price": pos.avg, "color": Look.TEXT, "label": "평단 · %s" % _qty_text(pos.qty), "width": 1.2})
	for order in trade.orders:
		var color := Look.UP_TEXT if order.kind == Order.Kind.TAKE else Look.DOWN_TEXT
		list.append({"price": order.price, "color": color, "label": order.label(), "dashed": true, "right": true})
	for option in trade.options:
		if option["kind"] == "protect":
			list.append({"price": option["strike"], "color": Color("b9a6ff"), "label": "보호 옵션", "dashed": true, "right": true})
	if run().notes.level("margin_call") >= 2 and not pos.is_flat():
		list.append({"price": trade.margin_call_price(), "color": Look.UP, "label": "마진콜", "dashed": true})
	return list


func _qty_text(qty: int) -> String:
	if qty == 0:
		return "없음"
	return "%s %d계약" % ["롱" if qty > 0 else "숏", absi(qty)]


func _refresh_position() -> void:
	for child in _position_box.get_children():
		child.queue_free()
	var pos := trade.position
	var inst := trade.instrument
	var close := trade.yesterday().close
	var head := Look.hbox(8)
	head.add_child(Look.label("내 포지션", 12, Look.DIM, "bold"))
	head.add_child(Look.spacer())
	if run().notes.level("leverage") >= 2 and not pos.is_flat():
		head.add_child(Look.label("레버리지 %.1f배" % trade.leverage(), 11, Look.DIM))
	_position_box.add_child(head)
	var row := Look.hbox(10)
	if pos.is_flat():
		row.add_child(Look.tag("포지션 없음", Look.LINE_2))
	else:
		row.add_child(Look.tag(_qty_text(pos.qty), Look.UP_STRONG if pos.qty > 0 else Look.DOWN_STRONG))
		row.add_child(Look.label("평단 " + inst.price_text(pos.avg), 13, Look.TEXT, "mono"))
		row.add_child(Look.spacer())
		var profit := pos.open_profit(close, inst.multiplier)
		row.add_child(Look.label(Fmt.signed_money(profit), 20, Look.up_down(profit), "display"))
	for child in row.get_children():
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_position_box.add_child(row)
	var queued := 0
	for q in trade.queued:
		queued += int(q["delta"])
	if not trade.queued.is_empty():
		var labels: Array[String] = []
		for q in trade.queued:
			labels.append("%s %+d" % [q["label"], int(q["delta"])])
		_position_box.add_child(Look.label("시가 체결 대기 · " + ", ".join(labels), 12, Look.GOLD, "bold"))
	var orders: Array[String] = []
	for order in trade.orders:
		orders.append("%s %s" % [order.label(), inst.price_text(order.price)])
	if trade.close_at_close:
		orders.append("종가 청산")
	for option in trade.options:
		orders.append("보호 옵션" if option["kind"] == "protect" else "스트래들")
	if not orders.is_empty():
		_position_box.add_child(Look.label("걸린 주문 · " + " · ".join(orders), 12, Look.SOFT))
	if run().notes.level("margin_call") >= 2 and not pos.is_flat():
		var mc := trade.margin_call_price()
		_position_box.add_child(Look.label("마진콜 가격 약 %s · 지금보다 %s %s" % [inst.price_text(mc), inst.price_text(absf(close - mc)), "아래" if mc < close else "위"], 12, Look.SOFT))
	if pos.is_flat() and trade.queued.is_empty():
		_position_box.add_child(Look.wrap_label("롱이나 숏 카드를 내면 내일이 아니라 오늘 시가에 체결된다.", 12, Look.DIM, 350))


func _refresh_goal() -> void:
	var pnl := trade.trade_pnl()
	_goal_value.text = Fmt.signed_money(pnl)
	_goal_value.add_theme_color_override("font_color", Look.up_down(pnl))
	_goal_target.text = "/ +%s" % Fmt.money(trade.target)
	var left := trade.days - trade.day
	var names: Array[String] = []
	for i in range(trade.day, trade.days):
		names.append(trade.bars[trade.start_index + i].weekday_name())
	_goal_days.text = "D-%d · %s" % [left, "·".join(names)]
	_goal_bar.queue_redraw()


func _draw_goal_bar() -> void:
	var w := _goal_bar.size.x
	_goal_bar.draw_rect(Rect2(0, 0, w, 8), Look.LINE)
	var pnl := trade.trade_pnl()
	var ratio := clampf(pnl / trade.target, 0.0, 1.0)
	if not is_nan(_goal_ghost):
		var ghost := clampf(_goal_ghost / trade.target, 0.0, 1.0)
		_goal_bar.draw_rect(Rect2(0, 0, w * ghost, 8), Color(Look.GOLD, 0.35))
	_goal_bar.draw_rect(Rect2(0, 0, w * ratio, 8), Look.GOLD)


func _draw_energy() -> void:
	var c := Vector2(48, 48)
	var full := trade.energy > 0
	_energy.draw_circle(c, 46, Look.GOLD if full else Look.LINE_2)
	_energy.draw_circle(c, 41, Look.INK)
	_energy.draw_circle(c, 38, Look.GOLD if full else Look.RAISED)
	var text := "%d/%d" % [trade.energy, Trade.ENERGY]
	var font := Look.font("display")
	var s := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	_energy.draw_string(font, c + Vector2(-s.x * 0.5, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Look.INK if full else Look.DIM)


# ── 손패 ──────────────────────────────────────────────────────────

func _deal() -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
	_hovered = null
	for card in trade.hand:
		_add_view(card)
	_layout_hand(false)
	for i in _views.size():
		var view := _views[i]
		var target := view.position
		view.position = Vector2(40, 600)
		view.scale = Vector2(0.5, 0.5)
		view.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(view, "position", target, 0.28).set_delay(i * 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(view, "scale", Vector2.ONE, 0.28).set_delay(i * 0.06)
		tween.tween_property(view, "modulate:a", 1.0, 0.15).set_delay(i * 0.06)
	for card in trade.hand:
		if card.type() == "pattern":
			app.toast("%s 발견 — %s 카드가 들어왔다" % [Patterns.label(card.def()["pattern"]), card.name()])


func _add_view(card: Card) -> CardView:
	var view := CardView.new().setup(card, trade)
	view.hovered.connect(_on_hover)
	view.unhovered.connect(_on_unhover)
	view.clicked.connect(_on_click)
	_hand_layer.add_child(view)
	_views.append(view)
	return view


func _layout_hand(animate := true) -> void:
	var n := _views.size()
	var spacing := minf(124.0, 760.0 / maxf(n, 1))
	for i in n:
		var view := _views[i]
		var off := i - (n - 1) * 0.5
		view.home = Vector2(HAND_CENTER + off * spacing - CardView.W * 0.5, HAND_Y + off * off * 2.5)
		view.home_rotation = deg_to_rad(off * 2.0)
		view.z_index = i
		var lifted := view == _hovered
		var pos := view.home + (Vector2(0, -52) if lifted else Vector2.ZERO)
		var rot := 0.0 if lifted else view.home_rotation
		if lifted:
			view.z_index = 40
		if animate:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(view, "position", pos, 0.12)
			tween.tween_property(view, "rotation", rot, 0.12)
			tween.tween_property(view, "scale", Vector2(1.08, 1.08) if lifted else Vector2.ONE, 0.12)
		else:
			view.position = pos
			view.rotation = rot


func _on_hover(view: CardView) -> void:
	if busy:
		return
	_hovered = view
	view.selected = true
	view.queue_redraw()
	_layout_hand()
	_show_tip(view)
	_show_preview(view.card)
	app.sfx.play("click", -22.0, 40)


func _on_unhover(view: CardView) -> void:
	if _hovered == view:
		_hovered = null
		view.selected = false
		view.queue_redraw()
		_layout_hand()
		_tip.visible = false
		_show_preview(null)


func _on_click(view: CardView) -> void:
	play_view(view)


func play_view(view: CardView) -> void:
	if busy or not _views.has(view):
		return
	var index := trade.hand.find(view.card)
	var reason := trade.play(index)
	if not reason.is_empty():
		app.toast(reason, Look.UP_TEXT)
		var tween := create_tween()
		tween.tween_property(view, "position:x", view.position.x + 8, 0.05)
		tween.tween_property(view, "position:x", view.position.x - 8, 0.05)
		tween.tween_property(view, "position:x", view.position.x, 0.05)
		return
	app.sfx.play("card", -6.0)
	_views.erase(view)
	if _hovered == view:
		_hovered = null
	_tip.visible = false
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fly := create_tween().set_parallel(true)
	fly.tween_property(view, "position", Vector2(520, 180), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(view, "scale", Vector2(0.5, 0.5), 0.22)
	fly.tween_property(view, "modulate:a", 0.0, 0.22)
	fly.chain().tween_callback(view.queue_free)
	# 뽑기 카드로 새로 들어온 카드
	for card in trade.hand:
		var known := false
		for other in _views:
			if other.card == card:
				known = true
		if not known:
			var added := _add_view(card)
			added.position = Vector2(40, 600)
	_layout_hand()
	refresh()


# ── 미리 보기 ─────────────────────────────────────────────────────

func _show_tip(view: CardView) -> void:
	for child in _tip.get_children():
		child.queue_free()
	var id := view.keyword()
	var parts := CardDB.text(view.card, trade)
	var box := Look.vbox(6)
	var head := Look.hbox(8)
	var title: String = NoteDB.name_of(id) if not id.is_empty() else String(parts[1])
	head.add_child(Look.label(title, 18, Look.GOLD, "display"))
	head.add_child(Look.spacer())
	var notes := run().notes
	var level := notes.level(id) if not id.is_empty() else 0
	if not id.is_empty():
		head.add_child(Look.label(Look.stars(level, notes._cap(id)), 12, Look.GOLD))
	box.add_child(head)
	var text := ""
	if id.is_empty():
		text = "투자 노트에 없는 카드다."
	elif level >= 1:
		text = NoteDB.ENTRIES[id]["texts"][level - 1]
		if level > 1:
			text = NoteDB.ENTRIES[id]["texts"][0] + "\n" + text
	else:
		text = "아직 투자 노트에 없는 낱말. 카드를 한 번 쓰면 적힌다."
	box.add_child(Look.wrap_label(text, 13, Look.TEXT, 236))
	box.add_child(Look.label("N 투자 노트에서 더 보기", 11, Look.DIM))
	_tip.add_child(box)
	_tip.custom_minimum_size = Vector2(262, 0)
	_tip.size = Vector2(262, 0)
	var x := view.home.x + CardView.W + 14 if view.home.x < 560 else view.home.x - 262 - 14
	_tip.position = Vector2(x, 432)
	_tip.visible = true


func _show_preview(card: Card) -> void:
	for child in _preview_rows.get_children():
		child.queue_free()
	chart.preview_lines.clear()
	_goal_ghost = NAN
	if card == null:
		_preview_title.text = "카드 미리 보기"
		_preview_head.text = "카드에 마우스를 올리면 오늘 그 주문이 어떻게 될지 여기에 나온다. 클릭하거나 숫자 키로 낸다."
		chart.queue_redraw()
		_goal_bar.queue_redraw()
		return
	var info := _preview(card)
	_preview_title.text = "%s — 미리 보기" % card.name()
	var reason := trade.why_not(card)
	_preview_head.text = (("지금은 못 낸다: %s. " % reason) if not reason.is_empty() else "") + String(info["head"])
	_preview_head.add_theme_color_override("font_color", Look.UP_TEXT if not reason.is_empty() else Look.TEXT)
	for row: Array in info["rows"]:
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", Look.box(Look.PANEL_2, Look.PANEL_2, 4, 0, 3))
		var h := Look.hbox(8)
		h.add_child(Look.label(row[0], 12, Look.SOFT))
		h.add_child(Look.spacer())
		h.add_child(Look.label(row[1], 12, row[2], "mono_bold"))
		line.add_child(h)
		_preview_rows.add_child(line)
	for line: Dictionary in info["lines"]:
		chart.preview_lines.append(line)
	_goal_ghost = info.get("ghost", NAN)
	chart.queue_redraw()
	_goal_bar.queue_redraw()


func _preview(card: Card) -> Dictionary:
	var inst := trade.instrument
	var m := inst.multiplier
	var c := trade.yesterday().close
	var span := trade.expected_span()
	var hi := trade.forecast.high()
	var lo := trade.forecast.low()
	var q := trade.planned_qty()
	var dir := signi(q)
	var base := trade.trade_pnl()
	var rows: Array = []
	var lines: Array[Dictionary] = []
	var head := ""
	var ghost := NAN
	var pnl_at := func(qty: int, price: float) -> float: return base + qty * (price - c) * m
	var row := func(when: String, pnl: float) -> Array:
		var text := Fmt.signed_money(pnl) + (" · 달성" if pnl >= trade.target else "")
		return [when, text, Look.up_down(pnl)]
	var price := func(value: float) -> String: return inst.price_text(value)
	var delta := trade._entry_delta(card)
	if card.is_habit():
		return {"head": "낼 수 없는 카드다. " + "".join(CardDB.text(card, trade)), "rows": [], "lines": lines}
	if delta != 0 and card.id not in ["close", "half"]:
		var nq := q + delta
		head = "시가에 %s %d계약 → %s. 증거금 %s이 묶인다." % ["롱" if delta > 0 else "숏", absi(delta), _qty_text(nq), Fmt.money(absi(nq) * inst.margin)]
		rows.append(row.call("예상 고점 %s에 끝나면" % price.call(hi), pnl_at.call(nq, hi)))
		rows.append(row.call("예상 저점 %s에 끝나면" % price.call(lo), pnl_at.call(nq, lo)))
		var stop_dist: float = -1.0
		var stop_dir := signi(delta)
		if card.id == "contra":
			stop_dist = card.value("dist")
		elif card.type() == "pattern" and card.def().has("dist"):
			stop_dist = card.def()["dist"]
		if stop_dist > 0.0:
			var s := c - stop_dir * stop_dist * span
			rows.append(row.call("자동 손절 %s에 걸리면" % price.call(s), pnl_at.call(nq, s)))
			lines.append({"price": s, "color": Look.DOWN_TEXT, "label": "새 손절", "dashed": true, "right": true})
		ghost = maxf(pnl_at.call(nq, hi), pnl_at.call(nq, lo))
		return {"head": head, "rows": rows, "lines": lines, "ghost": ghost}
	match card.id:
		"stop", "take":
			var dist: float = card.value("dist")
			var sign := -1.0 if card.id == "stop" else 1.0
			var p := c + sign * dir * dist * span
			head = "%s을 %s에 건다. 장중에 닿으면 %s을 그 값에 정리한다. 걸린 주문은 포지션이 있는 동안 남는다." % ["손절" if card.id == "stop" else "익절", price.call(p), _qty_text(q)]
			if dir != 0:
				rows.append(row.call("%s에 닿으면 확정" % price.call(p), pnl_at.call(q, p)))
				rows.append(row.call("안 닿고 전일 종가에 끝나면", base))
				lines.append({"price": p, "color": Look.DOWN_TEXT if card.id == "stop" else Look.UP_TEXT, "label": "새 " + ("손절" if card.id == "stop" else "익절"), "dashed": true, "right": true})
				ghost = pnl_at.call(q, p) if card.id == "take" else NAN
		"trail":
			var d: float = card.value("dist") * span
			head = "손절선이 좋은 가격을 %s 뒤에서 따라간다. 번 것을 지키며 추세를 탄다." % price.call(d)
			if dir != 0:
				var far := hi if dir > 0 else lo
				rows.append(row.call("%s까지 갔다 돌아서면" % price.call(far), pnl_at.call(q, far - dir * d)))
				rows.append(row.call("바로 밀리면 %s" % price.call(c - dir * d), pnl_at.call(q, c - dir * d)))
				lines.append({"price": c - dir * d, "color": Look.DOWN_TEXT, "label": "트레일링 시작", "dashed": true, "right": true})
		"close":
			head = "시가에 %s을 모두 정리한다. 일일정산으로 번 돈은 이미 계좌에 있다." % _qty_text(q)
			rows.append(row.call("전일 종가 근처에서 정리하면", base))
		"half":
			var half := q / 2 if absi(q) > 1 else q
			head = "시가에 %d계약을 정리하고 %s이 남는다." % [absi(half), _qty_text(q - half)]
			rows.append(row.call("예상 고점 %s에 끝나면" % price.call(hi), pnl_at.call(q - half, hi)))
			rows.append(row.call("예상 저점 %s에 끝나면" % price.call(lo), pnl_at.call(q - half, lo)))
		"moc":
			head = "오늘 종가에 모두 정리한다. 밤사이 뉴스로 다음 날 시가가 튀는 갭을 피한다."
			rows.append(row.call("예상 고점 %s에 끝나면" % price.call(hi), pnl_at.call(q, hi)))
			rows.append(row.call("예상 저점 %s에 끝나면" % price.call(lo), pnl_at.call(q, lo)))
		"option":
			var premium: float = card.value("premium") * span * m * absi(q)
			var strike: float = c - dir * float(card.value("strike")) * span
			var bad := lo if dir > 0 else hi
			var cover := maxf(0.0, (strike - bad) * dir) * absi(q) * m
			head = "권리값 %s을 지금 낸다. 오늘 %s 너머로 밀린 만큼 돌려받는다." % [Fmt.money(premium), price.call(strike)]
			rows.append(row.call("%s에 끝나면 (옵션 있음)" % price.call(bad), pnl_at.call(q, bad) - premium + cover))
			rows.append(row.call("%s에 끝나면 (옵션 없음)" % price.call(bad), pnl_at.call(q, bad)))
			lines.append({"price": strike, "color": Color("b9a6ff"), "label": "행사가", "dashed": true, "right": true})
		"straddle":
			var units: int = card.value("units")
			var paid: float = card.value("premium") * span * m * units
			head = "권리값 %s. 오늘 종가가 %s에서 멀어질수록 번다. 방향은 몰라도 된다." % [Fmt.money(paid), price.call(c)]
			rows.append(row.call("예상 고점 %s에 끝나면" % price.call(hi), pnl_at.call(q, hi) - paid + absf(hi - c) * units * m))
			rows.append(row.call("전일 종가 그대로면", pnl_at.call(q, c) - paid))
			rows.append(row.call("예상 저점 %s에 끝나면" % price.call(lo), pnl_at.call(q, lo) - paid + absf(lo - c) * units * m))
		"foreign", "research":
			var p := trade.forecast.up_probability()
			head = "방향 신호를 하나 더 받는다 (맞을 확률 %d%%). 지금 전망은 %s %d%%." % [roundi(card.value("acc") * 100), "상승" if p >= 0.5 else "하락", roundi(maxf(p, 1.0 - p) * 100)]
			if card.value("draw", 0) > 0:
				head += " 카드 %d장도 뽑는다." % card.value("draw")
		"wait":
			head = "아무 주문도 내지 않고 카드 %d장을 뽑는다. 쉬는 것도 포지션이다." % card.value("draw")
		_:
			head = "".join(CardDB.text(card, trade))
	return {"head": head, "rows": rows, "lines": lines, "ghost": ghost}


# ── 장 마감 ───────────────────────────────────────────────────────

func end_day() -> void:
	if busy:
		return
	var reason := trade.why_not_end()
	if not reason.is_empty():
		app.toast(reason, Look.UP_TEXT)
		return
	busy = true
	_tip.visible = false
	_show_preview(null)
	_end_button.disabled = true
	var lines_before := chart.lines.duplicate()
	var range_before := chart.price_range()
	_result = trade.end_day()
	for view in _views:
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := create_tween().set_parallel(true)
		tween.tween_property(view, "position:y", 760.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(view, "modulate:a", 0.0, 0.25)
	var today: Bar = _result["bar"]
	chart.forecast = {}
	chart.lines = lines_before
	chart.lock_range(minf(range_before.x, today.low), maxf(range_before.y, today.high))
	chart.live = {"open": today.open, "high": today.open, "low": today.open, "close": today.open}
	chart.live_trace = PackedVector2Array()
	chart.marks.clear()
	_event_index = 0
	_mark_count = 0
	_running_account = float(_result["account_before"])
	bar.set_context(today.long_date() + " · 장중", [[Look.kind_name(trade.kind), Look.kind_color(trade.kind)]])
	app.sfx.play("bell", -12.0)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_method(_replay_step, 0.0, 3.0, 2.6)
	tween.tween_interval(0.3)
	tween.tween_callback(_show_settlement)


func _replay_step(tau: float) -> void:
	var points: PackedFloat64Array = _result["points"]
	var s := mini(int(tau), 2)
	var k := clampf(tau - s, 0.0, 1.0)
	var price := lerpf(points[s], points[s + 1], k)
	chart.live["close"] = price
	chart.live["high"] = maxf(chart.live["high"], price)
	chart.live["low"] = minf(chart.live["low"], price)
	chart.trace_point(tau, price)
	var events: Array = _result["events"]
	while _event_index < events.size() and float(events[_event_index]["t"]) <= tau + 0.0001:
		_fire_event(events[_event_index])
		_event_index += 1
	chart.queue_redraw()


func _fire_event(event: Dictionary) -> void:
	_running_account += float(event.get("amount", 0.0)) - float(event.get("fee", 0.0))
	bar.shown_account = _running_account
	bar.refresh()
	var kind: String = event["kind"]
	if kind == "settle":
		return
	var color := Look.GOLD
	if kind == "fill":
		var delta := int(event.get("delta", 0))
		color = Look.UP_TEXT if delta > 0 else Look.DOWN_TEXT
		app.sfx.play("buy" if delta > 0 else "sell", -8.0)
		if String(event["text"]).contains("마진콜"):
			app.sfx.play("alarm", -8.0)
			color = Look.UP
	elif kind == "option":
		app.sfx.play("coin", -8.0)
	_mark_count += 1
	var t := float(event["t"])
	chart.marks.append({"x": chart.trace_x(t), "price": event["price"], "color": color, "index": _mark_count})
	var amount := float(event.get("amount", 0.0))
	var text := "%d  %s %s" % [_mark_count, event["text"], trade.instrument.price_text(event["price"])]
	if absf(amount) > 0.05:
		text += "  " + Fmt.signed_money(amount)
	var label := Look.label(text, 12, color, "bold")
	var bg := PanelContainer.new()
	bg.add_theme_stylebox_override("panel", Look.box(Color(Look.BAR, 0.92), color, 4, 1, 5))
	bg.add_child(label)
	var y := chart.y_of(event["price"])
	bg.position = Vector2(clampf(chart.trace_x(t) - 180, 60, 400), clampf(y - 34, 40, 290))
	chart.add_child(bg)
	var tween := create_tween()
	tween.tween_property(bg, "position:y", bg.position.y - 14, 1.6)
	tween.parallel().tween_property(bg, "modulate:a", 0.0, 0.6).set_delay(1.4)
	tween.tween_callback(bg.queue_free)


func _show_settlement() -> void:
	# 남은 사건 (종가 사건) 을 마저 반영한다.
	var events: Array = _result["events"]
	while _event_index < events.size():
		_fire_event(events[_event_index])
		_event_index += 1
	bar.shown_account = NAN
	bar.refresh()
	_settle_ready = false
	_settle = Control.new()
	_settle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settle.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settle)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.55)
	Look.place(shade, 0, 430, 1280, 290)
	_settle.add_child(shade)
	var panel := Look.panel(Look.PANEL_2, Look.GOLD, 10, 18)
	Look.place(panel, 888, 86, 376, 336)
	panel.custom_minimum_size = Vector2(376, 336)
	_settle.add_child(panel)
	_settle_rows = Look.vbox(6)
	panel.add_child(_settle_rows)
	var today: Bar = _result["bar"]
	var inst := trade.instrument
	var prev_close := trade.bars[trade.start_index + trade.day - 2].close if trade.day >= 1 else today.open
	var change := today.close - prev_close
	var rows: Array[Control] = []
	rows.append(Look.label("장 마감 정산 · " + today.short_date(), 20, Look.GOLD, "display"))
	rows.append(Look.wrap_label("%s %s %s → 종가 %s" % [inst.name, "올라" if change >= 0 else "내려", inst.price_text(absf(change)), inst.price_text(today.close)], 13, Look.up_down(change), 340))
	var day_note := "day_" + today.date.substr(5, 2) + today.date.substr(8, 2)
	if NoteDB.ENTRIES.has(day_note):
		rows.append(Look.wrap_label("이날 있었던 일 · " + String(NoteDB.ENTRIES[day_note]["texts"][0]), 12, Look.GOLD, 340))
		run().notes.learn(day_note)
	var index := 0
	var fees := 0.0
	for event: Dictionary in events:
		fees += float(event.get("fee", 0.0))
		var kind: String = event["kind"]
		var amount := float(event.get("amount", 0.0))
		if kind == "settle":
			if int(event.get("qty", 0)) == 0:
				continue
			var formula := ""
			if run().notes.level("settlement") >= 1 and int(event.get("qty", 0)) != 0:
				formula = "(%s − %s) × %s × %d계약" % [inst.price_text(today.close), inst.price_text(event["basis"]), _mult_text(), int(event["qty"])]
			rows.append(_settle_row("일일정산", formula, amount))
			continue
		if kind == "close":
			rows.append(_settle_row(String(event["text"]), "", 0.0))
			continue
		index += 1
		var detail := ""
		if kind == "fill":
			detail = "%+d계약 @ %s" % [int(event["delta"]), inst.price_text(event["price"])]
		rows.append(_settle_row("%d  %s" % [index, event["text"]], detail, amount))
	if fees > 0.0:
		rows.append(_settle_row("수수료 (게임 값)", "", -fees))
	var line := ColorRect.new()
	line.color = Look.LINE_2
	line.custom_minimum_size = Vector2(340, 1)
	rows.append(line)
	var account_row := Look.hbox(8)
	account_row.add_child(Look.label("계좌", 13, Look.SOFT))
	account_row.add_child(Look.spacer())
	var account_label := Look.label("%s → %s" % [Fmt.money(_result["account_before"]), Fmt.money(_result["account_after"])], 16, Look.TEXT, "display")
	account_row.add_child(account_label)
	rows.append(account_row)
	var pnl := trade.trade_pnl()
	var goal_row := Look.hbox(8)
	goal_row.add_child(Look.label("이번 거래 손익", 13, Look.SOFT))
	goal_row.add_child(Look.spacer())
	goal_row.add_child(Look.label("%s / 목표 +%s" % [Fmt.signed_money(pnl), Fmt.money(trade.target)], 16, Look.up_down(pnl), "display"))
	rows.append(goal_row)
	var verdict := ""
	var verdict_color := Look.GOLD
	match trade.state:
		Trade.State.WON:
			verdict = "목표 달성! 포지션을 정리하고 보상을 받는다."
		Trade.State.FAILED:
			verdict = "기한이 끝났다. 목표에 못 미쳤다."
			verdict_color = Look.DOWN_TEXT
		Trade.State.BUSTED:
			verdict = "마진콜 — 계좌가 선 아래로 떨어져 반대매매됐다."
			verdict_color = Look.UP
		_:
			verdict = "D-%d · 포지션과 걸린 주문은 내일로 넘어간다." % (trade.days - trade.day)
	rows.append(Look.wrap_label(verdict, 14, verdict_color, 340, "bold"))
	var what_if := _what_if(events, today)
	if not what_if.is_empty():
		rows.append(Look.wrap_label(what_if, 12, Look.SOFT, 340))
	for message in _new_messages():
		rows.append(Look.wrap_label(message, 12, Look.UP_TEXT, 340))
	var button := Look.button("다음 날" if not trade.is_over() else "거래 결과", "primary", 18, "Space")
	button.pressed.connect(_continue)
	rows.append(button)
	for row in rows:
		row.modulate.a = 0.0
		_settle_rows.add_child(row)
	_settle_tween = create_tween()
	for row in rows:
		_settle_tween.tween_property(row, "modulate:a", 1.0, 0.12)
		_settle_tween.tween_callback(func() -> void: app.sfx.play("coin", -18.0))
		_settle_tween.tween_interval(0.08)
	_settle_tween.tween_callback(func() -> void: _settle_ready = true)
	match trade.state:
		Trade.State.WON:
			app.sfx.play("win", -6.0)
		Trade.State.BUSTED:
			app.sfx.play("alarm", -6.0)
		Trade.State.FAILED:
			app.sfx.play("lose", -8.0)


## 주문이 체결된 날, 그 주문이 없었다면 종가까지 어땠을지 한 줄로.
func _what_if(events: Array, today: Bar) -> String:
	var m := trade.instrument.multiplier
	for event: Dictionary in events:
		if event["kind"] != "fill":
			continue
		var text := String(event["text"])
		var name := ""
		var subjects := {"손절": "손절이", "익절": "익절이", "트레일링": "트레일링 스톱이", "리스크 매니저": "리스크 매니저가"}
		for key: String in subjects:
			if text.contains(key):
				name = subjects[key]
		if name.is_empty():
			continue
		var held := -int(event["delta"])
		var diff := (today.close - float(event["price"])) * held * m
		if absf(diff) < 0.5:
			continue
		if diff > 0.0:
			return "만약 %s 없었다면 종가까지 %s 더 벌었다. 대신 그 사이 더 밀렸을 수도 있었다." % [name, Fmt.money(diff)]
		return "만약 %s 없었다면 종가까지 %s 더 잃었다. 주문이 계좌를 지켰다." % [name, Fmt.money(-diff)]
	return ""


func _mult_text() -> String:
	var m := trade.instrument.multiplier
	return "%s만" % (Fmt.number(m, 0) if is_equal_approx(m, roundf(m)) else Fmt.number(m, 1))


func _settle_row(title: String, detail: String, amount: float) -> Control:
	var box := Look.vbox(0)
	var row := Look.hbox(8)
	row.add_child(Look.label(title, 13, Look.TEXT))
	row.add_child(Look.spacer())
	if absf(amount) > 0.049:
		row.add_child(Look.label(Fmt.signed_money(amount), 14, Look.up_down(amount), "mono_bold"))
	box.add_child(row)
	if not detail.is_empty():
		box.add_child(Look.label(detail, 11, Look.DIM, "mono"))
	return box


func _new_messages() -> Array[String]:
	var list: Array[String] = []
	while _message_index < trade.messages.size():
		list.append(trade.messages[_message_index])
		_message_index += 1
	return list


func _flush_messages() -> void:
	if busy:
		return
	for message in _new_messages():
		app.toast(message, Look.UP_TEXT)


func _continue() -> void:
	if _settle == null:
		return
	if not _settle_ready:
		_settle_tween.custom_step(100.0)
		return
	if trade.is_over():
		app.finish_trade(trade, _fresh_start)
		return
	_settle.queue_free()
	_settle = null
	chart.live = {}
	chart.marks.clear()
	chart.live_trace = PackedVector2Array()
	chart.unlock_range()
	for child in chart.get_children():
		if child is PanelContainer:
			child.queue_free()
	busy = false
	_end_button.disabled = false
	bar.set_context(trade.today().long_date() + " · 장 시작 전", [[Look.kind_name(trade.kind), Look.kind_color(trade.kind)]])
	refresh()
	_deal()
	app.sfx.play("bell", -16.0)


func handle_key(event: InputEventKey) -> bool:
	if _coach != null:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			_next_coach()
		return true
	if _settle != null:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
			_continue()
			return true
		return false
	if busy:
		return false
	if event.keycode == KEY_E or event.keycode == KEY_ENTER:
		end_day()
		return true
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var index := event.keycode - KEY_1
		var ordered := _views.duplicate()
		if index < ordered.size():
			play_view(ordered[index])
		return true
	return false

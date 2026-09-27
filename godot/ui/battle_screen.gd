class_name BattleScreen
extends Control
## 전투 화면: 왼쪽은 호가창과 주문, 오른쪽은 전투 공간, 그 아래 차트와 전장 소식.
##
## 키보드: A 돌격 · S 벽 쌓기 · D 포지션 정리 · F 주문 취소 · Q/W/E 스킬 · 1~4 수량 · Space 일시정지

signal exit_requested
signal rematch_requested

## 장중 1분이 몇 초인지 (1배속).
const MINUTE_SECONDS := 0.5
const FRACTIONS := [0.1, 0.25, 0.5, 1.0]
const SKILL_KEYS := ["Q", "W", "E"]


## 매수세 vs 매도세 줄다리기 막대.
class TugGauge:
	extends Control
	var share := 0.5

	func _draw() -> void:
		var h := size.y
		var split := size.x * clampf(share, 0.02, 0.98)
		draw_rect(Rect2(0, 0, split, h), WarStyle.BULL)
		draw_rect(Rect2(split, 0, size.x - split, h), WarStyle.BEAR)
		draw_rect(Rect2(split - 2, -3, 4, h + 6), Color.WHITE)


var engine: BattleEngine
var _company: Company
var _faction: int
var _paused := false
var _fast := false
var _accum := 0.0
var _fraction := 0.25

var _clock_label: Label
var _price_label: Label
var _change_label: Label
var _buy_label: Label
var _sell_label: Label
var _strength_label: Label
var _gauge: TugGauge
var _pause_button: Button
var _speed_button: Button
var _book_view: OrderBookView
var _pnl_label: Label
var _pnl_rate_label: Label
var _position_label: Label
var _record_label: Label
var _fraction_buttons: Array[Button] = []
var _available_label: Label
var _attack_button: Button
var _wall_button: Button
var _close_button: Button
var _cancel_button: Button
var _battlefield: Battlefield
var _hand_box: HBoxContainer
var _hand_signature := "-"
var _chart: CandleChart
var _news: RichTextLabel
var _news_serial := -1
var _toast: Label
var _toast_time := 0.0
var _overlay: Control


func _init(company: Company, faction: int, seed_value := -1) -> void:
	_company = company
	_faction = faction
	engine = BattleEngine.new(company, faction, seed_value)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()


func _process(delta: float) -> void:
	if _toast_time > 0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
	if _paused or engine.is_over() or _overlay != null:
		return
	_accum += delta * (2.0 if _fast else 1.0)
	while _accum >= MINUTE_SECONDS and not engine.is_over():
		_accum -= MINUTE_SECONDS
		advance(1)


## n분 진행한다 (테스트·자동 진행용으로도 쓴다).
func advance(minutes: int) -> void:
	for i in minutes:
		if engine.is_over():
			break
		engine.step()
	_refresh()
	if engine.is_over() and _overlay == null:
		_show_result()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_A:
			_act(engine.attack(_fraction))
		KEY_S:
			_act(engine.place_wall(_fraction))
		KEY_D:
			_act(engine.close_position())
		KEY_F:
			_act(engine.cancel_orders())
		KEY_Q:
			_act(engine.use_skill(0))
		KEY_W:
			_act(engine.use_skill(1))
		KEY_E:
			_act(engine.use_skill(2))
		KEY_1, KEY_2, KEY_3, KEY_4:
			_set_fraction(FRACTIONS[key.keycode - KEY_1])
		KEY_SPACE:
			_toggle_pause()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


# ── 화면 구성 ────────────────────────────────────────────────────

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(410, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(_build_book_panel())
	left.add_child(_build_account_panel())
	left.add_child(_build_action_panel())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	right.add_child(_build_battlefield())
	right.add_child(_build_hand_strip())
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 240)
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	bottom.add_child(_build_chart_panel())
	bottom.add_child(_build_news_panel())



## anchors·offsets = (left, top, right, bottom)
func _place(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _panel(padding := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", WarStyle.box(Color(WarStyle.PANEL, 0.55), Color(0, 0, 0, 0), 10, 0, padding))
	return panel


func _build_top_bar() -> Control:
	var panel := _panel(8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var back := Button.new()
	back.text = "< 로비"
	WarStyle.paint_button(back, WarStyle.ACCENT, false, 15)
	back.pressed.connect(_confirm_exit)
	row.add_child(back)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.add_child(WarStyle.label(_company.name, 22, Color.WHITE, true))
	names.add_child(WarStyle.label("%s · 나: %s" % [_company.sector, War.label(_faction)], 13, WarStyle.of(_faction)))
	row.add_child(names)

	_clock_label = WarStyle.label("09:00", 26, Color.WHITE, true)
	row.add_child(_clock_label)

	var price_box := VBoxContainer.new()
	price_box.add_theme_constant_override("separation", 0)
	_price_label = WarStyle.label("", 30, Color.WHITE, true)
	_change_label = WarStyle.label("", 14)
	price_box.add_child(_price_label)
	price_box.add_child(_change_label)
	row.add_child(price_box)

	var gauge_box := VBoxContainer.new()
	gauge_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauge_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var gauge_labels := HBoxContainer.new()
	_buy_label = WarStyle.label("", 14, WarStyle.BULL, true)
	_strength_label = WarStyle.label("", 13, WarStyle.MUTED)
	_strength_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strength_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_label = WarStyle.label("", 14, WarStyle.BEAR, true)
	gauge_labels.add_child(_buy_label)
	gauge_labels.add_child(_strength_label)
	gauge_labels.add_child(_sell_label)
	gauge_box.add_child(gauge_labels)
	_gauge = TugGauge.new()
	_gauge.custom_minimum_size = Vector2(0, 12)
	gauge_box.add_child(_gauge)
	row.add_child(gauge_box)

	_pause_button = Button.new()
	WarStyle.paint_button(_pause_button, WarStyle.ACCENT, false, 15)
	_pause_button.pressed.connect(_toggle_pause)
	row.add_child(_pause_button)
	_speed_button = Button.new()
	WarStyle.paint_button(_speed_button, WarStyle.ACCENT, true, 15)
	_speed_button.pressed.connect(_toggle_speed)
	row.add_child(_speed_button)
	return panel


func _build_book_panel() -> Control:
	var panel := _panel(8)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_child(WarStyle.label("호가창", 17, Color.WHITE, true))
	var hint := WarStyle.label("칸을 누르면 그 가격에 주문", 12, WarStyle.MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hint)
	box.add_child(header)
	_book_view = OrderBookView.new()
	_book_view.engine = engine
	_book_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book_view.price_clicked.connect(func(price: int) -> void: _act(engine.place_wall(_fraction, price)))
	box.add_child(_book_view)
	return panel


func _build_account_panel() -> Control:
	var panel := _panel(10)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	panel.add_child(grid)
	var title := WarStyle.label("평가손익", 13, WarStyle.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(title)
	_pnl_rate_label = WarStyle.label("", 15, Color.WHITE, true)
	_pnl_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(_pnl_rate_label)
	_pnl_label = WarStyle.label("", 24, Color.WHITE, true)
	grid.add_child(_pnl_label)
	_position_label = WarStyle.label("", 13, WarStyle.MUTED)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(_position_label)
	_record_label = WarStyle.label("", 12, WarStyle.MUTED)
	grid.add_child(_record_label)
	return panel


func _build_action_panel() -> Control:
	var panel := _panel(10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var color := WarStyle.of(_faction)

	var fractions := HBoxContainer.new()
	fractions.add_theme_constant_override("separation", 6)
	fractions.add_child(WarStyle.label("수량", 14, WarStyle.MUTED))
	for i in FRACTIONS.size():
		var fraction: float = FRACTIONS[i]
		var button := Button.new()
		button.text = "%d%%" % roundi(fraction * 100)
		button.custom_minimum_size = Vector2(54, 30)
		button.pressed.connect(_set_fraction.bind(fraction))
		fractions.add_child(button)
		_fraction_buttons.append(button)
	_available_label = WarStyle.label("", 13, WarStyle.MUTED)
	_available_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fractions.add_child(_available_label)
	box.add_child(fractions)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 8)
	_attack_button = Button.new()
	_attack_button.text = "돌격 · 시장가 %s  (A)" % ("매수" if _faction == War.Faction.BULL else "매도")
	_attack_button.custom_minimum_size = Vector2(0, 48)
	_attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_button.size_flags_stretch_ratio = 1.6
	WarStyle.paint_button(_attack_button, color, false, 19)
	_attack_button.pressed.connect(func() -> void: _act(engine.attack(_fraction)))
	main_row.add_child(_attack_button)
	_wall_button = Button.new()
	_wall_button.text = "벽 쌓기  (S)"
	_wall_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(_wall_button, color, true, 17)
	_wall_button.pressed.connect(func() -> void: _act(engine.place_wall(_fraction)))
	main_row.add_child(_wall_button)
	box.add_child(main_row)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	_close_button = Button.new()
	_close_button.text = "포지션 정리  (D)"
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.custom_minimum_size = Vector2(0, 36)
	WarStyle.paint_button(_close_button, WarStyle.ACCENT, false, 15)
	_close_button.pressed.connect(func() -> void: _act(engine.close_position()))
	sub_row.add_child(_close_button)
	_cancel_button = Button.new()
	_cancel_button.text = "주문 취소  (F)"
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(_cancel_button, WarStyle.ACCENT, false, 15)
	_cancel_button.pressed.connect(func() -> void: _act(engine.cancel_orders()))
	sub_row.add_child(_cancel_button)
	box.add_child(sub_row)
	return panel


func _build_battlefield() -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", WarStyle.box(Color("#06142a"), Color(WarStyle.ACCENT, 0.8), 10, 1, 0))
	frame.clip_contents = true
	_battlefield = Battlefield.new()
	_battlefield.engine = engine
	frame.add_child(_battlefield)
	return frame


## 스킬 카드 손패: 전장 바로 아래 한 줄.
func _build_hand_strip() -> Control:
	var panel := _panel(8)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := VBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_child(WarStyle.label("스킬 카드", 15, Color.WHITE, true))
	title.add_child(WarStyle.label("Q · W · E", 12, WarStyle.GOLD))
	row.add_child(title)
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 8)
	_hand_box.custom_minimum_size = Vector2(0, 58)
	_hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_hand_box)
	# 방금 한 행동의 결과가 오른쪽에 잠깐 뜬다.
	_toast = WarStyle.label("", 17, Color.WHITE, true)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toast.modulate.a = 0.0
	row.add_child(_toast)
	return panel


func _build_chart_panel() -> Control:
	var panel := _panel(8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	_chart = CandleChart.new()
	_chart.engine = engine
	panel.add_child(_chart)
	return panel


func _build_news_panel() -> Control:
	var panel := _panel(10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(WarStyle.label("전장 소식 · 뉴스 · 공시", 15, Color.WHITE, true))
	_news = RichTextLabel.new()
	_news.bbcode_enabled = true
	_news.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_news.add_theme_font_size_override("normal_font_size", 14)
	_news.add_theme_font_size_override("bold_font_size", 14)
	box.add_child(_news)
	return panel


# ── 갱신 ────────────────────────────────────────────────────────

func _refresh() -> void:
	var e := engine
	var price_color := WarStyle.for_price(e.last_price, e.base_price)
	_clock_label.text = e.clock()
	_price_label.text = Krx.format_number(e.last_price)
	_price_label.add_theme_color_override("font_color", price_color)
	var arrow := "▲ " if e.last_price > e.base_price else "▼ " if e.last_price < e.base_price else ""
	_change_label.text = arrow + Krx.signed_percent(e.change_rate())
	_change_label.add_theme_color_override("font_color", price_color)

	var buy := roundi(e.buy_share() * 100)
	_gauge.share = e.buy_share()
	_gauge.queue_redraw()
	_buy_label.text = "매수세 %d" % buy
	_sell_label.text = "%d 매도세" % (100 - buy)
	if e.in_vi():
		_strength_label.text = "VI 발동 · 단일가 %d분" % e.vi_remaining
		_strength_label.add_theme_color_override("font_color", WarStyle.WARNING)
	else:
		_strength_label.text = "체결강도 %d%%" % roundi(e.trade_strength())
		_strength_label.add_theme_color_override("font_color", WarStyle.MUTED)
	_pause_button.text = "계속  (Space)" if _paused else "일시정지  (Space)"
	_speed_button.text = "2배속" if _fast else "1배속"

	var pnl := e.pnl()
	_pnl_label.text = Krx.signed_number(pnl) + "원"
	_pnl_label.add_theme_color_override("font_color", WarStyle.for_sign(pnl))
	_pnl_rate_label.text = Krx.signed_percent(float(pnl) / e.starting_cash)
	_pnl_rate_label.add_theme_color_override("font_color", WarStyle.for_sign(pnl))
	var holding := e.account.position
	if holding == 0:
		_position_label.text = "포지션 없음"
	else:
		_position_label.text = "%s %s주 · 평단 %s" % ["보유" if holding > 0 else "공매도",
			Krx.format_number(absi(holding)), Krx.format_number(e.account.average_price)]
	_record_label.text = "돌격 %s · 방어 %s · 스킬 %d회" % [
		Krx.compact_won(e.attack_value), Krx.compact_won(e.defense_value), e.skills_used]

	var side := War.attack_side(_faction)
	var reference := e.book.best(OrderBook.opposite(side))
	if reference == OrderBook.NO_PRICE:
		reference = e.last_price
	_available_label.text = "%s주" % Krx.format_number(floori(e.max_quantity(side, reference) * _fraction))
	for i in _fraction_buttons.size():
		var selected := is_equal_approx(FRACTIONS[i], _fraction)
		WarStyle.paint_button(_fraction_buttons[i], WarStyle.of(_faction) if selected else WarStyle.ACCENT, not selected, 14)
	var market_blocked := e.in_vi() or e.is_over()
	_attack_button.disabled = market_blocked
	_close_button.disabled = market_blocked
	_wall_button.disabled = e.is_over()
	_cancel_button.disabled = e.is_over()

	_refresh_hand()
	_refresh_news()
	_book_view.queue_redraw()
	_chart.queue_redraw()
	_battlefield.sync()


func _refresh_hand() -> void:
	var signature := ""
	for card: BattleEngine.SkillCard in engine.hand:
		signature += "%s:%d|" % [card.skill.name, card.expires_at - engine.tick]
	signature += "vi" if engine.in_vi() else ""
	if signature == _hand_signature:
		return
	_hand_signature = signature
	for child in _hand_box.get_children():
		child.queue_free()
	if engine.hand.is_empty():
		var empty := WarStyle.label("차트 패턴이 완성되면 여기에 스킬 카드가 생긴다. 적 패턴은 3분 뒤 자동으로 날아온다.", 13, WarStyle.MUTED)
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hand_box.add_child(empty)
	for i in engine.hand.size():
		var card: BattleEngine.SkillCard = engine.hand[i]
		var skill := card.skill
		var button := Button.new()
		button.custom_minimum_size = Vector2(250, 58)
		button.text = "%s\n%s %s · %d분 남음" % [skill.name, ChartPatterns.label(skill.pattern), "★".repeat(skill.tier()), card.expires_at - engine.tick]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = skill.description
		WarStyle.paint_card(button, WarStyle.of(skill.faction()))
		button.disabled = engine.in_vi()
		button.pressed.connect(func() -> void: _act(engine.use_skill(i)))
		var key := WarStyle.label(SKILL_KEYS[i], 20, WarStyle.GOLD, true)
		_place(key, Vector4(1, 0, 1, 0), Vector4(-30, 4, -8, 30))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key)
		_hand_box.add_child(button)


func _refresh_news() -> void:
	if engine.feed_serial == _news_serial:
		return
	_news_serial = engine.feed_serial
	var lines := PackedStringArray()
	for item: BattleEngine.FeedItem in engine.feed.slice(0, 40):
		var color := Color.WHITE
		if item.kind == BattleEngine.FeedKind.WARNING:
			color = WarStyle.WARNING
		elif item.tone != War.NEUTRAL:
			color = WarStyle.of(item.tone)
		elif item.kind == BattleEngine.FeedKind.SYSTEM:
			color = WarStyle.MUTED
		var line := "[color=#%s]%s[/color]  " % [WarStyle.hex(WarStyle.MUTED), item.time]
		if not item.label.is_empty():
			line += "[color=#%s][b][lb]%s][/b][/color] " % [WarStyle.hex(color), item.label]
			line += _escape(item.title)
		else:
			line += "[color=#%s]%s[/color]" % [WarStyle.hex(color), _escape(item.title)]
		if not item.detail.is_empty():
			line += "\n[color=#%s][font_size=12]      %s[/font_size][/color]" % [WarStyle.hex(WarStyle.MUTED), _escape(item.detail)]
		lines.append(line)
	_news.text = "\n".join(lines)


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


# ── 행동 ────────────────────────────────────────────────────────

func _act(result: BattleEngine.ActionResult) -> void:
	_refresh()
	_show_toast(result.message, result.ok)


func _show_toast(message: String, ok: bool) -> void:
	_toast.text = message
	_toast.add_theme_color_override("font_color", Color.WHITE if ok else WarStyle.WARNING)
	_toast_time = 1.8
	_toast.modulate.a = 1.0


func _set_fraction(fraction: float) -> void:
	_fraction = fraction
	_refresh()


func _toggle_pause() -> void:
	if engine.is_over():
		return
	_paused = not _paused
	_refresh()


func _toggle_speed() -> void:
	_fast = not _fast
	_refresh()


# ── 결과·이탈 창 ─────────────────────────────────────────────────

func _open_overlay() -> VBoxContainer:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", WarStyle.box(WarStyle.PANEL, WarStyle.ACCENT, 14, 2, 28))
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _confirm_exit() -> void:
	if engine.is_over():
		exit_requested.emit()
		return
	var box := _open_overlay()
	var title := WarStyle.label("전장을 떠날까요?", 26, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := WarStyle.label("진행 중인 전투는 기록되지 않습니다.", 15, WarStyle.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var stay := Button.new()
	stay.text = "계속 싸우기"
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(stay, WarStyle.ACCENT, false, 17)
	stay.pressed.connect(_close_overlay)
	var leave := Button.new()
	leave.text = "떠나기"
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(leave, WarStyle.MUTED, true, 17)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	row.add_child(stay)
	row.add_child(leave)
	box.add_child(row)


func _show_result() -> void:
	_close_overlay()
	var r := engine.result
	var box := _open_overlay()
	var title_text := "무승부"
	if r.winner != War.NEUTRAL:
		title_text = "승리" if r.victory() else "패배"
	var title := WarStyle.label(title_text, 44, WarStyle.of(r.winner), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var reason := WarStyle.label(r.reason, 15, WarStyle.MUTED)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reason)
	var grade := WarStyle.label(r.grade(), 48, WarStyle.GOLD, true)
	grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade.add_theme_stylebox_override("normal", WarStyle.box(Color(0, 0, 0, 0.25), WarStyle.GOLD, 40, 2, 6))
	var grade_row := CenterContainer.new()
	grade.custom_minimum_size = Vector2(90, 90)
	grade.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_row.add_child(grade)
	box.add_child(grade_row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	box.add_child(grid)
	_stat(grid, "종가", "%s (%s)" % [Krx.format_number(r.close_price), Krx.signed_percent(r.price_change())],
		WarStyle.for_price(r.close_price, r.base_price))
	_stat(grid, "내 손익", "%s원 (%s)" % [Krx.signed_number(r.pnl), Krx.signed_percent(r.return_rate())], WarStyle.for_sign(r.pnl))
	_stat(grid, "돌격 체결", Krx.compact_won(r.attack_value), Color.WHITE)
	_stat(grid, "방어 체결", Krx.compact_won(r.defense_value), Color.WHITE)
	_stat(grid, "스킬", "%d회 · +%d호가" % [r.skills_used, r.skill_ticks], Color.WHITE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lobby := Button.new()
	lobby.text = "로비로"
	lobby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(lobby, WarStyle.MUTED, true, 17)
	lobby.pressed.connect(func() -> void: exit_requested.emit())
	var again := Button.new()
	again.text = "다시 싸우기"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 44)
	WarStyle.paint_button(again, WarStyle.of(_faction), false, 17)
	again.pressed.connect(func() -> void: rematch_requested.emit())
	row.add_child(lobby)
	row.add_child(again)
	box.add_child(row)


func _stat(grid: GridContainer, title: String, value: String, color: Color) -> void:
	grid.add_child(WarStyle.label(title, 15, WarStyle.MUTED))
	var label := WarStyle.label(value, 17, color, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)

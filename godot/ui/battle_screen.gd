class_name BattleScreen
extends Control
## 전투 화면. HTS 바탕 위에 창 여섯 개.
##   [0101] 현재가·호가 (호가표 + 탑)   [0305] 스킬 카드
##   [0301] 주문   [0600] 차트           [0700] 뉴스·공시   [0800] 종목토론

signal exit_requested
signal rematch_requested

## 장중 1분 = 0.5초, 동시호가 1분 = 1초.
const MINUTE := 0.5
const AUCTION_MINUTE := 1.0

var engine: BattleEngine
var sfx: Sfx

var _company: Company
var _paused := false
var _fast := false
var _accum := 0.0
var _desktop: Desktop
var _ticker: Ticker
var _tower: BookTower
var _chart: MiniChart
var _news: TextList
var _chat: TextList
var _orders: OrderPanel
var _skills: SkillPanel
var _overlay: Control
var _overlay_kind := ""
var _news_serial := -1
var _chat_serial := -1
var _message_time := 0.0
var _last_phase := -1
var _kospi := 2641.2
var _kospi_base := 2641.2
var _kosdaq := 781.4
var _kosdaq_base := 781.4


func _init(company: Company, faction: int, seed_value := -1, p_sfx: Sfx = null) -> void:
	_company = company
	sfx = p_sfx
	engine = BattleEngine.new(company, faction, seed_value)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop = Desktop.new()
	_desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop.hint = "F1 도움말 · Space 멈춤 · X 배속 · M 소리"
	add_child(_desktop)
	_ticker = Ticker.new()
	_place(_ticker, Rect2(0, 13, 800, 12))

	_tower = BookTower.new()
	_tower.engine = engine
	_tower.sfx = sfx
	_tower.price_clicked.connect(func(price: int) -> void: _act(engine.place_wall(_orders.fraction, price)))
	_window("[0101] 현재가·호가  %s" % _company.name, _tower, Rect2(2, 26, 582, 298))

	_orders = OrderPanel.new()
	_orders.engine = engine
	_orders.acted.connect(_act)
	_window("[0301] 주문 · 나는 %s" % War.label(engine.faction), _orders, Rect2(2, 326, 222, 110))

	_chart = MiniChart.new()
	_chart.engine = engine
	_window("[0600] 차트 · 5분", _chart, Rect2(226, 326, 358, 110))

	_skills = SkillPanel.new()
	_skills.engine = engine
	_skills.use_requested.connect(func(index: int) -> void: _act(engine.use_skill(index)))
	_window("[0305] 스킬 카드", _skills, Rect2(586, 26, 212, 69))

	_news = TextList.new()
	_window("[0700] 뉴스·공시", _news, Rect2(586, 97, 212, 148))

	_chat = TextList.new()
	_chat.newest_first = false
	_window("[0800] 종목토론 · %s" % _company.name, _chat, Rect2(586, 247, 212, 189))
	_refresh()


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	add_child(control)


func _window(title: String, content: Control, rect: Rect2) -> HtsWindow:
	var window := HtsWindow.new(title, content)
	_place(window, rect)
	return window


func _process(delta: float) -> void:
	if _message_time > 0:
		_message_time -= delta
		if _message_time <= 0:
			_desktop.message = ""
			_desktop.queue_redraw()
	if _paused or engine.is_over() or _overlay != null:
		return
	_accum += delta * (2.0 if _fast else 1.0)
	var minute := AUCTION_MINUTE if engine.in_auction() else MINUTE
	if _accum >= minute:
		_accum -= minute
		advance(1)


## n분 진행한다 (테스트·자동 진행용으로도 쓴다).
func advance(minutes: int) -> void:
	for i in minutes:
		if engine.is_over():
			break
		engine.step()
		_drift_indices()
	_refresh()
	if engine.is_over() and _overlay_kind != "result":
		_show_result()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	if _overlay != null:
		match key.keycode:
			KEY_ESCAPE, KEY_F1:
				if _overlay_kind == "result":
					exit_requested.emit()
				else:
					_close_overlay()
			KEY_ENTER, KEY_KP_ENTER:
				if _overlay_kind == "result":
					rematch_requested.emit()
				elif _overlay_kind == "confirm":
					exit_requested.emit()
			_:
				handled = false
	else:
		match key.keycode:
			KEY_A:
				_act(engine.attack(_orders.fraction))
			KEY_S:
				_act(engine.place_wall(_orders.fraction))
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
				_orders.set_fraction(OrderPanel.FRACTIONS[key.keycode - KEY_1])
				_refresh()
			KEY_SPACE:
				_paused = not _paused
				_refresh()
			KEY_X:
				_fast = not _fast
				_refresh()
			KEY_M:
				if sfx != null:
					sfx.muted = not sfx.muted
					_say("소리 %s" % ("끔" if sfx.muted else "켬"), true)
			KEY_F1:
				_show_help()
			KEY_ESCAPE:
				_confirm_exit()
			_:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()


# ── 갱신 ────────────────────────────────────────────────────────

func _refresh() -> void:
	var e := engine
	if e.phase != _last_phase:
		if e.phase == BattleEngine.Phase.VI and sfx != null:
			sfx.play("vi")
		_last_phase = e.phase
	_tower.sync()
	_orders.refresh()
	_skills.queue_redraw()
	_chart.queue_redraw()
	if e.feed_serial != _news_serial:
		_news_serial = e.feed_serial
		_news.set_entries(_news_entries())
	if e.chatter.serial != _chat_serial:
		_chat_serial = e.chatter.serial
		_chat.set_entries(_chat_entries())
	var state := e.phase_label()
	if e.in_auction():
		state += " %d분" % e.auction_remaining()
	if _paused:
		state += " · 멈춤"
	if _fast:
		state += " · 2배속"
	_desktop.right_text = "%s   %s" % [state, e.clock()]
	_desktop.right_color = Hts.WARN if e.in_auction() or _paused else Hts.INK
	_desktop.queue_redraw()
	_ticker.text = _ticker_text()


func _news_entries() -> Array:
	var list := []
	for item: BattleEngine.FeedItem in engine.feed.slice(0, 24):
		var color := Hts.SUB
		if item.kind == BattleEngine.FeedKind.WARNING:
			color = Hts.WARN
		elif item.tone != War.NEUTRAL:
			color = Hts.side_color(item.tone)
		var pieces := [[item.time + " ", Hts.SUB]]
		if not item.label.is_empty():
			pieces.append(["[%s] " % item.label, color, true])
		pieces.append([item.title, Hts.INK])
		if not item.detail.is_empty() and item.kind != BattleEngine.FeedKind.SYSTEM:
			pieces.append([" " + item.detail, Hts.SUB])
		list.append(pieces)
	return list


func _chat_entries() -> Array:
	var list := []
	for line: Chatter.Line in engine.chatter.lines.slice(0, 20):
		list.append([[line.nick + " ", Color("#2a5aa0"), true], [line.text, Hts.INK]])
	return list


func _ticker_text() -> String:
	var parts := PackedStringArray()
	parts.append("코스피 %.2f %s%.2f%%" % [_kospi, Hts.arrow(_kospi - _kospi_base), absf(_kospi / _kospi_base - 1.0) * 100.0])
	parts.append("코스닥 %.2f %s%.2f%%" % [_kosdaq, Hts.arrow(_kosdaq - _kosdaq_base), absf(_kosdaq / _kosdaq_base - 1.0) * 100.0])
	var change := engine.reference_price() - engine.base_price
	parts.append("%s %s %s%s" % [_company.name, Krx.format_number(engine.reference_price()), Hts.arrow(change), Krx.signed_percent(float(change) / engine.base_price)])
	var count := 0
	for item: BattleEngine.FeedItem in engine.feed:
		if item.kind == BattleEngine.FeedKind.NEWS:
			parts.append("[%s] %s" % [item.label, item.title])
			count += 1
			if count == 3:
				break
	return "      ".join(parts)


## 지수는 분위기만 낸다: 이 종목 심리를 조금 따라 흔들린다.
func _drift_indices() -> void:
	var push := engine.sentiment * 0.00025
	_kospi *= 1.0 + push + randf_range(-0.0003, 0.0003)
	_kosdaq *= 1.0 + push * 1.4 + randf_range(-0.0005, 0.0005)


# ── 행동 ────────────────────────────────────────────────────────

func _act(result: BattleEngine.ActionResult) -> void:
	_refresh()
	_say(result.message, result.ok)
	if sfx != null and result.ok:
		sfx.play("click", -14.0)


func _say(message: String, ok: bool) -> void:
	_desktop.message = message
	_desktop.message_color = Hts.INK if ok else Hts.UP
	_message_time = 4.0
	_desktop.queue_redraw()


# ── 창 띄우기 ───────────────────────────────────────────────────

func _open_dialog(kind: String, title: String, content: Control, box: Vector2) -> HtsWindow:
	_close_overlay()
	_overlay_kind = kind
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0, 0, 0, 0.35)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var window := HtsWindow.new(title, content)
	window.position = ((Vector2(800, 450) - box) * 0.5).round()
	window.size = box
	_overlay.add_child(window)
	return window


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_overlay_kind = ""


func _show_help() -> void:
	_open_dialog("help", "[0999] 도움말 · 닫기 F1", Help.new(), Vector2(600, 286))


func _confirm_exit() -> void:
	if engine.is_over():
		exit_requested.emit()
		return
	var body := ConfirmView.new()
	_open_dialog("confirm", "[0000] 확인", body, Vector2(300, 90))
	var stay := Hts.button("계속 (Esc)")
	stay.position = Vector2(60, 42)
	stay.size = Vector2(80, 18)
	stay.pressed.connect(_close_overlay)
	body.add_child(stay)
	var leave := Hts.button("나가기 (Enter)")
	leave.position = Vector2(146, 42)
	leave.size = Vector2(90, 18)
	leave.pressed.connect(func() -> void: exit_requested.emit())
	body.add_child(leave)


func _show_result() -> void:
	var r := engine.result
	Record.add(r, _company.name)
	var view := ResultView.new()
	view.result = r
	view.company = _company
	_open_dialog("result", "[0345] 당일 결산", view, Vector2(330, 214))
	var again := Hts.button("한 판 더 (Enter)")
	again.position = Vector2(92, 170)
	again.size = Vector2(110, 18)
	again.pressed.connect(func() -> void: rematch_requested.emit())
	view.add_child(again)
	var lobby := Hts.button("관심종목 (Esc)")
	lobby.position = Vector2(208, 170)
	lobby.size = Vector2(110, 18)
	lobby.pressed.connect(func() -> void: exit_requested.emit())
	view.add_child(lobby)


class ConfirmView:
	extends Control

	func _draw() -> void:
		Hts.text(self, Vector2(8, 6), "이번 판을 그만두고 관심종목으로 나갈까?", Hts.INK)
		Hts.text(self, Vector2(8, 20), "전적에는 남지 않는다.", Hts.SUB)


## 결산표와 도장.
class ResultView:
	extends Control
	var result: BattleEngine.BattleResult
	var company: Company

	func _draw() -> void:
		var r := result
		Hts.well(self, Rect2(0, 0, size.x, 164))
		# 도장: 이겼으면 빨간 승, 졌으면 파란 패
		var stamp := "무"
		var ink := Hts.SHADOW
		if r.winner != War.NEUTRAL:
			stamp = "승" if r.victory() else "패"
			ink = Hts.UP if r.victory() else Hts.DOWN
		var center := Vector2(size.x - 50, 52)
		draw_circle(center, 34, Color(ink, 0.12))
		draw_arc(center, 34, 0, TAU, 48, ink, 2.0)
		draw_arc(center, 29, 0, TAU, 48, ink, 1.0)
		Hts.text(self, center - Vector2(18, 20), stamp, ink, 36)
		Hts.text(self, Vector2(size.x - 100, 92), "등급 %s" % r.grade(), ink, 12, true, HORIZONTAL_ALIGNMENT_CENTER, 100)
		var rows := [
			["종목", "%s (나는 %s)" % [company.name, War.label(r.player_faction)], Hts.INK],
			["결과", r.reason, Hts.INK],
			["시가 → 종가", "%s → %s" % [Krx.format_number(r.open_price), Krx.format_number(r.close_price)], Hts.price_color(r.close_price, r.base_price)],
			["기준가 대비", Krx.signed_percent(r.price_change()), Hts.sign_color(r.price_change())],
			["내 손익", "%s원" % Krx.signed_number(r.pnl), Hts.sign_color(r.pnl)],
			["수익률", Krx.signed_percent(r.return_rate()), Hts.sign_color(r.pnl)],
			["돌격 · 방어 체결", "%s · %s" % [Krx.compact_won(r.attack_value), Krx.compact_won(r.defense_value)], Hts.INK],
			["스킬", "%d번 · %d호가 밀어냄" % [r.skills_used, r.skill_ticks], Hts.INK],
		]
		var y := 4.0
		for row: Array in rows:
			Hts.text(self, Vector2(6, y), row[0], Hts.SUB)
			Hts.text(self, Vector2(100, y), row[1], row[2], 12, false)
			y += 19

class_name OrderPanel
extends Control
## [0301] 주문. 잔고 두 줄, 수량 비율, 버튼 넷 (시장가 돌격, 지정가 벽, 정리, 취소).

signal acted(result: BattleEngine.ActionResult)

const FRACTIONS := [0.1, 0.25, 0.5, 1.0]

var engine: BattleEngine
var fraction := 0.25
var _fraction_buttons: Array[Button] = []
var _attack: Button
var _wall: Button
var _close: Button
var _cancel: Button


func _ready() -> void:
	var bull := engine.faction == War.Faction.BULL
	var face := Color("#e8b4b4") if bull else Color("#b4c4e8")
	var ink := Hts.UP.darkened(0.3) if bull else Hts.DOWN.darkened(0.3)
	for i in FRACTIONS.size():
		var b := Hts.button("%d%%" % roundi(FRACTIONS[i] * 100))
		b.position = Vector2(i * 35, 29)
		b.size = Vector2(33, 15)
		b.pressed.connect(set_fraction.bind(FRACTIONS[i]))
		add_child(b)
		_fraction_buttons.append(b)
	_attack = _add("시장가 %s  A" % ("매수" if bull else "매도"), Rect2(0, 47, 107, 17), face, ink,
		func() -> BattleEngine.ActionResult: return engine.attack(fraction))
	_wall = _add("지정가 벽  S", Rect2(109, 47, 107, 17), Hts.FACE, ink,
		func() -> BattleEngine.ActionResult: return engine.place_wall(fraction))
	_close = _add("포지션 정리  D", Rect2(0, 66, 107, 17), Hts.FACE, Hts.INK,
		func() -> BattleEngine.ActionResult: return engine.close_position())
	_cancel = _add("미체결 취소  F", Rect2(109, 66, 107, 17), Hts.FACE, Hts.INK,
		func() -> BattleEngine.ActionResult: return engine.cancel_orders())
	refresh()


func _add(label: String, rect: Rect2, face: Color, ink: Color, action: Callable) -> Button:
	var b := Hts.button(label, face, ink)
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(func() -> void: acted.emit(action.call()))
	add_child(b)
	return b


func set_fraction(value: float) -> void:
	fraction = value
	refresh()


func refresh() -> void:
	for i in _fraction_buttons.size():
		var on := is_equal_approx(FRACTIONS[i], fraction)
		Hts.paint_button(_fraction_buttons[i], Hts.SELECT if on else Hts.FACE, Hts.LIGHT if on else Hts.INK)
	var over := engine.is_over()
	for b in [_attack, _wall, _close, _cancel]:
		b.disabled = over
	queue_redraw()


func _draw() -> void:
	var e := engine
	var holding := e.account.position
	if holding == 0:
		Hts.text(self, Vector2(0, -1), "보유 없음", Hts.SUB)
	else:
		Hts.text(self, Vector2(0, -1), "%s %s주 · 평단 %s" % ["보유" if holding > 0 else "공매도",
			Krx.format_number(absi(holding)), Krx.format_number(e.account.average_price)], Hts.INK)
	var pnl := e.pnl()
	var color := Hts.sign_color(pnl)
	Hts.text(self, Vector2(0, 12), "평가손익 %s  %s" % [Krx.signed_number(pnl), Krx.signed_percent(float(pnl) / e.starting_cash)], color, 12, true)
	var side := War.attack_side(e.faction)
	var qty := floori(e.max_quantity(side, e.attack_reference(side)) * fraction)
	Hts.text(self, Vector2(142, 28), "%s주" % Krx.format_number(qty), Hts.SUB, 12, false, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 142)

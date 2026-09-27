class_name Lobby
extends Control
## 첫 화면. [0130] 관심종목에서 종목을 고르고, [0301]에서 사자·팔자 중 한쪽에 선다.

signal join_requested(company: Company, faction: int)

## 종목마다 붙는 한 줄 메모 (분위기만).
const MEMOS := ["실적 발표 주간", "기술이전 소문", "무증 기대감", "수주 공시 대기", "정책 수혜 거론"]

var sfx: Sfx
var _companies: Array = []
var _selected := 0
var _desktop: Desktop
var _list: Control
var _pick: Control
var _overlay: Control


func _init(start: Company = null) -> void:
	_companies = Company.roster()
	_selected = randi() % _companies.size()
	if start != null:
		for i in _companies.size():
			if _companies[i].name == start.name:
				_selected = i


func selected_company() -> Company:
	return _companies[_selected]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop = Desktop.new()
	_desktop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop.right_text = "장 시작 전   08:50"
	_desktop.message = "종목을 고르고 사자나 팔자에 선다. 판은 08:50 장전 동시호가부터 시작한다."
	_desktop.hint = "F1 도움말 · Enter 사자 · Shift+Enter 팔자"
	add_child(_desktop)
	var title := TitleArt.new()
	_place(title, Rect2(14, 18, 460, 56))

	_list = WatchList.new()
	_list.lobby = self
	_window("[0130] 관심종목", _list, Rect2(14, 78, 480, 132))

	_pick = PickPanel.new()
	_pick.lobby = self
	_window("[0301] 주문 · 편 고르기", _pick, Rect2(500, 78, 286, 202))

	var record := RecordView.new()
	_window("[0350] 전적", record, Rect2(14, 214, 480, 118))

	var how := HowView.new()
	_window("[0900] 한 판", how, Rect2(14, 336, 772, 98))


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	add_child(control)


func _window(title: String, content: Control, rect: Rect2) -> HtsWindow:
	var window := HtsWindow.new(title, content)
	_place(window, rect)
	return window


func select(index: int) -> void:
	_selected = clampi(index, 0, _companies.size() - 1)
	_list.queue_redraw()
	_pick.queue_redraw()


func join(faction: int) -> void:
	join_requested.emit(selected_company(), faction)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	if _overlay != null:
		if key.keycode == KEY_F1 or key.keycode == KEY_ESCAPE:
			_overlay.queue_free()
			_overlay = null
		else:
			handled = false
	else:
		match key.keycode:
			KEY_UP:
				select(_selected - 1)
			KEY_DOWN:
				select(_selected + 1)
			KEY_ENTER, KEY_KP_ENTER:
				join(War.Faction.BEAR if key.shift_pressed else War.Faction.BULL)
			KEY_F1:
				_overlay = ColorRect.new()
				(_overlay as ColorRect).color = Color(0, 0, 0, 0.35)
				_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				add_child(_overlay)
				var window := HtsWindow.new("[0999] 도움말 · 닫기 F1", Help.new())
				window.position = Vector2(100, 82)
				window.size = Vector2(600, 286)
				_overlay.add_child(window)
			_:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()


## 바탕화면에 크게 박힌 제목.
class TitleArt:
	extends Control

	func _draw() -> void:
		Hts.text(self, Vector2(3, 3), "호가전쟁", Color("#1b2430"), 36)
		Hts.text(self, Vector2(0, 0), "호가전쟁", Hts.LIGHT, 36)
		Hts.text(self, Vector2(172, 10), "사자와 팔자의 하루", Color("#c9d4e2"), 12)
		Hts.text(self, Vector2(172, 25), "모두증권 HTS에서 벌어지는 전쟁", Color("#93a4b8"), 12)


## 관심종목 표.
class WatchList:
	extends Control
	var lobby: Lobby
	const COLS := [4, 96, 190, 246, 304, 362]

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var row := int((click.position.y - 15) / 16)
			if row >= 0 and row < lobby._companies.size():
				lobby.select(row)
				if click.double_click:
					lobby.join(War.Faction.BULL)
			accept_event()

	func _draw() -> void:
		Hts.well(self, Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(1, 1, size.x - 2, 13), Hts.FACE)
		var heads := ["종목명", "업종", "기준가", "상한가", "하한가", "메모"]
		for i in heads.size():
			Hts.text(self, Vector2(COLS[i], 0), heads[i], Hts.INK)
		for i in lobby._companies.size():
			var c: Company = lobby._companies[i]
			var y := 15 + i * 16
			var selected := i == lobby._selected
			if selected:
				draw_rect(Rect2(1, y, size.x - 2, 16), Hts.SELECT)
			var ink := Hts.LIGHT if selected else Hts.INK
			Hts.text(self, Vector2(COLS[0], y + 1), c.name, ink, 12, true)
			Hts.text(self, Vector2(COLS[1], y + 1), c.sector, ink if selected else Hts.SUB)
			Hts.text(self, Vector2(COLS[2], y + 1), Krx.format_number(c.base_price), ink)
			Hts.text(self, Vector2(COLS[3], y + 1), Krx.format_number(Krx.upper_limit(c.base_price)), ink if selected else Hts.UP)
			Hts.text(self, Vector2(COLS[4], y + 1), Krx.format_number(Krx.lower_limit(c.base_price)), ink if selected else Hts.DOWN)
			Hts.text(self, Vector2(COLS[5], y + 1), Lobby.MEMOS[i % Lobby.MEMOS.size()], ink if selected else Hts.SUB)
			draw_rect(Rect2(1, y + 15, size.x - 2, 1), Hts.GRID)


## 사자·팔자 고르기.
class PickPanel:
	extends Control
	var lobby: Lobby

	func _ready() -> void:
		var buy := Hts.button("사자 · 매수", Hts.UP, Hts.LIGHT)
		buy.position = Vector2(4, 52)
		buy.size = Vector2(134, 34)
		buy.name = "JoinBull"
		buy.pressed.connect(func() -> void: lobby.join(War.Faction.BULL))
		add_child(buy)
		var sell := Hts.button("팔자 · 매도", Hts.DOWN, Hts.LIGHT)
		sell.position = Vector2(144, 52)
		sell.size = Vector2(134, 34)
		sell.name = "JoinBear"
		sell.pressed.connect(func() -> void: lobby.join(War.Faction.BEAR))
		add_child(sell)

	func _draw() -> void:
		var c := lobby.selected_company()
		Hts.well(self, Rect2(0, 0, size.x, 46))
		Hts.text(self, Vector2(6, 2), c.name, Hts.INK, 24)
		Hts.text(self, Vector2(6, 29), "기준가 %s · 상 %s · 하 %s" % [Krx.format_number(c.base_price),
			Krx.format_number(Krx.upper_limit(c.base_price)), Krx.format_number(Krx.lower_limit(c.base_price))], Hts.SUB)
		var lines := [
			["사자는 종가를 기준가 위로 올리면 이긴다.", Hts.UP],
			["팔자는 종가를 기준가 아래로 누르면 이긴다.", Hts.DOWN],
			["밑천은 1억. 상·하한가를 10분 지켜도 끝난다.", Hts.INK],
			["편이 이겨도 내 계좌가 깨지면 등급은 낮다.", Hts.SUB],
		]
		var y := 92.0
		for line: Array in lines:
			Hts.text(self, Vector2(4, y), line[0], line[1])
			y += 15


## 지난 판들.
class RecordView:
	extends Control

	func _draw() -> void:
		Hts.well(self, Rect2(Vector2.ZERO, size))
		var data := Record.load_record()
		if data.plays == 0:
			Hts.text(self, Vector2(6, 4), "아직 한 판도 안 했다.", Hts.SUB)
			return
		Hts.text(self, Vector2(6, 2), "%d판 %d승 %d패 %d무 · 최고 수익률 %s" % [data.plays, data.wins, data.losses, data.draws,
			Krx.signed_percent(data.best)], Hts.INK, 12, true)
		var y := 20.0
		for game: Dictionary in data.history:
			var outcome: String = game.outcome
			var ink := Hts.UP if outcome == "승" else Hts.DOWN if outcome == "패" else Hts.SUB
			Hts.text(self, Vector2(6, y), outcome, ink, 12, true)
			Hts.text(self, Vector2(24, y), "%s · %s" % [game.company, game.side], Hts.INK)
			Hts.text(self, Vector2(160, y), Krx.signed_percent(game["return"]), Hts.sign_color(game["return"]))
			Hts.text(self, Vector2(230, y), "등급 %s" % game.grade, Hts.SUB)
			y += 15


## 한 판의 흐름 한눈에.
class HowView:
	extends Control
	const STEPS := [
		["08:50", "장전 동시호가", "주문을 모아 09:00 시가를 정한다"],
		["09:00", "장중", "시장가로 치고 지정가로 막는다. 10% 급변하면 VI"],
		["점심", "한산", "거래가 줄고 뉴스도 뜸하다"],
		["15:20", "장 마감 동시호가", "10분 동안 모인 주문이 종가를 정한다"],
		["15:30", "종가", "기준가 위면 사자, 아래면 팔자 승"],
	]

	func _draw() -> void:
		Hts.well(self, Rect2(Vector2.ZERO, size))
		var w := (size.x - 8) / STEPS.size()
		for i in STEPS.size():
			var x := 4 + i * w
			var step: Array = STEPS[i]
			Hts.text(self, Vector2(x + 2, 3), step[0], Hts.SELECT, 12, true)
			Hts.text(self, Vector2(x + 2, 18), step[1], Hts.INK, 12, true)
			var rest: String = step[2]
			var line := ""
			var y := 36.0
			for word in rest.split(" "):
				if Hts.text_width(line + word) > w - 12 and not line.is_empty():
					Hts.text(self, Vector2(x + 2, y), line, Hts.SUB)
					y += 14
					line = ""
				line += word + " "
			Hts.text(self, Vector2(x + 2, y), line, Hts.SUB)
			if i > 0:
				draw_rect(Rect2(x - 2, 4, 1, size.y - 8), Hts.GRID)

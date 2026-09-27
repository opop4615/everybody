class_name TitleScreen
extends Screen
## 타이틀과 시대 고르기.
## 덱빌딩 로그라이크 · 역사 시뮬레이션 · 금융 학습.

const ERAS := [
	{"year": "2020", "name": "팬데믹", "text": "코로나 공포의 3월과 마이너스 유가. 달러·금·원유 선물로 두 막을 버틴다.", "open": true,
		"items": ["미국달러 선물", "금 선물", "WTI 원유 선물"]},
	{"year": "2008", "name": "금융위기", "text": "리먼 파산, 원/달러 1,500원, 통화스와프 300억 달러.", "open": false, "items": []},
	{"year": "1997", "name": "외환위기", "text": "IMF 구제금융과 환율 두 배. 금 모으기 운동.", "open": false, "items": []},
	{"year": "2022", "name": "긴축", "text": "40년 만의 인플레이션과 자이언트 스텝.", "open": false, "items": []},
]


func _ready() -> void:
	background()
	var backdrop := Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.draw.connect(_draw_backdrop.bind(backdrop))
	add_child(backdrop)
	var title := Look.label("차트 던전", 76, Look.GOLD, "display")
	Look.place(title, 70, 70)
	add_child(title)
	var sub := Look.label("선물 트레이더가 되어 실제 역사의 시장을 버틴다", 20, Look.TEXT, "bold")
	Look.place(sub, 74, 170)
	add_child(sub)
	var pillars := Look.hbox(8)
	Look.place(pillars, 74, 210)
	pillars.add_child(Look.tag("덱빌딩 로그라이크", Look.UP_STRONG, Color.WHITE, 13))
	pillars.add_child(Look.tag("역사 시뮬레이션", Look.DOWN_STRONG, Color.WHITE, 13))
	pillars.add_child(Look.tag("금융 학습", Color("2f6b4f"), Color.WHITE, 13))
	add_child(pillars)
	var pitch := Look.wrap_label("카드로 주문을 내고, 장 마감을 누르면 그날의 실제 캔들이 움직인다. 이기면 카드와 성과급, 지면 나쁜 습관. 쓰고 겪은 개념은 투자 노트에 쌓이고, 판이 끝나도 남는다.", 14, Look.SOFT, 560)
	Look.place(pitch, 74, 246, 560, 0)
	add_child(pitch)
	var row := Look.hbox(16)
	Look.place(row, 70, 360)
	add_child(row)
	for era: Dictionary in ERAS:
		row.add_child(_era_card(era))
	var notes: Notes = app.notes
	var footer := Look.hbox(14)
	Look.place(footer, 70, 652)
	var codex := Look.button("투자 노트 %d/%d" % [notes.known_count(), NoteDB.total()], "plain", 14, "N")
	codex.add_theme_color_override("font_color", Look.GOLD)
	codex.pressed.connect(func() -> void: app.open_codex())
	footer.add_child(codex)
	var rank := Look.label("등급 · " + notes.rank_name(), 14, Look.TEXT, "bold")
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(rank)
	add_child(footer)
	var source := Look.wrap_label("시세: 미 연준 H.10 원/달러, 미 에너지정보청 WTI 현물, XAUUSD 일봉 (2019.09–2020.12). 일부 시가·고가·저가는 종가로 추정. 게임 속 계약 크기와 수수료는 게임 값이다. M 소리 켜고 끄기.", 11, Look.FAINT, 560)
	Look.place(source, 650, 648, 580, 0)
	add_child(source)


func _era_card(era: Dictionary) -> Control:
	var open: bool = era["open"]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(270, 260)
	button.disabled = not open
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
	button.add_theme_stylebox_override("normal", Look.box(Look.PANEL, Look.GOLD if open else Look.LINE, 10, 2 if open else 1, 18))
	button.add_theme_stylebox_override("hover", Look.box(Look.RAISED, Look.GOLD, 10, 3, 18))
	button.add_theme_stylebox_override("pressed", Look.box(Look.RAISED, Look.GOLD, 10, 3, 18))
	button.add_theme_stylebox_override("disabled", Look.box(Color(Look.PANEL, 0.7), Look.LINE, 10, 1, 18))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var box := Look.vbox(6)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20
	box.offset_top = 18
	box.offset_right = -20
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(Look.label(era["year"], 44, Look.GOLD if open else Look.FAINT, "display"))
	box.add_child(Look.label(era["name"], 22, Look.TEXT if open else Look.FAINT, "display"))
	box.add_child(Look.wrap_label(era["text"], 13, Look.SOFT if open else Look.FAINT, 230))
	if open:
		for item: String in era["items"]:
			box.add_child(Look.label("· " + item, 12, Look.DIM))
		box.add_child(Look.label("시작하기  [Enter]", 14, Look.GOLD, "bold"))
	else:
		box.add_child(Look.label("준비 중", 13, Look.FAINT, "bold"))
	button.add_child(box)
	if open:
		button.pressed.connect(func() -> void: app.new_run())
	return button


func _draw_backdrop(node: Control) -> void:
	var bars := Market.bars("gold")
	var start := Market.index_on_or_after("gold", "2020-01-02")
	var count := 64
	var lo := INF
	var hi := -INF
	for i in range(start, start + count):
		lo = minf(lo, bars[i].low)
		hi = maxf(hi, bars[i].high)
	var left := 620.0
	var width := 640.0
	var top := 60.0
	var height := 270.0
	for i in count:
		var bar := bars[start + i]
		var x := left + width * (i + 0.5) / count
		var y := func(v: float) -> float: return top + height * (1.0 - (v - lo) / (hi - lo))
		var color := Color(Look.UP if bar.is_up() else Look.DOWN, 0.28)
		node.draw_line(Vector2(x, y.call(bar.high)), Vector2(x, y.call(bar.low)), color, 1.5)
		var t: float = y.call(maxf(bar.open, bar.close))
		var b: float = y.call(minf(bar.open, bar.close))
		node.draw_rect(Rect2(x - 3.5, t, 7, maxf(b - t, 1.5)), color)
	node.draw_string(Look.font("mono"), Vector2(left, top + height + 18), "금 일봉 2020.01 – 04", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Look.DIM, 0.5))


func handle_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_ENTER, KEY_SPACE]:
		app.new_run()
		return true
	return false

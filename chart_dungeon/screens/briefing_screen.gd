class_name BriefingScreen
extends Screen
## 첫 출근 브리핑. 규칙을 한 장 메모로.


func _ready() -> void:
	background()
	top_bar("2020.01.02 (목) · 첫 출근", [["2020 · 팬데믹", Look.DOWN_STRONG]])
	var memo := PanelContainer.new()
	var style := Look.box(Look.PAPER, Color("d8ccb0"), 4, 1, 34)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 14
	memo.add_theme_stylebox_override("panel", style)
	memo.rotation_degrees = -0.6
	Look.place(memo, 150, 76, 720, 0)
	add_child(memo)
	var box := Look.vbox(12)
	memo.add_child(box)
	box.add_child(Look.label("선물 데스크 신입 안내", 13, Look.GOLD_DARK, "bold"))
	box.add_child(Look.label("계좌 3,000만 원을 맡긴다.", 30, Look.INK, "display"))
	var rules := [
		["계좌가 곧 체력", "계좌가 1,900만 아래로 떨어지면 증권사가 포지션을 강제로 정리한다 (마진콜 · 반대매매). 그러면 판이 끝난다."],
		["하루가 한 턴", "카드로 주문을 낸다 → 장 마감 → 그날 실제 캔들이 시가부터 움직이며 닿은 주문이 체결된다 → 종가로 손익을 계좌에 넣고 뺀다 (일일정산)."],
		["거래마다 기한과 목표", "기한 안에 목표 손익을 내면 성과급과 카드 한 장. 못 미치면 덱에 나쁜 습관 카드가 들어온다."],
		["전망은 확률", "퀀트가 말하는 방향은 62%만 맞는다. 금색 상자는 오늘 예상 범위다. 손절과 익절을 걸어 두면 장중에 알아서 체결된다."],
		["모두 실제로 있었던 일", "캔들은 2020년 실제 시세, 뉴스는 실제 기사다. 쓰고 겪은 개념은 투자 노트에 쌓이고, 판이 끝나도 남는다."],
	]
	for rule: Array in rules:
		var row := Look.hbox(14)
		var head := Look.label(rule[0], 15, Look.INK, "bold")
		head.custom_minimum_size = Vector2(170, 0)
		row.add_child(head)
		row.add_child(Look.wrap_label(rule[1], 14, Look.INK_SOFT, 470))
		box.add_child(row)
	var side := Look.panel(Look.PANEL, Look.LINE, 10, 18)
	Look.place(side, 900, 110, 330, 0)
	var side_box := Look.vbox(10)
	side_box.add_child(Look.label("첫 팀원", 12, Look.DIM, "bold"))
	var row := Look.hbox(12)
	row.add_child(Sprites.portrait("analyst_bull", 4))
	var texts := Look.vbox(4)
	texts.add_child(Look.label("퀀트", 20, Look.TEXT, "display"))
	texts.add_child(Look.wrap_label(Run.MEMBERS["quant"]["text"], 12, Look.SOFT, 220))
	row.add_child(texts)
	side_box.add_child(row)
	var bubble := Look.panel(Look.PAPER, Look.PAPER, 6, 10)
	bubble.add_child(Look.wrap_label("첫 달은 조용할 겁니다. 그런데 뉴스를 보니 1월부터 심상치가 않네요.", 13, Look.INK, 280))
	side_box.add_child(bubble)
	side_box.add_child(Look.label("덱 12장", 12, Look.DIM, "bold"))
	side_box.add_child(Look.wrap_label("롱 진입 3 · 숏 진입 3 · 손절 주문 2 · 지정가 익절 1 · 청산 2 · 관망 1", 12, Look.SOFT, 290))
	side.add_child(side_box)
	add_child(side)
	var go := Look.button("출근한다", "primary", 22, "Enter")
	Look.place(go, 900, 600, 330, 64)
	go.pressed.connect(func() -> void: app.show_map())
	add_child(go)


func handle_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_ENTER, KEY_SPACE]:
		app.show_map()
		return true
	return false

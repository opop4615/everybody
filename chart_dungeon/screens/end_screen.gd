class_name EndScreen
extends Screen
## 판 결과. 살아남았는지, 계좌 흐름, 쌓인 투자 노트.


func _ready() -> void:
	background()
	var won: bool = run().victory
	top_bar("판 결과", [["2020 · 팬데믹", Look.DOWN_STRONG]])
	var title := Look.label("살아남았다" if won else "마진콜", 64, Look.GOLD if won else Look.UP, "display")
	Look.place(title, 60, 70)
	add_child(title)
	var change := run().account - Era2020.START_ACCOUNT
	var text := "공포의 3월과 마이너스 유가를 지나 계좌 %s로 판을 마쳤다 (%s)." % [Fmt.money(run().account), Fmt.signed_money(change)] if won else "계좌가 마진콜 선 아래로 떨어져 포지션이 강제로 정리됐다. 투자 노트는 그대로 남는다."
	var sub := Look.wrap_label(text, 18, Look.TEXT, 1100, "bold")
	Look.place(sub, 64, 170, 1100, 0)
	add_child(sub)
	var chart_panel := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	Look.place(chart_panel, 60, 230, 700, 330)
	var chart_box := Look.vbox(8)
	chart_box.add_child(Look.label("계좌 흐름 · 2020", 12, Look.DIM, "bold"))
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(670, 270)
	chart.draw.connect(_draw_account.bind(chart))
	chart_box.add_child(chart)
	chart_panel.add_child(chart_box)
	add_child(chart_panel)
	var stats := Look.panel(Look.PANEL, Look.LINE, 8, 18)
	Look.place(stats, 780, 230, 440, 330)
	var box := Look.vbox(8)
	var s: Dictionary = run().stats
	box.add_child(Look.label("성적", 12, Look.DIM, "bold"))
	box.add_child(Look.label("거래 %d번 · 달성 %d · 미달 %d" % [int(s["trades"]), int(s["won"]), int(s["failed"])], 16, Look.TEXT, "bold"))
	box.add_child(Look.label("가장 좋은 거래 %s" % Fmt.signed_money(float(s["best"])), 14, Look.SOFT))
	box.add_child(Look.label("덱 %d장 · 팀원 %d명" % [run().deck.size(), run().members.size()], 14, Look.SOFT))
	var notes := run().notes
	box.add_child(Look.label("투자 노트 %d/%d · 별 %d개" % [notes.known_count(), NoteDB.total(), notes.stars()], 16, Look.GOLD, "bold"))
	box.add_child(Look.label("등급 · " + notes.rank_name(), 20, Look.GOLD, "display"))
	var next_rank := notes.next_rank()
	if not String(next_rank[0]).is_empty():
		box.add_child(Look.wrap_label("다음 등급 %s까지 %d항목. 투자 노트는 다음 판에도 이어진다." % [next_rank[0], int(next_rank[1]) - notes.known_count()], 13, Look.DIM, 400))
	stats.add_child(box)
	add_child(stats)
	var again := Look.button("새 판", "primary", 20, "Enter")
	Look.place(again, 60, 600, 220, 60)
	again.pressed.connect(func() -> void: app.new_run())
	add_child(again)
	var home := Look.button("타이틀", "plain", 16)
	Look.place(home, 296, 600, 160, 60)
	home.pressed.connect(func() -> void: app.show_title())
	add_child(home)
	app.sfx.play("win" if won else "lose", -6.0)


func _draw_account(node: Control) -> void:
	var points: Array = [Era2020.START_ACCOUNT]
	for item: Dictionary in run().history:
		points.append(item["account"])
	var lo: float = run().margin_line
	var hi: float = Era2020.START_ACCOUNT
	for p: float in points:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	var pad := (hi - lo) * 0.1
	lo -= pad
	hi += pad
	var w := node.size.x - 60
	var h := node.size.y - 10
	var y := func(v: float) -> float: return h * (1.0 - (v - lo) / maxf(hi - lo, 1.0))
	for k in 4:
		var v := lerpf(lo, hi, k / 3.0)
		node.draw_line(Vector2(0, y.call(v)), Vector2(w, y.call(v)), Look.GRID, 1.0)
		node.draw_string(Look.font("mono"), Vector2(w + 6, y.call(v) + 4), Fmt.number(v, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM_2)
	node.draw_dashed_line(Vector2(0, y.call(run().margin_line)), Vector2(w, y.call(run().margin_line)), Look.DOWN_TEXT, 1.5, 5.0)
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for i in points.size():
		line.append(Vector2(w * i / float(points.size() - 1), y.call(points[i])))
	node.draw_polyline(line, Look.GOLD, 2.5, true)


func handle_key(event: InputEventKey) -> bool:
	if event.keycode in [KEY_ENTER, KEY_SPACE]:
		app.new_run()
		return true
	return false

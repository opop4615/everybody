class_name ReviewScreen
extends Screen
## 막이 끝난 뒤 복기. 계좌 흐름, 성적, 그리고 그 막의 실제 역사 퀴즈 한 문제.
## 맞히면 투자 노트 한 단계와 성과급.

const QUIZ_BONUS := 30

var _quiz: Dictionary
var _answered := false
var _quiz_box: VBoxContainer
var _next: Button


func _ready() -> void:
	background()
	var act := run().act()
	top_bar(String(act["period"]) + " · 막 복기", [[act["title"], Look.DOWN_STRONG]])
	var title := Look.label(String(act["title"]) + " 끝", 32, Look.GOLD, "display")
	Look.place(title, 40, 66)
	add_child(title)
	var start: float = run().act_start_account
	var change := run().account - start
	var sub := Look.label("계좌 %s → %s (%s)" % [Fmt.money(start), Fmt.money(run().account), Fmt.signed_money(change)], 16, Look.up_down(change), "bold")
	Look.place(sub, 42, 114)
	add_child(sub)
	var chart_panel := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	Look.place(chart_panel, 40, 156, 560, 300)
	var chart_box := Look.vbox(8)
	chart_box.add_child(Look.label("이번 막 계좌 흐름", 12, Look.DIM, "bold"))
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(530, 220)
	chart.draw.connect(_draw_account.bind(chart))
	chart_box.add_child(chart)
	chart_panel.add_child(chart_box)
	add_child(chart_panel)
	var stats := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	Look.place(stats, 40, 468, 560, 220)
	var stats_box := Look.vbox(6)
	stats_box.add_child(Look.label("성적", 12, Look.DIM, "bold"))
	var s: Dictionary = run().stats
	stats_box.add_child(Look.label("거래 %d번 · 달성 %d · 미달 %d" % [int(s["trades"]), int(s["won"]), int(s["failed"])], 15, Look.TEXT, "bold"))
	stats_box.add_child(Look.label("가장 좋은 거래 %s" % Fmt.signed_money(float(s["best"])), 14, Look.SOFT))
	stats_box.add_child(Look.label("패턴 카드 %d번 받음 · 습관 카드 %d장" % [int(s.get("patterns", 0)), run().habits().size()], 14, Look.SOFT))
	stats_box.add_child(Look.label("투자 노트 %d/%d · %s" % [run().notes.known_count(), NoteDB.total(), run().notes.rank_name()], 14, Look.GOLD, "bold"))
	var next_rank := run().notes.next_rank()
	if not String(next_rank[0]).is_empty():
		stats_box.add_child(Look.label("다음 등급 %s까지 %d항목" % [next_rank[0], int(next_rank[1]) - run().notes.known_count()], 12, Look.DIM))
	stats.add_child(stats_box)
	add_child(stats)
	_quiz = Era2020.QUIZZES[mini(run().act_index, Era2020.QUIZZES.size() - 1)]
	var quiz_panel := Look.panel(Look.PANEL_2, Look.GOLD, 10, 20)
	Look.place(quiz_panel, 620, 156, 620, 532)
	_quiz_box = Look.vbox(12)
	quiz_panel.add_child(_quiz_box)
	add_child(quiz_panel)
	_quiz_box.add_child(Look.label("역사 퀴즈", 13, Look.GOLD, "bold"))
	_quiz_box.add_child(Look.wrap_label(String(_quiz["question"]), 22, Look.TEXT, 570, "display"))
	for i in _quiz["options"].size():
		var option := Look.button("%d  %s" % [i + 1, _quiz["options"][i]], "plain", 15)
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.custom_minimum_size = Vector2(570, 48)
		option.pressed.connect(_answer.bind(i))
		_quiz_box.add_child(option)


func _draw_account(node: Control) -> void:
	var points: Array = [run().act_start_account]
	var dates: Array = [run().act_start_date]
	for item: Dictionary in run().history:
		if int(item["act"]) == run().act_index:
			points.append(item["account"])
			dates.append(item["date"])
	var lo: float = run().margin_line
	var hi: float = run().act_start_account
	for p: float in points:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	var pad := (hi - lo) * 0.1
	lo -= pad
	hi += pad
	var w := node.size.x - 60
	var h := node.size.y - 20
	var y := func(v: float) -> float: return h * (1.0 - (v - lo) / maxf(hi - lo, 1.0))
	var mono := Look.font("mono")
	for k in 4:
		var v := lerpf(lo, hi, k / 3.0)
		node.draw_line(Vector2(0, y.call(v)), Vector2(w, y.call(v)), Look.GRID, 1.0)
		node.draw_string(mono, Vector2(w + 6, y.call(v) + 4), Fmt.number(v, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM_2)
	node.draw_dashed_line(Vector2(0, y.call(run().margin_line)), Vector2(w, y.call(run().margin_line)), Look.DOWN_TEXT, 1.5, 5.0)
	node.draw_string(Look.font("bold"), Vector2(4, y.call(run().margin_line) - 5), "마진콜 선", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DOWN_TEXT)
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for i in points.size():
		line.append(Vector2(w * i / float(points.size() - 1), y.call(points[i])))
	var fill := line.duplicate()
	fill.append(Vector2(w, h))
	fill.append(Vector2(0, h))
	node.draw_colored_polygon(fill, Color(Look.GOLD, 0.08))
	node.draw_polyline(line, Look.GOLD, 2.5, true)
	for i in [0, dates.size() - 1]:
		var d := String(dates[i]).split("-")
		node.draw_string(mono, Vector2(clampf(w * i / float(points.size() - 1) - 14, 0, w - 30), h + 16), "%d.%d" % [int(d[1]), int(d[2])], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM_2)


func _answer(index: int) -> void:
	if _answered:
		return
	_answered = true
	var right := index == int(_quiz["answer"])
	for child in _quiz_box.get_children():
		if child is Button:
			(child as Button).disabled = true
	if right:
		run().notes.study(_quiz["note"])
		run().bonus += QUIZ_BONUS
		app.sfx.play("win", -6.0)
	else:
		app.sfx.play("lose", -8.0)
	var verdict := "맞았다 · 투자 노트 %s 한 단계, 성과급 +%d" % [NoteDB.name_of(_quiz["note"]), QUIZ_BONUS] if right else "아니다 · 정답은 %d번" % (int(_quiz["answer"]) + 1)
	_quiz_box.add_child(Look.label(verdict, 16, Look.GOLD if right else Look.DOWN_TEXT, "display"))
	_quiz_box.add_child(Look.wrap_label(String(_quiz["explain"]), 14, Look.TEXT, 570))
	_next = Look.button("판 결과" if run().victory else "다음 막으로", "primary", 18, "Space")
	_next.pressed.connect(_go_next)
	_quiz_box.add_child(_next)


func _go_next() -> void:
	if run().victory or run().over:
		app.show_end()
	else:
		app.next_act()


func handle_key(event: InputEventKey) -> bool:
	if _answered and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_go_next()
		return true
	if not _answered and event.keycode >= KEY_1 and event.keycode <= KEY_3:
		_answer(event.keycode - KEY_1)
		return true
	return false

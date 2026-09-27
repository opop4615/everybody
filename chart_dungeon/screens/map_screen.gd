class_name MapScreen
extends Screen
## 막 지도. 왼쪽에서 오른쪽으로 날짜가 흐르고, 열마다 한 칸을 고른다.
## 이웃한 줄로만 건너갈 수 있다. 마지막 열은 막 보스.

const LANE_Y := [206.0, 318.0, 430.0]
const LEFT := 90.0
const RIGHT := 1190.0

var _canvas: Control
var _info: PanelContainer
var _info_box: VBoxContainer
var _nodes := {}
var _hover := {}
var _pulse := 0.0


func _ready() -> void:
	background()
	var act := run().act()
	top_bar(String(act["period"]), [[act["title"], Look.DOWN_STRONG]])
	var title := Look.label(act["title"], 30, Look.TEXT, "display")
	Look.place(title, 40, 66)
	add_child(title)
	var sub := Look.label("한 열에서 한 칸을 고른다. 이웃한 줄로만 건너갈 수 있다. 날짜는 왼쪽에서 오른쪽으로 흐른다.", 13, Look.DIM)
	Look.place(sub, 42, 110)
	add_child(sub)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	_build_nodes()
	_build_bottom()
	_show_info({})


func _process(delta: float) -> void:
	_pulse += delta
	for id in _nodes:
		(_nodes[id] as Control).queue_redraw()


func _column_x(i: int) -> float:
	var n: int = run().columns().size()
	return LEFT + (RIGHT - LEFT) * i / float(maxi(n - 1, 1))


func _node_pos(i: int, node: Dictionary) -> Vector2:
	return Vector2(_column_x(i), LANE_Y[int(node["lane"])])


func _radius(node: Dictionary) -> float:
	match node["kind"]:
		"boss":
			return 42.0
		"elite":
			return 33.0
		"start":
			return 22.0
	return 29.0


func _build_nodes() -> void:
	var columns: Array = run().columns()
	for i in columns.size():
		for node: Dictionary in columns[i]:
			var r := _radius(node)
			var button := Control.new()
			var center := _node_pos(i, node)
			Look.place(button, center.x - r - 6, center.y - r - 6, (r + 6) * 2, (r + 6) * 2)
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			var available := run().is_available(node)
			if available:
				button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.draw.connect(_draw_node.bind(button, node, r))
			button.mouse_entered.connect(func() -> void:
				_hover = node
				_show_info(node)
				_canvas.queue_redraw())
			button.mouse_exited.connect(func() -> void:
				if _hover == node:
					_hover = {}
					_show_info({})
					_canvas.queue_redraw())
			button.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					app.open_node(node))
			add_child(button)
			_nodes[node["id"]] = button
			if node.has("inst") or node["kind"] in ["news", "desk", "rest"]:
				var caption := Look.label(_caption(node), 11, Look.SOFT if available or run().visited.has(node["id"]) else Look.FAINT)
				caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				Look.place(caption, center.x - 60, center.y + r + 6, 120, 16)
				add_child(caption)
		var date := Look.label(_short(String(columns[i][0]["date"])), 11, Look.DIM_2, "mono")
		date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Look.place(date, _column_x(i) - 30, 148, 60, 16)
		add_child(date)


func _short(date: String) -> String:
	var parts := date.split("-")
	return "%d.%d" % [int(parts[1]), int(parts[2])]


func _caption(node: Dictionary) -> String:
	if node.has("inst"):
		return "목표 +%s · %d일" % [Fmt.money(node["target"]), int(node["days"])]
	return Look.kind_name(node["kind"])


func _glyph(node: Dictionary) -> String:
	if node.has("inst"):
		return Instrument.of(node["inst"]).glyph
	return {"news": "뉴스", "desk": "데스크", "rest": "퇴근", "start": "출근"}.get(node["kind"], "?")


func _draw_map() -> void:
	var columns: Array = run().columns()
	# 이어진 길
	for i in range(columns.size() - 1):
		for a: Dictionary in columns[i]:
			for b: Dictionary in columns[i + 1]:
				if absi(int(a["lane"]) - int(b["lane"])) <= 1 or i == 0:
					var walked: bool = run().visited.has(a["id"]) and run().visited.has(b["id"])
					var color := Look.GOLD if walked else Look.LINE
					_canvas.draw_line(_node_pos(i, a), _node_pos(i + 1, b), color, 3.0 if walked else 1.5, true)
	# 지금 자리에서 갈 수 있는 길
	var here: Dictionary = {}
	for node: Dictionary in columns[run().column]:
		if run().visited.has(node["id"]):
			here = node
	if not here.is_empty():
		for node in run().available():
			var color := Color(Look.GOLD, 0.55 if _hover != node else 1.0)
			_canvas.draw_dashed_line(_node_pos(run().column, here), _node_pos(run().column + 1, node), color, 2.0, 7.0)


func _draw_node(button: Control, node: Dictionary, r: float) -> void:
	var c := button.size * 0.5
	var visited: bool = run().visited.has(node["id"])
	var available := run().is_available(node)
	var fill := Look.kind_color(node["kind"])
	if node.has("inst") and node["kind"] == "trade":
		fill = {"usdkrw": Color("2d5a3d"), "gold": Color("8a6a1c"), "wti": Color("3d3d46")}.get(node["inst"], fill)
	if not available and not visited:
		fill = fill.lerp(Look.BG, 0.55)
	if available:
		var glow := 0.5 + 0.5 * sin(_pulse * 4.0)
		button.draw_circle(c, r + 5, Color(Look.GOLD, 0.25 + 0.35 * glow))
	button.draw_circle(c, r, Look.INK)
	button.draw_circle(c, r - 3, fill)
	if visited:
		button.draw_arc(c, r - 1.5, 0, TAU, 40, Look.GOLD, 3.0, true)
	elif _hover == node:
		button.draw_arc(c, r - 1.5, 0, TAU, 40, Look.TEXT, 2.0, true)
	var glyph := _glyph(node)
	var font := Look.font("display")
	var size := 26 if glyph.length() == 1 else (13 if glyph.length() >= 3 else 15)
	if node["kind"] == "boss":
		size = 30
	var s := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var ink := Look.TEXT if available or visited else Look.DIM_2
	button.draw_string(font, c + Vector2(-s.x * 0.5, size * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	if node["kind"] in ["elite", "boss"]:
		var tag := "보스" if node["kind"] == "boss" else "발표일"
		var small := Look.font("bold")
		var ts := small.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var rect := Rect2(c + Vector2(-ts.x * 0.5 - 5, -r - 4), Vector2(ts.x + 10, 16))
		button.draw_rect(rect, Look.DOWN_STRONG if node["kind"] == "boss" else Color("7a3d8c"))
		button.draw_string(small, rect.position + Vector2(5, 12), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _build_bottom() -> void:
	_info = Look.panel(Look.PANEL, Look.LINE, 8, 14)
	Look.place(_info, 40, 520, 600, 176)
	_info_box = Look.vbox(6)
	_info.add_child(_info_box)
	add_child(_info)
	var team := Look.panel(Look.PANEL, Look.LINE, 8, 14)
	Look.place(team, 652, 520, 588, 176)
	var box := Look.vbox(8)
	var head := Look.hbox(10)
	head.add_child(Look.label("데스크 팀", 12, Look.DIM, "bold"))
	head.add_child(Look.spacer())
	head.add_child(Look.label("투자 노트 %d/%d · %s" % [run().notes.known_count(), NoteDB.total(), run().notes.rank_name()], 12, Look.GOLD, "bold"))
	box.add_child(head)
	var row := Look.hbox(18)
	for id in run().members:
		var info: Dictionary = Run.MEMBERS[id]
		var member := Look.vbox(2)
		member.add_child(Sprites.portrait(info["sprite"], 3))
		member.add_child(Look.label(info["name"], 11, Look.SOFT))
		row.add_child(member)
	for i in range(run().members.size(), Run.MAX_MEMBERS):
		var empty := Look.vbox(2)
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(42, 42)
		slot.add_theme_stylebox_override("panel", Look.box(Look.PANEL_2, Look.LINE, 6, 1, 0))
		empty.add_child(slot)
		empty.add_child(Look.label("빈 자리", 11, Look.FAINT))
		row.add_child(empty)
	row.add_child(Look.spacer())
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(220, 70)
	spark.draw.connect(_draw_spark.bind(spark))
	row.add_child(spark)
	box.add_child(row)
	var habits := run().habits().size()
	var summary := "덱 %d장%s · 거래 %d번 중 %d번 달성" % [run().deck.size(), (" (습관 %d)" % habits) if habits > 0 else "", int(run().stats["trades"]), int(run().stats["won"])]
	box.add_child(Look.label(summary, 12, Look.SOFT))
	team.add_child(box)
	add_child(team)


func _draw_spark(spark: Control) -> void:
	var points: Array = [Era2020.START_ACCOUNT]
	for item: Dictionary in run().history:
		points.append(item["account"])
	var w := spark.size.x
	var h := spark.size.y - 14
	var lo: float = run().margin_line
	var hi: float = Era2020.START_ACCOUNT
	for p: float in points:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	hi += (hi - lo) * 0.1
	var y_of := func(v: float) -> float: return 14 + h * (1.0 - (v - lo) / maxf(hi - lo, 1.0))
	spark.draw_string(Look.font("body"), Vector2(0, 10), "계좌 흐름", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM)
	spark.draw_dashed_line(Vector2(0, y_of.call(run().margin_line)), Vector2(w, y_of.call(run().margin_line)), Look.DOWN_TEXT, 1.0, 4.0)
	if points.size() < 2:
		points.append(points[0])
	var line := PackedVector2Array()
	for i in points.size():
		line.append(Vector2(w * i / float(points.size() - 1), y_of.call(points[i])))
	spark.draw_polyline(line, Look.GOLD, 2.0, true)


func _show_info(node: Dictionary) -> void:
	for child in _info_box.get_children():
		child.queue_free()
	if node.is_empty():
		_info_box.add_child(Look.label("다음 칸 고르기", 12, Look.DIM, "bold"))
		_info_box.add_child(Look.wrap_label("금색으로 빛나는 칸이 갈 수 있는 곳이다. 칸에 마우스를 올리면 무엇이 기다리는지 보인다.", 14, Look.TEXT, 570))
		var kinds := Look.hbox(8)
		for kind in ["trade", "elite", "news", "desk", "rest", "boss"]:
			kinds.add_child(Look.tag(Look.kind_name(kind), Look.kind_color(kind)))
		_info_box.add_child(kinds)
		_info_box.add_child(Look.wrap_label("거래 — 기한 안에 목표 손익을 낸다. 발표일 — 큰 발표가 있는 날이라 흔들림이 크고 보상도 크다. 뉴스 — 실제 그날의 기사와 선택. 데스크 — 카드를 사고 팀원을 뽑는다. 퇴근 — 공부하거나 복기한다.", 12, Look.DIM, 570))
		return
	var head := Look.hbox(8)
	head.add_child(Look.tag(Look.kind_name(node["kind"]), Look.kind_color(node["kind"])))
	head.add_child(Look.label(_long_date(node["date"]), 13, Look.GOLD, "mono_bold"))
	_info_box.add_child(head)
	var title: String = node.get("title", Look.kind_name(node["kind"]))
	_info_box.add_child(Look.label(title, 22, Look.TEXT, "display"))
	if node.has("inst"):
		var inst := Instrument.of(node["inst"])
		_info_box.add_child(Look.label("%s · %d거래일 안에 +%s" % [inst.name, int(node["days"]), Fmt.money(node["target"])], 14, Look.SOFT, "bold"))
		_info_box.add_child(Look.label(inst.spec, 12, Look.DIM))
		if node["kind"] == "boss":
			for rule: String in node.get("rules", []):
				_info_box.add_child(Look.label(rule, 12, Look.DOWN_TEXT))
		else:
			_info_box.add_child(Look.label("이기면 카드 한 장과 성과급, 못 미치면 덱에 나쁜 습관 카드가 들어온다.", 12, Look.DIM))
	elif node["kind"] == "news":
		_info_box.add_child(Look.wrap_label("실제로 이날 나온 기사. 무엇을 할지 고른다.", 13, Look.SOFT, 570))
	elif node["kind"] == "desk":
		_info_box.add_child(Look.wrap_label("성과급으로 카드를 사고, 팀원을 뽑고, 카드를 지우거나 강화한다. 성과급으로 계좌에 돈을 넣을 수도 있다.", 13, Look.SOFT, 570))
	elif node["kind"] == "rest":
		_info_box.add_child(Look.wrap_label("공부해서 투자 노트를 올리거나, 복기해서 나쁜 습관을 지우거나, 백테스트로 카드 한 장을 강화한다.", 13, Look.SOFT, 570))
	if not run().is_available(node):
		var visited: bool = run().visited.has(node["id"])
		_info_box.add_child(Look.label("지나온 칸" if visited else "지금은 갈 수 없다", 12, Look.FAINT))
	else:
		_info_box.add_child(Look.label("클릭하면 들어간다", 12, Look.GOLD, "bold"))


func _long_date(date: String) -> String:
	var bar := Bar.new(date)
	return bar.long_date()


func handle_key(event: InputEventKey) -> bool:
	var list := run().available()
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		var index := event.keycode - KEY_1
		if index < list.size():
			app.open_node(list[index])
		return true
	return false

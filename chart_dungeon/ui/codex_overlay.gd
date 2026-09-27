class_name CodexOverlay
extends Control
## 투자 노트. 장(chapter)별 항목, 단계마다 열리는 설명, 단계가 주는 화면 정보.
## 판이 끝나도 남는다. 아는 항목 수로 등급(자격증 이름)이 오른다.

var app: Node
var notes: Notes
var _chapter := ""
var _selected := ""
var _tabs: VBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer


func setup(p_app: Node, focus := "") -> CodexOverlay:
	app = p_app
	notes = app.notes
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(Look.dim_layer(0.78))
	var panel := Look.panel(Look.PANEL, Look.GOLD, 12, 20)
	Look.place(panel, 60, 40, 1160, 640)
	add_child(panel)
	var root := Look.vbox(14)
	panel.add_child(root)
	var head := Look.hbox(14)
	head.add_child(Look.label("투자 노트", 28, Look.GOLD, "display"))
	var rank := Look.label("%s · %d/%d항목 · 별 %d" % [notes.rank_name(), notes.known_count(), NoteDB.total(), notes.stars()], 14, Look.TEXT, "bold")
	rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rank)
	var next_rank := notes.next_rank()
	if not String(next_rank[0]).is_empty():
		var next := Look.label("다음 등급 %s · %d항목" % [next_rank[0], int(next_rank[1])], 12, Look.DIM)
		next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(next)
	head.add_child(Look.spacer())
	var close := Look.button("닫기", "plain", 13, "Esc")
	close.pressed.connect(func() -> void: app.close_overlay())
	head.add_child(close)
	root.add_child(head)
	var body := Look.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_tabs = Look.vbox(4)
	_tabs.custom_minimum_size = Vector2(170, 0)
	body.add_child(_tabs)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(300, 540)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = Look.vbox(4)
	_list.custom_minimum_size = Vector2(290, 0)
	list_scroll.add_child(_list)
	body.add_child(list_scroll)
	var detail_panel := Look.panel(Look.PANEL_2, Look.LINE, 8, 18)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = Look.vbox(12)
	detail_panel.add_child(_detail)
	body.add_child(detail_panel)
	if not focus.is_empty() and NoteDB.ENTRIES.has(focus):
		_chapter = NoteDB.ENTRIES[focus]["chapter"]
		_selected = focus
	else:
		_chapter = NoteDB.CHAPTERS[0]
	_refresh()
	return self


func _refresh() -> void:
	for child in _tabs.get_children():
		child.queue_free()
	for chapter: String in NoteDB.CHAPTERS:
		var ids := NoteDB.ids_in(chapter)
		var known := 0
		for id in ids:
			if notes.level(id) > 0:
				known += 1
		var tab := Look.button("%s  %d/%d" % [chapter, known, ids.size()], "primary" if chapter == _chapter else "ghost", 13)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.pressed.connect(func() -> void:
			_chapter = chapter
			_selected = ""
			_refresh())
		_tabs.add_child(tab)
	for child in _list.get_children():
		child.queue_free()
	var ids := NoteDB.ids_in(_chapter)
	if _selected.is_empty():
		for id in ids:
			if notes.level(id) > 0:
				_selected = id
				break
	for id in ids:
		var level := notes.level(id)
		var known := level > 0
		var text := "%s   %s" % [NoteDB.name_of(id) if known else "???", Look.stars(level, notes._cap(id))]
		var item := Look.button(text, "primary" if id == _selected else "ghost", 13)
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not known:
			item.add_theme_color_override("font_color", Look.FAINT)
		if notes.fresh.has(id) and known:
			item.text += "  새"
		item.pressed.connect(func() -> void:
			_selected = id
			_refresh())
		_list.add_child(item)
	_show_detail()


func _show_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	if _selected.is_empty():
		_detail.add_child(Look.wrap_label("이 장에서 아직 아는 항목이 없다. 카드를 쓰고, 뉴스를 읽고, 거래를 겪으면 적힌다.", 15, Look.SOFT, 560))
		return
	var entry: Dictionary = NoteDB.ENTRIES[_selected]
	var level := notes.level(_selected)
	var cap := notes._cap(_selected)
	var head := Look.hbox(12)
	head.add_child(Look.label(NoteDB.name_of(_selected) if level > 0 else "???", 26, Look.TEXT, "display"))
	var stars := Look.label(Look.stars(level, cap), 16, Look.GOLD)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(stars)
	_detail.add_child(head)
	var texts: Array = entry["texts"]
	var perks: Array = entry.get("perks", [])
	for i in cap:
		var box := Look.panel(Look.PANEL if i < level else Look.BG, Look.LINE if i < level else Look.LINE, 6, 12)
		var inner := Look.vbox(4)
		inner.add_child(Look.label("%d단계" % (i + 1), 11, Look.GOLD if i < level else Look.FAINT, "bold"))
		if i < level:
			inner.add_child(Look.wrap_label(String(texts[i]), 15, Look.TEXT, 540))
			if i < perks.size() and not String(perks[i]).is_empty():
				inner.add_child(Look.wrap_label("화면 · " + String(perks[i]), 12, Look.GOLD, 540))
		else:
			inner.add_child(Look.wrap_label("잠김 — 관련 카드를 더 쓰거나, 퇴근길에 공부하거나, 퀴즈를 맞히면 열린다.", 13, Look.FAINT, 540))
		box.add_child(inner)
		_detail.add_child(box)
	var uses := int(notes.uses.get(_selected, 0))
	if uses > 0:
		_detail.add_child(Look.label("써 본 횟수 %d" % uses, 12, Look.DIM))

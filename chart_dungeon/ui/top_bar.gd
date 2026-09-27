class_name TopBar
extends PanelContainer
## 화면 맨 위 띠: 날짜, 칸 딱지, 계좌 막대(마진콜 선), 성과급, 덱·투자 노트 버튼.

signal deck_pressed
signal notes_pressed

var run: Run
var _date: Label
var _tag_box: HBoxContainer
var _account: Label
var _bonus: Label
var _bar: Control
var _deck_button: Button
var _notes_button: Button
## 막대에 보여 줄 계좌 (재생 중에는 run.account 대신 이 값을 쓴다).
var shown_account := NAN


func setup(p_run: Run) -> TopBar:
	run = p_run
	add_theme_stylebox_override("panel", _style())
	custom_minimum_size = Vector2(1280, 46)
	size = Vector2(1280, 46)
	var row := Look.hbox(14)
	add_child(row)
	_date = Look.label("", 13, Look.GOLD, "mono_bold")
	_date.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_date)
	_tag_box = Look.hbox(6)
	_tag_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tag_box)
	var account_row := Look.hbox(8)
	account_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	account_row.add_child(Look.label("계좌", 12, Look.DIM))
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(180, 18)
	_bar.draw.connect(_draw_bar)
	account_row.add_child(_bar)
	_account = Look.label("", 17, Look.TEXT, "display")
	account_row.add_child(_account)
	row.add_child(account_row)
	var bonus_row := Look.hbox(6)
	bonus_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bonus_row.add_child(Look.label("성과급", 12, Look.DIM))
	_bonus = Look.label("", 17, Look.GOLD, "display")
	bonus_row.add_child(_bonus)
	row.add_child(bonus_row)
	row.add_child(Look.spacer())
	_deck_button = Look.button("덱", "plain", 13)
	_deck_button.custom_minimum_size = Vector2(0, 32)
	_deck_button.pressed.connect(func() -> void: deck_pressed.emit())
	row.add_child(_deck_button)
	_notes_button = Look.button("투자 노트", "plain", 13)
	_notes_button.add_theme_color_override("font_color", Look.GOLD)
	_notes_button.custom_minimum_size = Vector2(0, 32)
	_notes_button.pressed.connect(func() -> void: notes_pressed.emit())
	row.add_child(_notes_button)
	refresh()
	return self


func _style() -> StyleBoxFlat:
	var style := Look.box(Look.BAR, Look.LINE, 0, 0, 0)
	style.border_width_bottom = 1
	style.content_margin_left = 20
	style.content_margin_right = 16
	return style


func set_context(date_text: String, tags: Array) -> void:
	_date.text = date_text
	for child in _tag_box.get_children():
		child.queue_free()
	for item: Array in tags:
		_tag_box.add_child(Look.tag(item[0], item[1]))


func refresh() -> void:
	var account := run.account if is_nan(shown_account) else shown_account
	_account.text = Fmt.money(account)
	_account.add_theme_color_override("font_color", Look.UP_TEXT if account < run.margin_line + 300.0 else Look.TEXT)
	_bonus.text = str(run.bonus)
	_deck_button.text = "덱 %d  [D]" % run.deck.size()
	var fresh := run.notes.fresh.size()
	_notes_button.text = "투자 노트 %s [N]" % (("· 새 %d " % fresh) if fresh > 0 else "")
	_bar.queue_redraw()


func _draw_bar() -> void:
	var account := run.account if is_nan(shown_account) else shown_account
	var w := _bar.size.x
	var y := 4.0
	var h := 10.0
	var scale := maxf(Era2020.START_ACCOUNT * 1.5, account * 1.1)
	_bar.draw_rect(Rect2(0, y, w, h), Look.LINE)
	var fill := clampf(account / scale, 0.0, 1.0) * w
	var danger := account < run.margin_line + 300.0
	_bar.draw_rect(Rect2(0, y, fill, h), Look.UP if danger else Look.GOLD)
	if run.notes.level("margin_call") >= 1:
		var x := run.margin_line / scale * w
		_bar.draw_rect(Rect2(x - 1, 0, 2, 18), Look.DOWN_TEXT)

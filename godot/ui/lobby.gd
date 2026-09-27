class_name Lobby
extends Control
## 로비: 오늘의 전장(종목)을 보고 매수군·매도군 중 한쪽에 합류한다.

signal join_requested(company: Company, faction: int)

var company: Company
var _name_label: Label
var _price_row: HBoxContainer


func _init(start_company: Company = null) -> void:
	company = start_company
	if company == null:
		var roster := Company.roster()
		company = roster[randi() % roster.size()]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)
	row.add_child(_build_left())
	row.add_child(_build_rules())
	_show_company()


func _build_left() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(660, 0)
	box.add_theme_constant_override("separation", 14)
	box.add_child(WarStyle.label("호가전쟁", 64, Color.WHITE, true))
	box.add_child(WarStyle.label("매수세와 매도세가 호가창에서 싸운다. 어느 편에 설 것인가?", 22, WarStyle.MUTED))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WarStyle.box(WarStyle.PANEL, Color(0, 0, 0, 0), 14, 0, 22))
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	card.add_child(card_box)
	var head := HBoxContainer.new()
	var today := WarStyle.label("오늘의 전장", 15, WarStyle.MUTED)
	today.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(today)
	var reroll := Button.new()
	reroll.text = "다른 종목"
	WarStyle.paint_button(reroll, WarStyle.MUTED, true, 14)
	reroll.pressed.connect(_reroll)
	head.add_child(reroll)
	card_box.add_child(head)
	_name_label = WarStyle.label("", 34, Color.WHITE, true)
	card_box.add_child(_name_label)
	_price_row = HBoxContainer.new()
	card_box.add_child(_price_row)
	box.add_child(card)

	var joins := HBoxContainer.new()
	joins.add_theme_constant_override("separation", 16)
	joins.add_child(_join_button(War.Faction.BULL, "가격을 밀어 올려라", "목표: 상한가 · 매도군 본진 함락"))
	joins.add_child(_join_button(War.Faction.BEAR, "가격을 끌어 내려라", "목표: 하한가 · 매수군 본진 함락"))
	box.add_child(joins)

	var keys := WarStyle.label("조작  A 돌격 · S 벽 쌓기 · D 포지션 정리 · F 주문 취소 · Q/W/E 스킬 · 1~4 수량 · Space 일시정지", 14, WarStyle.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(keys)
	box.add_child(WarStyle.label("등장 종목과 뉴스는 모두 가상입니다. 실제 투자 판단의 근거가 아닙니다.", 13, WarStyle.MUTED))
	return box


func _join_button(faction: int, line1: String, line2: String) -> Control:
	var color := WarStyle.of(faction)
	var button := Button.new()
	button.name = "Join" + ("Bull" if faction == War.Faction.BULL else "Bear")
	button.custom_minimum_size = Vector2(0, 170)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	WarStyle.paint_button(button, color, true)
	button.pressed.connect(func() -> void: join_requested.emit(company, faction))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 22
	content.offset_top = 20
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	var arrow := WarStyle.label("▲" if faction == War.Faction.BULL else "▼", 30, color, true)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(arrow)
	var title := WarStyle.label("%s 합류" % War.label(faction), 28, color, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	for text in [line1, line2]:
		var line := WarStyle.label(text, 15, WarStyle.MUTED)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(line)
	button.add_child(content)
	return button


func _build_rules() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_rule_card("승리 조건", [
		"장 마감(15:30) 종가가 기준가보다 높으면 매수군, 낮으면 매도군 승리",
		"상한가(하한가)를 %d분 동안 지키면 적 본진 함락 · 즉시 완승" % BattleEngine.LIMIT_HOLD_TO_WIN,
		"기준가 대비 10% 급변하면 VI 발동: 2분간 시장가·스킬 봉인",
		"진영이 이겨도 내 계좌가 깨지면 등급은 낮다. 전공과 수익을 함께 챙겨라",
	]))
	box.add_child(_rule_card("싸우는 법", [
		"왼쪽 호가창의 잔량이 오른쪽 전장의 병력이다. 한 칸 = 한 열",
		"돌격: 시장가로 상대 호가를 먹어 치운다",
		"벽 쌓기: 아군 최우선 호가에 지정가 물량을 쌓아 적의 돌격을 받아낸다",
		"호가 칸을 누르면 그 가격에 지정가 주문. 상대 호가를 누르면 그 가격까지 돌격",
		"차트 패턴이 완성되면 스킬 카드 획득. %d분 안에 써야 한다" % BattleEngine.CARD_LIFETIME,
		"적 진영 패턴은 %d분 뒤 자동 발동. 벽을 두껍게 쌓으면 덜 뚫린다" % BattleEngine.ENEMY_WINDUP,
	]))
	var skills := PackedStringArray()
	for skill: Skill in Skill.all():
		var color := WarStyle.hex(WarStyle.of(skill.faction()))
		skills.append("%s → [color=#%s][b]%s[/b][/color] [color=#%s]%s[/color]\n[color=#%s][font_size=13]%s[/font_size][/color]" % [
			ChartPatterns.label(skill.pattern), color, skill.name, WarStyle.hex(WarStyle.GOLD), "★".repeat(skill.tier()),
			WarStyle.hex(WarStyle.MUTED), skill.description])
	box.add_child(_rich_card("차트 패턴 = 스킬", "패턴이 완성되는 순간, 그 방향의 진영이 한 방향으로 호가를 쓸어버린다\n\n" + "\n".join(skills)))
	box.add_child(_rule_card("전장 이벤트", [
		"공시: 유상증자·무상증자·합병·자사주·블록딜·CB·실적·공급계약",
		"루머와 조회공시 답변, 결과 발표를 기다리는 긴장 구간",
		"매크로·세계정세: 금리·CPI·환율·사이드카·전쟁·무역협상",
		"어떤 공시는 전장에 성벽을 세운다 (합병 매수청구가, 유증 신주 물량 등)",
	]))
	return scroll


func _rule_card(title: String, lines: Array) -> Control:
	var text := ""
	for line: String in lines:
		text += "•  %s\n" % line
	return _rich_card(title, text.strip_edges())


func _rich_card(title: String, bbcode: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", WarStyle.box(Color(WarStyle.PANEL, 0.6), Color(0, 0, 0, 0), 12, 0, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(WarStyle.label(title, 19, Color.WHITE, true))
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.add_theme_font_size_override("normal_font_size", 15)
	rich.add_theme_font_size_override("bold_font_size", 15)
	rich.add_theme_constant_override("line_separation", 4)
	rich.text = bbcode
	box.add_child(rich)
	return panel


func _reroll() -> void:
	var others := Company.roster().filter(func(c: Company) -> bool: return c.name != company.name)
	company = others[randi() % others.size()]
	_show_company()


func _show_company() -> void:
	_name_label.text = "%s · %s" % [company.name, company.sector]
	for child in _price_row.get_children():
		child.queue_free()
	var base := company.base_price
	for spec in [["기준가", base, Color.WHITE], ["상한가", Krx.upper_limit(base), WarStyle.BULL], ["하한가", Krx.lower_limit(base), WarStyle.BEAR]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(WarStyle.label(spec[0], 14, WarStyle.MUTED))
		col.add_child(WarStyle.label(Krx.format_number(spec[1]), 24, spec[2], true))
		_price_row.add_child(col)

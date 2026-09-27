extends TestCase
## 화면을 실제로 띄워 관심종목 → 전투 → 결산까지 흘려 본다 (헤드리스).


func _main() -> Control:
	Record.path = "user://test_record.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Record.path))
	var main: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	tree.root.push_input(event)


func test_lobby_to_battle() -> void:
	var main := _main()
	await _frames(2)
	var lobby: Lobby = main.current_screen()
	check(lobby is Lobby, "관심종목부터 시작")
	var join: Button = lobby.find_child("JoinBear", true, false)
	check(join != null, "팔자 버튼")
	join.pressed.emit()
	await _frames(2)
	var battle: BattleScreen = main.current_screen()
	check(battle is BattleScreen, "전투 화면으로")
	eq(battle.engine.faction, War.Faction.BEAR)
	eq(battle.engine.phase, BattleEngine.Phase.PREOPEN, "장전 동시호가부터")
	main.queue_free()
	await _frames(1)


func test_keys_drive_the_battle() -> void:
	var main := _main()
	await _frames(1)
	var battle: BattleScreen = main.start_battle(Company.new("모두전자", "전자부품", 12000), War.Faction.BULL, 4)
	await _frames(2)
	battle.advance(BattleEngine.OPEN_TICK + 1)
	_key(KEY_2)
	await _frames(1)
	eq(battle._orders.fraction, 0.25, "2번 키는 25%")
	_key(KEY_A)
	await _frames(2)
	check(battle.engine.account.position > 0, "A로 시장가 매수")
	_key(KEY_S)
	await _frames(2)
	check(battle.engine.book.player_open_quantity(OrderBook.Side.BUY) > 0, "S로 벽")
	_key(KEY_F)
	await _frames(2)
	eq(battle.engine.book.player_open_quantity(OrderBook.Side.BUY), 0, "F로 취소")
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.GOLDEN_CROSS))
	_key(KEY_Q)
	await _frames(3)
	eq(battle.engine.skills_used, 1, "Q로 스킬")
	check(not battle._tower._beam.is_empty(), "빛기둥 연출")
	_key(KEY_SPACE)
	await _frames(1)
	check(battle._paused, "Space로 멈춤")
	_key(KEY_F1)
	await _frames(1)
	eq(battle._overlay_kind, "help")
	_key(KEY_F1)
	await _frames(2)
	check(battle._overlay == null, "F1로 닫힘")
	main.queue_free()
	await _frames(1)


func test_full_day_result_and_record() -> void:
	var main := _main()
	await _frames(1)
	var battle: BattleScreen = main.start_battle(Company.new("모두전자", "전자부품", 12000), War.Faction.BEAR, 5)
	await _frames(1)
	battle.advance(BattleEngine.END_TICK)
	await _frames(2)
	check(battle.engine.is_over())
	eq(battle._overlay_kind, "result", "결산 창")
	eq(Record.load_record().plays, 1, "전적에 남는다")
	_key(KEY_ENTER)
	await _frames(2)
	var next: BattleScreen = main.current_screen()
	check(next != battle and next is BattleScreen, "Enter로 한 판 더")
	eq(next.engine.tick, 0)
	main.queue_free()
	await _frames(1)

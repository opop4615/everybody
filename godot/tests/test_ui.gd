extends TestCase
## 화면을 실제로 띄워 로비 → 전투 → 결과까지 흘려 본다 (헤드리스).


func _main() -> Control:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_lobby_join_and_fight() -> void:
	var main := _main()
	await _frames(2)
	var lobby: Lobby = main.current_screen()
	check(lobby is Lobby, "로비부터 시작")
	var join: Button = lobby.find_child("JoinBull", true, false)
	check(join != null, "매수군 합류 버튼")
	join.pressed.emit()
	await _frames(2)
	var battle: BattleScreen = main.current_screen()
	check(battle is BattleScreen, "전투 화면으로")
	eq(battle.engine.faction, War.Faction.BULL)
	battle.advance(5)
	await _frames(2)
	eq(battle.engine.clock(), "09:05")
	battle._act(battle.engine.attack(0.25))
	check(battle.engine.account.position > 0, "돌격으로 매수")
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.GOLDEN_CROSS))
	battle._refresh()
	await _frames(2)
	eq(battle._hand_box.get_child_count(), 1, "스킬 카드가 손에")
	var card: Button = battle._hand_box.get_child(0)
	card.pressed.emit()
	await _frames(3)
	eq(battle.engine.skills_used, 1)
	check(not battle._battlefield._blast.is_empty(), "스킬 연출 시작")
	main.queue_free()
	await _frames(1)


func test_full_day_shows_result_and_rematch() -> void:
	var main := _main()
	await _frames(1)
	var battle: BattleScreen = main.start_battle(Company.new("모두전자", "전자부품", 12000), War.Faction.BEAR, 5)
	await _frames(1)
	battle.advance(BattleEngine.TICKS_PER_DAY)
	await _frames(2)
	check(battle.engine.is_over())
	check(battle._overlay != null, "결과 창")
	battle.rematch_requested.emit()
	await _frames(2)
	var next: BattleScreen = main.current_screen()
	check(next != battle and next is BattleScreen, "새 전투")
	eq(next.engine.tick, 0)
	main.queue_free()
	await _frames(1)

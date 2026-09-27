extends SceneTree
## 화면 캡처: 관심종목·장전 동시호가·장중·스킬·장 마감 동시호가·결산을 PNG로 남긴다.
##   godot --path godot --script res://tools/capture.gd -- <저장 폴더> [시드]


func _initialize() -> void:
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(dir: String, file: String) -> void:
	await process_frame
	await process_frame
	var path := dir.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var seed_value: int = int(args[1]) if args.size() > 1 else 3
	Record.path = "user://capture_record.cfg"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.4)
	await _save(dir, "1_lobby.png")

	var battle: BattleScreen = main.start_battle(Company.new("모두전자", "전자부품", 12000), War.Faction.BULL, seed_value)
	battle._paused = true
	await _wait(0.2)
	battle.advance(4)
	battle._act(battle.engine.attack(0.25))
	battle.advance(2)
	await _wait(0.3)
	await _save(dir, "2_preopen.png")

	battle.advance(90)
	battle._act(battle.engine.place_wall(0.25))
	await _wait(0.5)
	battle._act(battle.engine.attack(0.25))
	await _wait(0.12)
	await _save(dir, "3_battle.png")

	battle.advance(30)
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.GOLDEN_CROSS))
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.DEAD_CROSS))
	battle._refresh()
	await _wait(0.5)
	await _save(dir, "4_threat.png")
	battle._act(battle.engine.use_skill(battle.engine.hand.size() - 1))
	await _wait(0.3)
	await _save(dir, "5_skill.png")

	battle.advance(BattleEngine.CLOSING_TICK + 6 - battle.engine.tick)
	await _wait(0.5)
	await _save(dir, "6_closing.png")
	battle.advance(10)
	await _wait(0.6)
	await _save(dir, "7_result.png")
	quit()

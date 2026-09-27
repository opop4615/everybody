extends SceneTree
## 화면 캡처: 로비·전투·스킬 발동 장면을 PNG로 저장한다 (렌더링 가능한 환경 필요).
##   godot --path godot --resolution 1600x900 --script res://tools/capture.gd -- <저장 폴더> [시드]


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
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(0.5)
	await _save(dir, "lobby.png")

	var battle: BattleScreen = main.start_battle(Company.new("모두전자", "전자부품", 12000), War.Faction.BULL, seed_value)
	await _wait(0.3)
	battle._paused = true
	battle.advance(95)
	battle._act(battle.engine.place_wall(0.25))
	battle.advance(2)
	battle._act(battle.engine.attack(0.25))
	await _wait(0.22)
	await _save(dir, "battle.png")

	battle.advance(40)
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.GOLDEN_CROSS))
	battle.engine.grant_skill(Skill.of(ChartPatterns.Pattern.DEAD_CROSS))
	battle._refresh()
	await _wait(0.4)
	await _save(dir, "threat.png")
	battle._act(battle.engine.use_skill(battle.engine.hand.size() - 1))
	await _wait(0.42)
	await _save(dir, "skill.png")

	battle.advance(BattleEngine.TICKS_PER_DAY)
	await _wait(0.4)
	await _save(dir, "result.png")
	quit()

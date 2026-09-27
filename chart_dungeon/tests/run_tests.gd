extends SceneTree
## 헤드리스 테스트 러너.
##   godot --headless --path chart_dungeon --script res://tests/run_tests.gd [-- trade run ...]

const SUITES := [
	"res://tests/test_data.gd",
	"res://tests/test_position.gd",
	"res://tests/test_trade.gd",
	"res://tests/test_run.gd",
	"res://tests/test_ui.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var tests := 0
	var checks := 0
	var only := Array(OS.get_cmdline_user_args())
	for path: String in SUITES:
		if not only.is_empty() and not only.any(func(word: String) -> bool: return path.contains(word)):
			continue
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append("%s: 스크립트를 불러오지 못했다" % path)
			continue
		var suite: TestCase = script.new()
		suite.tree = self
		for method in suite.get_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			suite.current = "%s::%s" % [path.get_file().get_basename(), method_name]
			tests += 1
			await suite.call(method_name)
			if suite.get("require_end") and not suite.ended.has(suite.current):
				suite.failures.append("%s: 끝까지 가지 못했다 (스크립트 오류?)" % suite.current)
		failures.append_array(suite.failures)
		checks += suite.checks
	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d checks, %d failures" % [tests, checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

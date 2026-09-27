extends SceneTree
## 헤드리스 테스트 러너.
##   godot --headless --path godot --script res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_krx.gd",
	"res://tests/test_order_book.gd",
	"res://tests/test_patterns.gd",
	"res://tests/test_engine.gd",
	"res://tests/test_ui.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures: Array[String] = []
	var tests := 0
	var checks := 0
	for path: String in SUITES:
		var suite: TestCase = load(path).new()
		suite.tree = self
		for method in suite.get_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			suite.current = "%s::%s" % [path.get_file().get_basename(), method_name]
			tests += 1
			await suite.call(method_name)
		failures.append_array(suite.failures)
		checks += suite.checks
	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d checks, %d failures" % [tests, checks, failures.size()])
	quit(1 if failures.size() > 0 else 0)

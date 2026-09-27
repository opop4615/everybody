class_name TestCase
extends RefCounted
## 아주 작은 테스트 베이스. test_로 시작하는 메서드를 러너가 차례로 부른다.

var failures: Array[String] = []
var current := ""
var checks := 0
## UI 테스트용 (러너가 넣어 준다).
var tree: SceneTree


func check(condition: bool, message := "") -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [current, message])


func eq(actual: Variant, expected: Variant, message := "") -> void:
	checks += 1
	var numeric := (actual is int or actual is float) and (expected is int or expected is float)
	var same: bool = (numeric or typeof(actual) == typeof(expected)) and actual == expected
	if not same:
		failures.append("%s: %s — 기대 %s, 실제 %s" % [current, message, str(expected), str(actual)])

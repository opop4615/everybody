class_name Forecast
extends RefCounted
## 하루의 시장 전망표.
##
## 방향 신호는 '맞을 확률'이 정해진 제보다. 역사 모드에서 내일 캔들은 이미 정해져 있으므로,
## 신호는 그 캔들을 정해진 확률로 맞히게 뽑는다. 여러 신호를 베이즈로 합친 값이 화면의 확률이다.
## 그래서 "상승 68%"라고 뜨는 날은 길게 보면 정말 68% 정도로 오른다.

## 신호: {source, says_up, accuracy, contrarian}
var signals: Array[Dictionary] = []
var true_up := true
var previous_close := 0.0
## 예상 변동폭 (최근 고저폭 평균 × 장세).
var expected := 0.0
var volatility := 1.0
var seed_key := ""
## 보스 규칙이나 뉴스로 붙는 한 줄 주의.
var flags: Array[String] = []


func _init(bar: Bar, previous: Bar, p_expected: float, p_seed_key: String) -> void:
	true_up = bar.close >= previous.close
	previous_close = previous.close
	expected = p_expected
	seed_key = p_seed_key


## 맞을 확률 accuracy 인 신호를 하나 더한다. contrarian 이면 '대중은 반대로 간다'는 역지표.
func add_signal(source: String, accuracy: float, contrarian := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [seed_key, source, signals.size()])
	var correct := rng.randf() < accuracy
	var points_up := true_up if correct else not true_up
	var says_up := (not points_up) if contrarian else points_up
	var entry := {"source": source, "says_up": says_up, "accuracy": accuracy, "contrarian": contrarian}
	signals.append(entry)
	return entry


func has_direction() -> bool:
	return not signals.is_empty()


## 오를 확률 (신호가 없으면 0.5).
func up_probability() -> float:
	var odds := 1.0
	for s in signals:
		var accuracy: float = clampf(s["accuracy"], 0.51, 0.97)
		var ratio := accuracy / (1.0 - accuracy)
		var points_up: bool = s["says_up"] != s["contrarian"]
		odds *= ratio if points_up else 1.0 / ratio
	return odds / (1.0 + odds)


func low() -> float:
	return previous_close - expected * volatility


func high() -> float:
	return previous_close + expected * volatility


func span() -> float:
	return expected * volatility

class_name Notes
extends RefCounted
## 투자 노트 진행. 판이 끝나도 남는다 (user://notes.json).

signal learned(id: String, level: int)

const RANKS := [[0, "개미"], [10, "파생상품투자권유자문인력"], [22, "투자자산운용사"], [34, "금융투자분석사"]]
## 쓰거나 겪은 횟수가 이만큼 되면 그 단계까지 오른다.
const USE_STEPS := [1, 4]

var path := "user://notes.json"
var autosave := true
var levels := {}
var uses := {}
## 이번 판에 새로 알게 된 항목 (배지용).
var fresh: Array[String] = []


func level(id: String) -> int:
	return int(levels.get(id, 0))


## 적어도 to_level 단계까지 올린다. 올랐으면 true.
func learn(id: String, to_level := 1) -> bool:
	if not NoteDB.ENTRIES.has(id):
		return false
	var cap := _cap(id)
	var target := mini(to_level, cap)
	if level(id) >= target:
		return false
	levels[id] = target
	if not fresh.has(id):
		fresh.append(id)
	learned.emit(id, target)
	_save()
	return true


## 한 단계 올린다 (공부, 퀴즈).
func study(id: String) -> bool:
	return learn(id, level(id) + 1)


## 카드를 쓰거나 일을 겪을 때마다 센다.
func use(id: String) -> bool:
	if id.is_empty() or not NoteDB.ENTRIES.has(id):
		return false
	uses[id] = int(uses.get(id, 0)) + 1
	var count: int = uses[id]
	var reached := 0
	for i in USE_STEPS.size():
		if count >= USE_STEPS[i]:
			reached = i + 1
	return learn(id, reached)


func known_count() -> int:
	var count := 0
	for id: String in levels:
		if level(id) > 0:
			count += 1
	return count


func stars() -> int:
	var total := 0
	for id: String in levels:
		total += level(id)
	return total


func rank_name() -> String:
	var name: String = RANKS[0][1]
	for step: Array in RANKS:
		if known_count() >= step[0]:
			name = step[1]
	return name


## [다음 등급 이름, 필요한 항목 수]. 마지막 등급이면 ["", 0].
func next_rank() -> Array:
	for step: Array in RANKS:
		if known_count() < step[0]:
			return [step[1], step[0]]
	return ["", 0]


## 단계 설명이 있는 만큼만 오른다.
func _cap(id: String) -> int:
	var texts: Array = NoteDB.ENTRIES[id]["texts"]
	var cap := 0
	for text: String in texts:
		if not text.is_empty():
			cap += 1
	return maxi(cap, 1)


func load_saved() -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		levels = data.get("levels", {})
		uses = data.get("uses", {})


func reset() -> void:
	levels = {}
	uses = {}
	fresh.clear()
	_save()


func _save() -> void:
	if not autosave:
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"levels": levels, "uses": uses}))

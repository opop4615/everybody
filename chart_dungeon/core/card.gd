class_name Card
extends RefCounted
## 덱에 든 카드 한 장.

static var _next_uid := 1

var id: String
var upgraded := false
var uid: int
## 턴이 끝나면 사라지는 카드 (패턴 스킬).
var ethereal := false


func _init(p_id := "", p_upgraded := false) -> void:
	id = p_id
	upgraded = p_upgraded
	uid = _next_uid
	_next_uid += 1
	ethereal = def().get("ethereal", false)


func def() -> Dictionary:
	return CardDB.DEFS.get(id, {})


func name() -> String:
	return def().get("name", id) + ("+" if upgraded else "")


func type() -> String:
	return def().get("type", "entry")


func rarity() -> int:
	return def().get("rarity", 0)


func base_cost() -> int:
	var d := def()
	if upgraded and d.has("cost_up"):
		return d["cost_up"]
	return d.get("cost", 1)


func playable() -> bool:
	return not def().get("unplayable", false)


func is_entry() -> bool:
	return type() in ["long", "short", "entry"] or def().get("entry", false)


func is_habit() -> bool:
	return type() == "habit"


func can_upgrade() -> bool:
	return not upgraded and not is_habit() and type() != "pattern"


## 강화 값이 있으면 그것을, 없으면 기본 값을.
func value(key: String, fallback: Variant = 0) -> Variant:
	var d := def()
	if upgraded and d.has(key + "_up"):
		return d[key + "_up"]
	return d.get(key, fallback)


func copy() -> Card:
	return Card.new(id, upgraded)

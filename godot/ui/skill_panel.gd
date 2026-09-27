class_name SkillPanel
extends Control
## [0305] 스킬 카드. 한 줄에 한 장: 단축키, 패턴, 세기, 남은 시간.

signal use_requested(index: int)

const KEYS := ["Q", "W", "E"]
const ROW := 15

var engine: BattleEngine
var _hover := -1


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var row := int(motion.position.y / ROW)
		if row != _hover:
			_hover = row
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var row := int(click.position.y / ROW)
		if engine != null and row < engine.hand.size():
			use_requested.emit(row)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()


func _draw() -> void:
	if engine == null:
		return
	for i in 3:
		var r := Rect2(0, i * ROW, size.x, ROW - 1)
		if i < engine.hand.size():
			var card: BattleEngine.SkillCard = engine.hand[i]
			var bull := card.skill.faction() == War.Faction.BULL
			var face := Color("#f5d2d2") if bull else Color("#d2dcf5")
			if i == _hover:
				face = face.lightened(0.4)
			Hts.bevel(self, r, true, face)
			var ink := Hts.UP.darkened(0.25) if bull else Hts.DOWN.darkened(0.25)
			Hts.text(self, r.position + Vector2(4, 0), KEYS[i], Hts.INK, 12, true)
			Hts.text(self, r.position + Vector2(16, 0), card.skill.name, ink, 12, true)
			Hts.text(self, r.position + Vector2(16 + Hts.text_width(card.skill.name) + 6, 0), "★".repeat(card.skill.tier()), Color("#c08a00"))
			var left := card.expires_at - engine.tick
			Hts.text(self, r.position + Vector2(0, 0), "%d분" % left, Hts.UP if left <= 5 else Hts.SUB, 12, false,
				HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5)
		else:
			Hts.well(self, r, Hts.FACE.darkened(0.04))
			if i == 0 and engine.hand.is_empty():
				Hts.text(self, r.position + Vector2(4, 0), "차트 패턴이 나오면 카드가 생긴다", Hts.SUB)

class_name HtsWindow
extends Control
## HTS 창 하나: 입체 테두리, 남색 제목줄, 그 안에 내용 하나.
##   [0101] 현재가·호가 처럼 화면 번호를 달고 다닌다.

const TITLE_H := 14
const EDGE := 3

var title := ""
var active := true
var content: Control


func _init(p_title := "", p_content: Control = null) -> void:
	title = p_title
	if p_content != null:
		set_content(p_content)


func _ready() -> void:
	resized.connect(_layout)
	_layout()


func set_content(control: Control) -> void:
	if content != null:
		content.queue_free()
	content = control
	add_child(control)
	_layout()


func _layout() -> void:
	if content != null:
		content.position = Vector2(EDGE, EDGE + TITLE_H + 1)
		content.size = Vector2(maxf(0, size.x - EDGE * 2), maxf(0, size.y - EDGE * 2 - TITLE_H - 1))
	queue_redraw()


func _draw() -> void:
	Hts.bevel(self, Rect2(Vector2.ZERO, size), true)
	Hts.title_bar(self, Rect2(EDGE, EDGE, size.x - EDGE * 2, TITLE_H), title, active)
	# 오른쪽 위 창 단추 셋 (장식)
	var bx := size.x - EDGE - 3 * 13
	for i in 3:
		var r := Rect2(bx + i * 13, EDGE + 2, 11, 10)
		Hts.bevel(self, r, true)
		var mark: String = ["_", "□", "x"][i]
		Hts.text(self, r.position + Vector2(0, -3), mark, Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

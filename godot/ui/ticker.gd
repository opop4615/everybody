class_name Ticker
extends Control
## 전광판: 검은 띠에 노란 글자가 흘러간다. 지수와 방금 나온 뉴스.

var text := ""
var _offset := 0.0


func _process(delta: float) -> void:
	_offset += delta * 38.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0c0c0c"))
	if text.is_empty():
		return
	var gap := "      "
	var line := text + gap
	var w := Hts.text_width(line)
	if w <= 0:
		return
	var x := -fmod(_offset, w)
	while x < size.x:
		Hts.text(self, Vector2(roundf(x), -2), line, Hts.LED)
		x += w
	# 가장자리 LED 격자 느낌
	for gx in range(0, int(size.x), 2):
		draw_rect(Rect2(gx, 0, 1, size.y), Color(0, 0, 0, 0.18))

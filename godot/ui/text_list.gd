class_name TextList
extends Control
## 흰 바탕 목록 (뉴스, 토론방). 줄이 넘치면 접어서 다음 줄로.
## newest_first면 새 줄이 위에, 아니면 채팅처럼 아래에 쌓인다.

## 한 줄: [[글자, 색], [글자, 색], ...] 조각 목록.
var entries: Array = []
var newest_first := true


func set_entries(list: Array) -> void:
	entries = list
	queue_redraw()


func _draw() -> void:
	Hts.well(self, Rect2(Vector2.ZERO, size))
	var width := size.x - 8
	var blocks := []
	var used := 0.0
	for entry: Array in entries:
		var lines := _wrap(entry, width)
		var height := lines.size() * Hts.LINE
		if used + height > size.y - 4:
			break
		blocks.append(lines)
		used += height
	var y := 1.0 if newest_first else size.y - 3 - used
	if not newest_first:
		blocks.reverse()
	for lines: Array in blocks:
		for line: Array in lines:
			var x := 4.0
			for piece: Array in line:
				Hts.text(self, Vector2(x, y), piece[0], piece[1], 12, piece.size() > 2 and piece[2])
				x += Hts.text_width(piece[0])
			y += Hts.LINE


## 조각들을 폭에 맞게 줄로 나눈다. 글자 단위로 자른다 (한글이라 단어 경계가 덜 중요하다).
func _wrap(pieces: Array, width: float) -> Array:
	var lines := [[]]
	var x := 0.0
	for piece: Array in pieces:
		var text: String = piece[0]
		var chunk := ""
		for ch in text:
			var cw := Hts.char_width(ch)
			if x + cw > width and x > 0:
				if not chunk.is_empty():
					var done := piece.duplicate()
					done[0] = chunk
					lines.back().append(done)
					chunk = ""
				lines.append([])
				x = 0.0
			chunk += ch
			x += cw
		if not chunk.is_empty():
			var last := piece.duplicate()
			last[0] = chunk
			lines.back().append(last)
	return lines

class_name Desktop
extends Control
## HTS 바탕: 점무늬 배경, 맨 위 메뉴줄, 맨 아래 메시지줄.

const MENU_H := 13
const STATUS_H := 12

## 메뉴줄 오른쪽 글자 (시계, 장 상태).
var right_text := ""
var right_color := Hts.INK
## 메시지줄 왼쪽: 방금 일어난 일.
var message := ""
var message_color := Hts.INK
## 메시지줄 오른쪽: 단축키 안내.
var hint := "F1 도움말"


static var _dots: Texture2D


static func _dot_texture() -> Texture2D:
	if _dots == null:
		var image := Image.create(4, 8, false, Image.FORMAT_RGBA8)
		image.fill(Hts.DESK)
		image.set_pixel(0, 0, Hts.DESK_DOT)
		image.set_pixel(2, 4, Hts.DESK_DOT)
		_dots = ImageTexture.create_from_image(image)
	return _dots


func _draw() -> void:
	draw_texture_rect(_dot_texture(), Rect2(0, MENU_H, size.x, size.y - MENU_H - STATUS_H), true)
	# 메뉴줄
	draw_rect(Rect2(0, 0, size.x, MENU_H), Hts.FACE)
	draw_rect(Rect2(0, MENU_H - 1, size.x, 1), Hts.SHADOW)
	Hts.text(self, Vector2(4, -1), "모두증권 HTS", Hts.INK, 12, true)
	var x := Hts.text_width("모두증권 HTS") + 18.0
	for word in ["화면", "시세", "주문", "차트", "뉴스", "도움말"]:
		Hts.text(self, Vector2(x, -1), word, Hts.INK)
		x += Hts.text_width(word) + 12
	Hts.text(self, Vector2(0, -1), right_text, right_color, 12, true, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5)
	# 메시지줄
	var y := size.y - STATUS_H
	draw_rect(Rect2(0, y, size.x, STATUS_H), Hts.FACE)
	draw_rect(Rect2(0, y, size.x, 1), Hts.LIGHT)
	var hint_w := Hts.text_width(hint) + 12
	Hts.well(self, Rect2(2, y + 1, size.x - hint_w - 6, STATUS_H - 1), Hts.FACE)
	Hts.text(self, Vector2(5, y - 2), message, message_color)
	Hts.text(self, Vector2(size.x - hint_w, y - 2), hint, Hts.SUB, 12, false, HORIZONTAL_ALIGNMENT_RIGHT, hint_w - 4)

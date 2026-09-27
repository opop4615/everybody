class_name Sprites
extends RefCounted
## 데스크 팀원 도트 그림. 파일 없이 글자 격자로 그린다.
##   "analyst_bull" 처럼 모양_편. 편(bull/bear/gold)에 따라 옷 색이 바뀐다.

const SIDES := {
	"bull": {"a": Color8(214, 58, 58), "b": Color8(134, 30, 36), "c": Color8(245, 138, 124)},
	"bear": {"a": Color8(52, 96, 214), "b": Color8(28, 44, 134), "c": Color8(134, 168, 245)},
	"gold": {"a": Color8(242, 194, 48), "b": Color8(170, 120, 20), "c": Color8(255, 228, 136)},
}

const BASE := {
	"k": Color8(27, 27, 34), "s": Color8(242, 199, 160), "S": Color8(206, 150, 112), "w": Color8(255, 255, 255),
	"g": Color8(200, 206, 220), "h": Color8(110, 118, 138), "y": Color8(242, 194, 48), "Y": Color8(170, 120, 20),
	"n": Color8(106, 76, 40), "t": Color8(210, 182, 122), "G": Color8(63, 155, 90), "D": Color8(36, 96, 58),
	"L": Color8(140, 205, 150), "e": Color8(111, 134, 166), "E": Color8(63, 82, 112), "f": Color8(220, 228, 238),
	"r": Color8(220, 40, 40), "o": Color8(160, 210, 240), "z": Color8(245, 240, 225), "u": Color8(58, 96, 214),
}

const GRIDS := {
	# 개미: 떼로 다니는 개인 투자자. 머리띠가 편 색.
	"ant": [
		"..........k..k",
		"...........kk.",
		"..kkkk....aaaa",
		".kkkkkk..kkkkk",
		"kkkkkkkk.kkwkk",
		"kkkkkkkkkkkkkk",
		".kkkkkk.kkkkk.",
		"..kk..k.k..k..",
		".k..k.k..k..k.",
		"k....k....k...",
	],
	# 기관: 투구와 큰 방패 (방패에 막대그래프).
	"inst": [
		"....hhhh......",
		"...hggggh.....",
		"...hkkkkh.....",
		"...hggggh.....",
		"....hhhh......",
		"..aaaaaa.ggggg",
		".aaaaaaagwwwwg",
		".aaaaaaagwwywg",
		".aaaaaaagwyywg",
		"..aaaaaagyyywg",
		"..aaaaaa.ggggg",
		"...b..b...ggg.",
		"...b..b.......",
		"..bb..bb......",
	],
	# 외국인: 어디든 날아오는 비행선.
	"airship": [
		"....kkkkkkkk....",
		"..kkcccccccckk..",
		".kccaaaaaaaacck.",
		"kcaaaaawwaaaaack",
		"kaaaaawuuwaaaaak",
		"kaaaaawuuwaaaaak",
		".kaaaaawwaaaaak.",
		"..kkaaaaaaaakk..",
		"....kkkkkkkk....",
		".....k....k.....",
		"....nnnnnnnn....",
		".....nttttn.....",
	],
	# 애널리스트: 리포트 한 장.
	"analyst": [
		"....kkkk......",
		"...kkkkkk.....",
		"...kssssk.....",
		"...owkowk.....",
		"...ssssss.....",
		"....sSSs......",
		"..aaawaaa.zzzz",
		".aaaawaaaszrzz",
		".aaaawaaa.zzrz",
		".aa.awa.a.zrzz",
		"....aaaa..zzzz",
		"....b..b......",
		"....b..b......",
		"...bb..bb.....",
	],
	# 브로커: 전화기를 든 일꾼.
	"lp": [
		"...yyyyy......",
		"..yyyyyyy.....",
		"...ssssss.....",
		"...sksks......",
		"...ssssss.....",
		"..hyhhhyh.ntn.",
		".hhyhhhyhntttn",
		".hhyhhhyhhtttn",
		".s.hhhhh.ntttn",
		"...hhhhh..nnn.",
		"...b...b......",
		"...b...b......",
		"..bb...bb.....",
	],
	# 고래: 한 번에 들어왔다 빠지는 큰손.
	"whale": [
		"..............w.w.",
		"...............w..",
		"......aaaaaaaa....",
		"...aaaaaaaaaaaaa..",
		".aaaaaaaaaaaaakaa.",
		"aaaaaaaaaaaaaaaaaa",
		".aa.aacccccccccaaa",
		"aa...acccccccccaa.",
		"a......aaaaaaaaa..",
	],
	# 거북: 느리고 단단한 연기금.
	"turtle": [
		"....DDDDDD......",
		"..DDGLGGLGDD....",
		".DGGLGGGGLGGD...",
		"DGLGGGLGGGGLGD..",
		"DGGGGLGGGLGGGDLL",
		"DDDDDDDDDDDDDLLk",
		".tttttttttttt.LL",
		"..LL..LL..LL..L.",
		"..LL..LL..LL....",
	],
}

static var _cache := {}


## "analyst_bull" → 텍스처. 없는 이름이면 null.
static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var parts := key.split("_")
	var shape := parts[0]
	var side := parts[1] if parts.size() > 1 else "bull"
	if not GRIDS.has(shape):
		return null
	var rows: Array = GRIDS[shape]
	var colors := BASE.duplicate()
	colors.merge(SIDES.get(side, SIDES["bull"]), true)
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var image := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if colors.has(ch):
				image.set_pixel(x, y, colors[ch])
	var tex := ImageTexture.create_from_image(image)
	_cache[key] = tex
	return tex


## 정수 배율로 키운 TextureRect.
static func rect(key: String, scale := 3) -> TextureRect:
	var node := TextureRect.new()
	node.texture = texture(key)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if node.texture:
		node.custom_minimum_size = node.texture.get_size() * scale
	return node


## 밝은 판 위에 올린 초상 (검은 개미도 어두운 화면에서 보이게).
static func portrait(key: String, scale := 3) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Look.box(Color("2c3a4f"), Look.LINE_2, 6, 1, 4))
	frame.add_child(rect(key, scale))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return frame

class_name PixelArt
## 손으로 찍은 도트 그림. 글자 하나가 픽셀 하나다.
##
##   .  투명        k  검정 윤곽      s  살색         w  흰색
##   a  편 색       b  편 어두운 색   c  편 밝은 색
##   g  강철        h  강철 어두운 색 n  모래주머니 테두리  t  모래주머니

## 오른쪽을 보고 선 병사. 창을 들고 층을 지킨다.
const SOLDIER := [
	["..aaa.w",
	".aaaaah",
	"..ssk.h",
	"..sss.h",
	".baaash",
	".baaa.h",
	"..aaa.h",
	"..b.b..",
	"..b.b.."],
	["..aaa.w",
	".aaaaah",
	"..ssk.h",
	"..sss.h",
	".baaash",
	".baaa.h",
	"..aaa.h",
	"..b.b..",
	".b...b."],
]

## 달리는 병사 (계단을 오르내린다).
const RUNNER := [
	["...aaa.",
	"..aaaaa",
	"...ssk.",
	"...sss.",
	"..baaas",
	".baaa..",
	"..aaa..",
	".b...b.",
	"b.....b"],
	["...aaa.",
	"..aaaaa",
	"...ssk.",
	"...sss.",
	"..baaas",
	".baaa..",
	"..aaa..",
	"..b.b..",
	"..b.b.."],
]

## 개미. 머리에 편 색 머리띠.
const ANT := [
	["......k.",
	"......aa",
	".kkk.kkk",
	"kkkkkkkk",
	".k.k.k.."],
	["......k.",
	"......aa",
	".kkk.kkk",
	"kkkkkkkk",
	"k.k.k..."],
]

## 기관: 투구와 큰 방패.
const KNIGHT := [
	["..hhh...",
	".hgggh..",
	".hkkkh..",
	"..hhh...",
	".aaaaggg",
	".aaaagag",
	"..aaaggg",
	"..b..b..",
	"..b..b.."],
	["..hhh...",
	".hgggh..",
	".hkkkh..",
	"..hhh...",
	".aaaaggg",
	".aaaagag",
	"..aaaggg",
	"..b.b...",
	".b...b.."],
]

## 외국인: 깃털 투구에 긴 창.
const LANCER := [
	[".cc.....",
	"..caa...",
	".aaaa..w",
	"..ssk.h.",
	"..sss.h.",
	".baaash.",
	".baaah..",
	"..aah...",
	"..b.b...",
	"..b.b..."],
	[".cc.....",
	"..caa...",
	".aaaa..w",
	"..ssk.h.",
	"..sss.h.",
	".baaash.",
	".baaah..",
	"..aah...",
	".b...b..",
	"b.....b."],
]

## 세력: 고래.
const WHALE := [
	["...........w.w..",
	"............w...",
	"....aaaaaaaa....",
	"..aaaaaaaaaaaa..",
	"aaaaaaaaaaaakaa.",
	".aa.aacccccccaaa",
	"aa...acccccccaa.",
	"a......aaaaaa..."],
	["................",
	"...........w.w..",
	"....aaaaaaaa....",
	"..aaaaaaaaaaaa..",
	"aaaaaaaaaaaakaa.",
	"aa..aacccccccaaa",
	".aa..acccccccaa.",
	"........aaaaaa.."],
]

## 모래주머니 한 자루.
const SANDBAG := [
	[".nnnnnn.",
	"nttttttn",
	"nttttttn",
	".nnnnnn."],
]

const SIDE_PALETTES := {
	"bull": {"a": Color("#d23c3c"), "b": Color("#861c22"), "c": Color("#f58a7c")},
	"bear": {"a": Color("#3c64d2"), "b": Color("#1c2c86"), "c": Color("#86a8f5")},
	"me": {"a": Color("#f2c230"), "b": Color("#9a7410"), "c": Color("#ffe488")},
	"ghost": {"a": Color("#8c8c96"), "b": Color("#5a5a64"), "c": Color("#b4b4be")},
}

const BASE_PALETTE := {
	"k": Color("#16161c"), "s": Color("#f2c7a0"), "w": Color("#ffffff"),
	"g": Color("#c3c8d6"), "h": Color("#6f7589"), "n": Color("#6b5634"), "t": Color("#cdb27a"),
}

static var _cache := {}


## 그림 이름·편·프레임에 맞는 텍스처.
static func texture(sprite: String, palette: String, frame := 0) -> Texture2D:
	var key := "%s/%s/%d" % [sprite, palette, frame]
	if _cache.has(key):
		return _cache[key]
	var frames: Array = _frames(sprite)
	var rows: Array = frames[frame % frames.size()]
	var colors: Dictionary = BASE_PALETTE.duplicate()
	colors.merge(SIDE_PALETTES.get(palette, SIDE_PALETTES.ghost), true)
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
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


static func size_of(sprite: String) -> Vector2i:
	var rows: Array = _frames(sprite)[0]
	return Vector2i(rows[0].length(), rows.size())


static func _frames(sprite: String) -> Array:
	match sprite:
		"soldier":
			return SOLDIER
		"runner":
			return RUNNER
		"ant":
			return ANT
		"knight":
			return KNIGHT
		"lancer":
			return LANCER
		"whale":
			return WHALE
		"sandbag":
			return SANDBAG
	return SOLDIER


## 주문 주체 이름으로 돌격대 그림을 고른다.
static func sprite_for_tag(tag: String) -> String:
	match tag:
		"개미", "뉴스 매매":
			return "ant"
		"기관":
			return "knight"
		"외국인":
			return "lancer"
		"세력", "종가 관여":
			return "whale"
	return "runner"


## 텍스처를 그린다. flip이면 좌우를 뒤집는다.
static func draw(ci: CanvasItem, tex: Texture2D, pos: Vector2, flip := false, modulate := Color.WHITE) -> void:
	var p := pos.round()
	var s := tex.get_size()
	if flip:
		ci.draw_texture_rect(tex, Rect2(p.x + s.x, p.y, -s.x, s.y), false, modulate)
	else:
		ci.draw_texture(tex, p, modulate)

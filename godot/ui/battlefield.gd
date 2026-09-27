class_name Battlefield
extends Control
## 전투 공간. 호가 한 칸이 전장의 한 열이고, 그 칸의 잔량이 거기 서 있는 병력이다.
##
## 왼쪽은 매수 잔량(매수군), 오른쪽은 매도 잔량(매도군), 가운데가 현재가 = 전선.
## 시장가 주문은 뒤에서 달려와 전선에 부딪히는 돌격대로, 스킬은 한 방향으로
## 전장을 가로지르는 파도로 그린다. 맨 위 띠는 하한가~상한가 전체 전황도.

const COL_W := 48.0
const MAP_H := 54.0
const GROUND_H := 34.0
const SOLDIER_QTY := 0.2  ## 병사 한 명 = 표준 잔량의 0.2
const MAX_SOLDIERS := 30

var engine: BattleEngine

var _time := 0.0
var _scroll := 0.0
var _shown_price := 0
var _runners: Array = []
var _sparks: Array = []
var _floaters: Array = []
var _blast: Dictionary = {}
var _shake := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE
var _news: Dictionary = {}
var _news_serial := -1
var _clash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	_scroll = lerpf(_scroll, 0.0, 1.0 - exp(-7.0 * delta))
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 2.0)
	_clash = maxf(0.0, _clash - delta * 3.0)
	_update_runners(delta)
	_update_particles(delta)
	if not _blast.is_empty():
		_blast.t += delta / 1.1
		if _blast.t >= 1.0:
			_blast = {}
	if not _news.is_empty():
		_news.life -= delta
		if _news.life <= 0:
			_news = {}
	queue_redraw()


## 엔진이 한 분 진행했거나 플레이어가 주문한 뒤 부른다.
func sync() -> void:
	if engine == null:
		return
	if _shown_price != 0 and engine.last_price != _shown_price:
		_scroll += Krx.ticks_between(_shown_price, engine.last_price) * COL_W
		_scroll = clampf(_scroll, -size.x, size.x)
	_shown_price = engine.last_price
	# 여러 분을 한꺼번에 넘기면 마지막 몇 번만 그린다.
	var strikes := engine.take_strikes()
	for strike: BattleEngine.Strike in strikes.slice(maxi(0, strikes.size() - 8)):
		_spawn_squad(strike)
	var blasts := engine.take_blasts()
	if not blasts.is_empty():
		_start_blast(blasts.back())
	if engine.feed_serial != _news_serial:
		var fresh := mini(engine.feed_serial - _news_serial, engine.feed.size())
		_news_serial = engine.feed_serial
		for i in fresh:
			var item: BattleEngine.FeedItem = engine.feed[i]
			if item.kind == BattleEngine.FeedKind.NEWS:
				_news = {"label": item.label, "title": item.title, "tone": item.tone, "life": 4.0}
				break


# ── 좌표 ─────────────────────────────────────────────────────────

func _field_top() -> float:
	return MAP_H


func _ground_y() -> float:
	return size.y - GROUND_H


func _price_x(price: int) -> float:
	return size.x * 0.5 + Krx.ticks_between(engine.last_price, price) * COL_W + _scroll


## 매수 병력과 매도 병력 사이 경계.
func _front_x() -> float:
	var bid := engine.book.best_bid()
	var ask := engine.book.best_ask()
	if bid != OrderBook.NO_PRICE and ask != OrderBook.NO_PRICE:
		return (_price_x(bid) + _price_x(ask)) * 0.5
	if bid != OrderBook.NO_PRICE:
		return _price_x(bid) + COL_W * 0.5
	if ask != OrderBook.NO_PRICE:
		return _price_x(ask) - COL_W * 0.5
	return _price_x(engine.last_price)


# ── 연출 생성 ────────────────────────────────────────────────────

func _spawn_squad(strike: BattleEngine.Strike) -> void:
	if _runners.size() > 80:
		return
	var faction := War.of_side(strike.side)
	var dir := 1.0 if faction == War.Faction.BULL else -1.0
	var units := clampi(roundi(strike.quantity / (engine.depth_unit * 0.35)), 1, 12)
	var start_x := -30.0 if dir > 0 else size.x + 30.0
	var color := WarStyle.GOLD if strike.by_player else WarStyle.of(faction)
	for i in units:
		_runners.append({
			"x": start_x - dir * randf_range(0, 160),
			"y": _ground_y() - 4 - randf_range(0, 60),
			"dir": dir,
			"speed": randf_range(1300, 1700),
			"faction": faction,
			"color": color,
			"phase": randf() * TAU,
		})
	var big := strike.by_player or strike.quantity >= engine.depth_unit * 1.5
	if big and strike.tag != "개미" and _floaters.size() < 6:
		var text := "%s %s주" % [strike.tag, Krx.format_number(strike.quantity)]
		var lane := _floaters.filter(func(f: Dictionary) -> bool: return f.vx * dir > 0).size()
		_floaters.append({
			"text": text, "x": start_x + dir * 120, "y": _ground_y() - 150 - lane * 22,
			"vx": dir * 520.0, "life": 1.1, "color": color,
		})


func _start_blast(blast: BattleEngine.SkillBlast) -> void:
	var faction := blast.skill.faction()
	var moved := absi(Krx.ticks_between(blast.from, blast.to))
	_blast = {
		"name": blast.skill.name, "faction": faction, "t": 0.0,
		"by_player": blast.by_player, "moved": moved,
	}
	_shake = 1.0
	_flash = 0.6
	_flash_color = WarStyle.of(faction)


func _update_runners(delta: float) -> void:
	if engine == null:
		return
	var front := _front_x()
	var alive := []
	for r: Dictionary in _runners:
		r.x += r.dir * r.speed * delta
		r.phase += delta * 22.0
		var arrived: bool = (r.dir > 0 and r.x >= front - 8) or (r.dir < 0 and r.x <= front + 8)
		if arrived:
			_burst(Vector2(front, r.y - 10), r.color, 4)
			_clash = 1.0
		else:
			alive.append(r)
	_runners = alive


func _burst(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		var angle := randf_range(-PI, 0)
		_sparks.append({
			"p": at, "v": Vector2(cos(angle), sin(angle)) * randf_range(80, 260),
			"life": randf_range(0.25, 0.5), "color": color.lightened(0.3),
		})


func _update_particles(delta: float) -> void:
	var alive := []
	for s: Dictionary in _sparks:
		s.life -= delta
		if s.life > 0:
			s.v.y += 600 * delta
			s.p += s.v * delta
			alive.append(s)
	_sparks = alive
	var floating := []
	for f: Dictionary in _floaters:
		f.life -= delta
		f.x += f.vx * delta
		f.y -= 12 * delta
		if f.life > 0:
			floating.append(f)
	_floaters = floating


# ── 그리기 ───────────────────────────────────────────────────────

func _draw() -> void:
	if engine == null:
		return
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 7.0 * _shake * _shake
	draw_set_transform(shake)
	_draw_backdrop()
	_draw_armies()
	_draw_front()
	_draw_runners()
	_draw_particles()
	_draw_blast()
	draw_set_transform(Vector2.ZERO)
	_draw_map()
	_draw_banners()
	if _flash > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_color, 0.18 * _flash))


func _draw_backdrop() -> void:
	var top := _field_top()
	var ground := _ground_y()
	# 하늘
	var sky := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, ground), Vector2(0, ground)])
	draw_polygon(sky, PackedColorArray([Color("#081a33"), Color("#081a33"), Color("#1a3a64"), Color("#1a3a64")]))
	# 진영 쪽 노을: 전선 왼쪽은 붉게, 오른쪽은 푸르게
	var front := _front_x()
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(front, top), Vector2(front, ground), Vector2(0, ground)]),
		PackedColorArray([Color(WarStyle.BULL, 0.0), Color(WarStyle.BULL, 0.0), Color(WarStyle.BULL, 0.10), Color(WarStyle.BULL, 0.16)]))
	draw_polygon(PackedVector2Array([Vector2(front, top), Vector2(size.x, top), Vector2(size.x, ground), Vector2(front, ground)]),
		PackedColorArray([Color(WarStyle.BEAR, 0.0), Color(WarStyle.BEAR, 0.0), Color(WarStyle.BEAR, 0.16), Color(WarStyle.BEAR, 0.10)]))
	# 먼 산
	var hills := PackedVector2Array([Vector2(0, ground)])
	for i in 13:
		var x := size.x * i / 12.0
		hills.append(Vector2(x, ground - 60 - 30 * sin(i * 1.7) - 18 * sin(i * 0.6)))
	hills.append(Vector2(size.x, ground))
	draw_colored_polygon(hills, Color("#10284a"))
	# 땅과 가격 눈금
	draw_rect(Rect2(0, ground, size.x, GROUND_H), Color("#2a2a36"))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color("#4a4a5a"), 2)
	var font := WarStyle.regular()
	var half := int(size.x / COL_W / 2) + 2
	for offset in range(-half, half + 1):
		var price := Krx.shift_ticks(engine.last_price, offset)
		if price > engine.upper_limit or price < engine.lower_limit:
			continue
		var x := _price_x(price)
		var color := WarStyle.for_price(price, engine.base_price)
		draw_string(font, Vector2(x - COL_W * 0.5, ground + 21), Krx.format_number(price),
			HORIZONTAL_ALIGNMENT_CENTER, COL_W, 11, Color(color, 0.75))


func _draw_armies() -> void:
	var font := WarStyle.regular()
	var bold := WarStyle.bold()
	for level: OrderBook.BookLevel in engine.bids(14):
		_draw_column(level, War.Faction.BULL, font, bold)
	for level: OrderBook.BookLevel in engine.asks(14):
		_draw_column(level, War.Faction.BEAR, font, bold)


func _draw_column(level: OrderBook.BookLevel, faction: int, font: Font, bold: Font) -> void:
	var x := _price_x(level.price)
	if x < -COL_W or x > size.x + COL_W:
		return
	var ground := _ground_y()
	var unit := engine.depth_unit * SOLDIER_QTY
	var dir := 1.0 if faction == War.Faction.BULL else -1.0
	var y := ground
	# 특수 벽 (매수청구가·자사주·신주물량·스킬 벽): 전선 쪽에 성벽처럼 선다.
	var troops := level.quantity - level.wall_quantity
	if level.wall_quantity > 0:
		var wall_h := clampf(level.wall_quantity / float(engine.depth_unit) * 12.0, 18.0, 150.0)
		var wall := Rect2(x - COL_W * 0.42, ground - wall_h, COL_W * 0.84, wall_h)
		draw_rect(wall, Color("#6b6255"))
		for row in int(wall_h / 9):
			var by := ground - (row + 1) * 9
			draw_line(Vector2(wall.position.x, by), Vector2(wall.end.x, by), Color("#51493f"), 1)
			var shift := 8.0 if row % 2 == 0 else 0.0
			for bx in range(int(wall.position.x + shift), int(wall.end.x), 16):
				draw_line(Vector2(bx, by), Vector2(bx, by + 9), Color("#51493f"), 1)
		draw_rect(wall, WarStyle.of(faction), false, 2)
		draw_string(bold, Vector2(x - 40, wall.position.y - 6), level.wall_tag, HORIZONTAL_ALIGNMENT_CENTER, 80, 12, WarStyle.WARNING)
		y = wall.position.y - 18
	# 병사: 3열 종대로 아래부터 쌓는다. 내 물량은 금색.
	var count := clampi(ceili(troops / unit), 0, MAX_SOLDIERS) if troops > 0 else 0
	var mine := 0
	if level.player_quantity > 0 and troops > 0:
		mine = clampi(roundi(count * float(level.player_quantity) / troops), 1, count)
	var color := WarStyle.of(faction)
	for i in count:
		@warning_ignore("integer_division")
		var row := i / 3
		var col := i % 3
		var bob := sin(_time * 5.0 + level.price * 0.37 + i) * 1.2
		var pos := Vector2(x + (col - 1) * 13.0 - dir * (row % 2) * 3.0, y - 2 - row * 15.0 + bob)
		_draw_soldier(pos, faction, WarStyle.GOLD if i < mine else color, 0.95, false, 0.0)
	if count > 0:
		var top := y - 2 - ceili(count / 3.0) * 15.0 - 14
		draw_string(font, Vector2(x - COL_W * 0.5, top), Krx.format_number(level.quantity),
			HORIZONTAL_ALIGNMENT_CENTER, COL_W, 11, Color(1, 1, 1, 0.75))
		if mine > 0:
			_draw_flag(Vector2(x + dir * 16, top - 4), WarStyle.GOLD, "나")


func _draw_soldier(pos: Vector2, faction: int, color: Color, s: float, running: bool, phase: float) -> void:
	var dir := 1.0 if faction == War.Faction.BULL else -1.0
	var lean := dir * 3.0 * s if running else 0.0
	var swing := sin(phase) * 4.0 * s if running else 0.0
	var leg := color.darkened(0.35)
	draw_line(pos + Vector2(-2.5 * s, -5 * s), pos + Vector2(-2.5 * s - swing, 0), leg, 2.2 * s)
	draw_line(pos + Vector2(2.5 * s, -5 * s), pos + Vector2(2.5 * s + swing, 0), leg, 2.2 * s)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-4.5 * s, -5 * s), pos + Vector2(4.5 * s, -5 * s),
		pos + Vector2(4.5 * s + lean, -14 * s), pos + Vector2(-4.5 * s + lean, -14 * s)]), color)
	var head := pos + Vector2(lean * 1.3, -18 * s)
	if faction == War.Faction.BULL:
		var horn := Color("#f3e6c8")
		draw_colored_polygon(PackedVector2Array([head + Vector2(-2.5, -2) * s, head + Vector2(-7, -7) * s, head + Vector2(-0.5, -3.8) * s]), horn)
		draw_colored_polygon(PackedVector2Array([head + Vector2(2.5, -2) * s, head + Vector2(7, -7) * s, head + Vector2(0.5, -3.8) * s]), horn)
	else:
		draw_circle(head + Vector2(-3, -3) * s, 1.9 * s, color.darkened(0.25))
		draw_circle(head + Vector2(3, -3) * s, 1.9 * s, color.darkened(0.25))
	draw_circle(head, 4.0 * s, color.lightened(0.3))
	draw_circle(head + Vector2(dir * 1.6, -0.5) * s, 0.9 * s, Color("#10203a"))
	var hand := pos + Vector2(dir * 3 * s + lean, -10 * s)
	draw_line(hand - Vector2(dir * 3, -2) * s, hand + Vector2(dir * 10, -4) * s, Color("#d8dde6"), 1.3 * s)


func _draw_flag(at: Vector2, color: Color, text: String) -> void:
	draw_line(at, at + Vector2(0, 16), Color.WHITE, 1.5)
	draw_rect(Rect2(at.x, at.y, 18, 11), color)
	draw_string(WarStyle.bold(), Vector2(at.x, at.y + 9.5), text, HORIZONTAL_ALIGNMENT_CENTER, 18, 9, Color("#10203a"))


func _draw_front() -> void:
	var x := _front_x()
	var top := _field_top()
	var ground := _ground_y()
	var glow := 0.35 + 0.65 * _clash
	draw_rect(Rect2(x - 6, top, 12, ground - top), Color(1, 1, 1, 0.05 * glow))
	draw_line(Vector2(x, top + 10), Vector2(x, ground), Color(1, 1, 1, 0.35 + 0.5 * _clash), 2.0)
	draw_string(WarStyle.bold(), Vector2(x - 60, top + 26 + _banner_height()), "전선 %s" % Krx.format_number(engine.last_price),
		HORIZONTAL_ALIGNMENT_CENTER, 120, 13, WarStyle.for_price(engine.last_price, engine.base_price))


func _draw_runners() -> void:
	for r: Dictionary in _runners:
		_draw_soldier(Vector2(r.x, r.y), r.faction, r.color, 1.05, true, r.phase)
		draw_line(Vector2(r.x - r.dir * 10, r.y - 10), Vector2(r.x - r.dir * 26, r.y - 10), Color(r.color, 0.35), 2)
	if not _blast.is_empty():
		return
	var font := WarStyle.bold()
	for f: Dictionary in _floaters:
		var alpha := clampf(f.life * 2.0, 0.0, 1.0)
		draw_string_outline(font, Vector2(f.x - 80, f.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, 4, Color(0, 0, 0, 0.6 * alpha))
		draw_string(font, Vector2(f.x - 80, f.y), f.text, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(f.color, alpha))


func _draw_particles() -> void:
	for s: Dictionary in _sparks:
		var alpha := clampf(s.life * 3.0, 0.0, 1.0)
		draw_line(s.p, s.p - s.v * 0.03, Color(s.color, alpha), 2)


## 스킬: 진영 색 파도가 한 방향으로 전장을 가로지른다.
func _draw_blast() -> void:
	if _blast.is_empty():
		return
	var t: float = _blast.t
	var color := WarStyle.GOLD if _blast.by_player else WarStyle.of(_blast.faction)
	var dir := 1.0 if _blast.faction == War.Faction.BULL else -1.0
	var top := _field_top()
	var ground := _ground_y()
	var band := 260.0
	var head := lerpf(-band, size.x + band, t) if dir > 0 else lerpf(size.x + band, -band, t)
	var tail := head - dir * band * 1.6
	var fade := clampf((1.0 - t) * 1.6, 0.0, 1.0)
	var clear := Color(color, 0)
	var strong := Color(color, 0.55 * fade)
	draw_polygon(PackedVector2Array([Vector2(tail, top), Vector2(head, top), Vector2(head, ground), Vector2(tail, ground)]),
		PackedColorArray([clear, strong, strong, clear]))
	draw_line(Vector2(head, top), Vector2(head, ground), Color(Color.WHITE, 0.8 * fade), 4)
	for i in 9:
		var ly := top + 30 + i * (ground - top - 40) / 8.0
		var len := 60.0 + 40.0 * sin(i * 2.3)
		draw_line(Vector2(head - dir * 20, ly), Vector2(head - dir * (20 + len), ly), Color(Color.WHITE, 0.5 * fade), 2)
	var title_alpha := clampf(1.4 - t, 0.0, 1.0)
	var font := WarStyle.bold()
	var cy := top + (ground - top) * 0.42
	var label := ("내 " if _blast.by_player else "적 " if _blast.faction != engine.faction else "") + str(_blast.name)
	draw_string_outline(font, Vector2(0, cy), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, 10, Color(0, 0, 0, 0.7 * title_alpha))
	draw_string(font, Vector2(0, cy), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, Color(color.lightened(0.4), title_alpha))
	var arrow := "▶▶▶" if dir > 0 else "◀◀◀"
	draw_string(font, Vector2(0, cy + 38), "%s  %d호가 %s" % [arrow, _blast.moved, "돌파" if dir > 0 else "붕괴"],
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(Color.WHITE, title_alpha))


## 맨 위 전황도: 하한가(매수군 본진) ~ 상한가(매도군 본진).
func _draw_map() -> void:
	var font := WarStyle.regular()
	var bold := WarStyle.bold()
	draw_rect(Rect2(0, 0, size.x, MAP_H), Color("#06142a"))
	var left := 130.0
	var right := size.x - 130.0
	var bar_y := 30.0
	var lo := engine.lower_limit
	var hi := engine.upper_limit
	var px := func(price: float) -> float: return left + (right - left) * (price - lo) / float(hi - lo)
	var front: float = px.call(engine.last_price)
	draw_rect(Rect2(left, bar_y - 6, front - left, 12), Color(WarStyle.BULL, 0.55))
	draw_rect(Rect2(front, bar_y - 6, right - front, 12), Color(WarStyle.BEAR, 0.55))
	# 본진
	_draw_castle(Vector2(left - 26, bar_y + 8), WarStyle.BULL)
	_draw_castle(Vector2(right + 26, bar_y + 8), WarStyle.BEAR)
	draw_string(bold, Vector2(4, 20), "매수군 본진", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, WarStyle.BULL)
	draw_string(font, Vector2(4, 38), "하한가 " + Krx.format_number(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, WarStyle.MUTED)
	draw_string(bold, Vector2(size.x - 128, 20), "매도군 본진", HORIZONTAL_ALIGNMENT_RIGHT, 124, 12, WarStyle.BEAR)
	draw_string(font, Vector2(size.x - 128, 38), "상한가 " + Krx.format_number(hi), HORIZONTAL_ALIGNMENT_RIGHT, 124, 11, WarStyle.MUTED)
	# 기준가와 VI 관문
	var base_x: float = px.call(engine.base_price)
	draw_line(Vector2(base_x, bar_y - 11), Vector2(base_x, bar_y + 11), Color.WHITE, 2)
	draw_string(font, Vector2(base_x - 30, 12), "기준가", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color.WHITE)
	for gate in [engine.vi_anchor * 0.9, engine.vi_anchor * 1.1]:
		if gate > lo and gate < hi:
			var gx: float = px.call(gate)
			draw_dashed_line(Vector2(gx, bar_y - 12), Vector2(gx, bar_y + 12), WarStyle.WARNING, 2, 3)
			draw_string(font, Vector2(gx - 20, 12), "VI", HORIZONTAL_ALIGNMENT_CENTER, 40, 10, WarStyle.WARNING)
	# 내 평단
	if engine.account.position != 0:
		var ax: float = px.call(engine.account.average_price)
		draw_line(Vector2(ax, bar_y + 6), Vector2(ax, bar_y + 14), WarStyle.GOLD, 3)
		draw_string(font, Vector2(ax - 20, bar_y + 24), "평단", HORIZONTAL_ALIGNMENT_CENTER, 40, 9, WarStyle.GOLD)
	# 전선
	draw_colored_polygon(PackedVector2Array([Vector2(front - 7, bar_y - 16), Vector2(front + 7, bar_y - 16), Vector2(front, bar_y - 6)]), Color.WHITE)
	draw_string(bold, Vector2(front - 60, bar_y + 22), "%s (%s)" % [Krx.format_number(engine.last_price), Krx.signed_percent(engine.change_rate())],
		HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color.WHITE)


func _draw_castle(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at.x - 12, at.y - 18, 24, 18), color.darkened(0.2))
	for i in 3:
		draw_rect(Rect2(at.x - 12 + i * 9, at.y - 23, 6, 5), color.darkened(0.2))
	draw_rect(Rect2(at.x - 4, at.y - 9, 8, 9), Color("#06142a"))


## 위쪽 알림 띠(뉴스·적 스킬 경고)가 차지하는 높이.
func _banner_height() -> float:
	return (42.0 if not _news.is_empty() else 0.0) + 38.0 * engine.incoming.size()


func _draw_banners() -> void:
	var font := WarStyle.regular()
	var bold := WarStyle.bold()
	var y := MAP_H + 8
	if not _news.is_empty():
		var slide := clampf((4.0 - _news.life) * 4.0, 0.0, 1.0)
		var alpha := clampf(_news.life, 0.0, 1.0)
		var rect := Rect2(12 - (1.0 - slide) * 60, y, size.x - 24, 34)
		draw_rect(rect, Color(0, 0, 0, 0.55 * alpha))
		var tone_color := WarStyle.of(_news.tone) if _news.tone != War.NEUTRAL else Color.WHITE
		draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), Color(tone_color, alpha))
		var label := "[%s]" % _news.label
		draw_string(bold, rect.position + Vector2(16, 23), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(tone_color, alpha))
		var label_w := bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(font, rect.position + Vector2(26 + label_w, 23), _news.title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - label_w - 40, 16, Color(1, 1, 1, alpha))
		y += 42
	for threat: BattleEngine.IncomingSkill in engine.incoming:
		var wait := threat.fires_at - engine.tick
		var pulse := 0.6 + 0.4 * sin(_time * 8.0)
		var text := "경고  적 %s 「%s」 %s — 벽을 쌓아 막아라! (S)" % [
			War.label(threat.skill.faction()), threat.skill.name, "%d분 뒤 발동" % wait if wait > 0 else "곧 발동"]
		var rect := Rect2(size.x * 0.5 - 330, y, 660, 32)
		draw_rect(rect, Color(WarStyle.WARNING, 0.16 * pulse))
		draw_rect(rect, Color(WarStyle.WARNING, pulse), false, 2)
		draw_string(bold, rect.position + Vector2(0, 22), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, WarStyle.WARNING)
		y += 38
	var center := Vector2(0, _field_top() + (_ground_y() - _field_top()) * 0.3)
	if engine.in_vi():
		draw_rect(Rect2(0, _field_top(), size.x, _ground_y() - _field_top()), Color(1, 1, 1, 0.07))
		var text := "VI 발동 — %d분간 휴전 (단일가 매매 · 벽 쌓기만 가능)" % engine.vi_remaining
		draw_string_outline(bold, center, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, 8, Color(0, 0, 0, 0.7))
		draw_string(bold, center, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, WarStyle.WARNING)
	var hold := ""
	var hold_color := Color.WHITE
	if engine.upper_hold > 0:
		hold = "상한가! 매도군 본진 함락까지 %d/%d분" % [engine.upper_hold, BattleEngine.LIMIT_HOLD_TO_WIN]
		hold_color = WarStyle.BULL
	elif engine.lower_hold > 0:
		hold = "하한가! 매수군 본진 함락까지 %d/%d분" % [engine.lower_hold, BattleEngine.LIMIT_HOLD_TO_WIN]
		hold_color = WarStyle.BEAR
	if not hold.is_empty():
		draw_string_outline(bold, center + Vector2(0, 40), hold, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, 8, Color(0, 0, 0, 0.7))
		draw_string(bold, center + Vector2(0, 40), hold, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, hold_color)

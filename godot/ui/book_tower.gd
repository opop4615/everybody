class_name BookTower
extends Control
## [0101] 현재가·호가 창 본문.
##
## 왼쪽은 HTS 호가표, 오른쪽은 같은 줄에 맞춘 탑이다. 호가 한 줄이 탑의 한 층이고,
## 그 줄의 잔량이 그 층을 지키는 병력이다. 위 열 층은 팔자(매도) 진지, 아래 열 층은
## 사자(매수) 진지, 가운데 이음매가 체결가(전선)다.
##
## 시장가가 매도 호가 세 칸을 먹으면 위쪽 세 층이 무너지고 병사들이 떨어지며,
## 남은 탑이 세 칸 내려앉는다. 오른쪽 계단으로 돌격대가 오르내린다.

signal price_clicked(price: int)

const INFO_H := 30
const HEAD_H := 13
const ROW_H := 11
const ROWS := 20
const FOOT_H := 13
const TABLE_W := 222
const COLS := [0, 72, 150, 222]
const SHAFT_W := 30
## 병사 한 명 = 표준 잔량의 0.15
const UNIT_QTY := 0.07
const MAX_UNITS := 34
const UNIT_STEP := 8

const BRICK := Color("#1c1f2e")
const BRICK_LINE := Color("#252a3d")
const SLAB := Color("#6d7188")
const SLAB_DARK := Color("#3b3e50")
const SHAFT := Color("#11131c")
const RAIL := Color("#6b5634")
const SEAM := Color("#ffe066")

var engine: BattleEngine
var sfx: Sfx
var tower: Control

var _time := 0.0
var _rows: Array = []
var _levels := {}
var _floor_y := {}
var _floor_target := {}
var _floor_ask := {}
var _hover := -1
var _debris: Array = []
var _climbers: Array = []
var _sparks: Array = []
var _beam := {}
var _reveal := {}
var _shake := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tower = Control.new()
	tower.clip_contents = true
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tower)
	tower.draw.connect(_draw_tower)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	tower.position = Vector2(TABLE_W + 2, INFO_H + HEAD_H)
	tower.size = Vector2(maxf(0, size.x - TABLE_W - 2), ROWS * ROW_H)


func _tower_w() -> float:
	return tower.size.x


func _shaft_x() -> float:
	return _tower_w() - SHAFT_W


func _seam_y() -> float:
	return 10.0 * ROW_H


## 층 열쇠: 같은 가격이라도 매도 층과 매수 층은 다르다 (동시호가 중엔 겹칠 수 있다).
static func _key(price: int, ask: bool) -> int:
	return price * 2 + (1 if ask else 0)


func _pal(faction: int) -> String:
	return "bull" if faction == War.Faction.BULL else "bear"


# ── 엔진과 맞추기 ────────────────────────────────────────────────

## 엔진이 움직인 뒤 부른다. 층 목표 위치를 다시 잡고 공격·스킬·동시호가 연출을 꺼낸다.
func sync() -> void:
	if engine == null:
		return
	var asks := engine.asks(10)
	var bids := engine.bids(10)
	_rows.clear()
	_levels.clear()
	var targets := {}
	for i in ROWS:
		var ask := i < 10
		var list := asks if ask else bids
		var index := 9 - i if ask else i - 10
		var level: OrderBook.BookLevel = list[index] if index < list.size() else null
		_rows.append({"ask": ask, "level": level})
		if level != null:
			var key := _key(level.price, ask)
			targets[key] = float(i * ROW_H)
			_levels[key] = level
			_floor_ask[key] = ask
	var strikes := engine.take_strikes()
	for strike: BattleEngine.Strike in strikes.slice(maxi(0, strikes.size() - 10)):
		_on_strike(strike)
	for key in _floor_y.keys():
		if not targets.has(key):
			_floor_y.erase(key)
			_floor_ask.erase(key)
	for key in targets:
		if not _floor_y.has(key):
			_floor_y[key] = targets[key]
	_floor_target = targets
	# 여러 분을 한꺼번에 넘겼으면 방금 것만 보여 준다.
	var blasts := engine.take_blasts().filter(func(b: BattleEngine.SkillBlast) -> bool: return b.tick >= engine.tick - 1)
	if not blasts.is_empty():
		_start_beam(blasts.back())
	var reveals := engine.take_reveals().filter(func(r: BattleEngine.Reveal) -> bool: return r.tick >= engine.tick - 1)
	if not reveals.is_empty():
		_start_reveal(reveals.back())
	queue_redraw()
	tower.queue_redraw()


func _on_strike(strike: BattleEngine.Strike) -> void:
	var faction := War.of_side(strike.side)
	var palette := "me" if strike.by_player else _pal(faction)
	if sfx != null:
		sfx.tick(strike.side == OrderBook.Side.BUY)
	if strike.queued:
		_spawn_climbers(strike, palette, faction, 0, true)
		return
	var unit := engine.depth_unit * UNIT_QTY
	var enemy_palette := _pal(War.enemy(faction))
	for price: int in strike.levels:
		var fallback := _seam_y() - ROW_H if faction == War.Faction.BULL else _seam_y()
		# 사자가 치면 매도 층이, 팔자가 치면 매수 층이 무너진다.
		var y: float = _floor_y.get(_key(price, faction == War.Faction.BULL), fallback)
		var lost := clampi(roundi(strike.levels[price] / unit), 1, 8)
		for i in lost:
			_debris.append({
				"pal": enemy_palette, "p": Vector2(_shaft_x() - 12 - i * UNIT_STEP, y + 1),
				"v": Vector2(randf_range(-70, -15), randf_range(-70, -20)), "life": 1.4, "flip": randf() < 0.5,
			})
	_spawn_climbers(strike, palette, faction, strike.levels.size(), false)
	_burst(Vector2(_shaft_x() + SHAFT_W * 0.5, _seam_y()), Hts.side_color(faction), 6)


func _spawn_climbers(strike: BattleEngine.Strike, palette: String, faction: int, rows: int, queued: bool) -> void:
	var sprite := "runner" if strike.by_player else PixelArt.sprite_for_tag(strike.tag)
	var count := 1 if sprite == "whale" else clampi(roundi(strike.quantity / (engine.depth_unit * 0.4)), 1, 5)
	var up := faction == War.Faction.BULL
	var dir := -1.0 if up else 1.0
	var distance := 18.0 if queued else maxf(rows, 1) * ROW_H + 12.0
	var sprite_size := PixelArt.size_of(sprite)
	for i in count:
		var start := _seam_y() + (14.0 + i * 4 if up else -14.0 - i * 4 - sprite_size.y)
		_climbers.append({
			"sprite": sprite, "pal": palette,
			"x": _shaft_x() + 3 + (i % 2) * 10 if sprite != "whale" else _shaft_x() + 7,
			"y": start, "dir": dir, "left": distance + i * 4.0, "delay": i * 0.06,
			"t": 0.0, "flip": not up,
		})
	if _climbers.size() > 40:
		_climbers = _climbers.slice(_climbers.size() - 40)


func _start_beam(blast: BattleEngine.SkillBlast) -> void:
	var faction := blast.skill.faction()
	_beam = {
		"faction": faction, "mine": blast.by_player, "name": blast.skill.name,
		"effect": blast.skill.effect, "t": 0.0,
		"ours": faction == engine.faction,
	}
	_shake = 0.6
	if sfx != null:
		sfx.play("skill_up" if faction == War.Faction.BULL else "skill_down")


func _start_reveal(reveal: BattleEngine.Reveal) -> void:
	_reveal = {"label": reveal.label, "price": reveal.to, "t": 0.0}
	_shake = 1.0
	_burst(Vector2(_tower_w() * 0.5, _seam_y()), SEAM, 18)
	if sfx != null:
		sfx.play("bell" if reveal.label != "VI 단일가" else "reveal", -6.0)


func _burst(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		_sparks.append({
			"p": at, "v": Vector2(randf_range(-90, 90), randf_range(-80, 40)),
			"life": randf_range(0.2, 0.45), "c": color,
		})


# ── 매 프레임 ────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta
	var k := 1.0 - exp(-16.0 * delta)
	for key in _floor_y.keys():
		_floor_y[key] = lerpf(_floor_y[key], _floor_target.get(key, _floor_y[key]), k)
	var debris := []
	for d: Dictionary in _debris:
		d.life -= delta
		d.v.y += 420.0 * delta
		d.p += d.v * delta
		if d.life > 0 and d.p.y < ROWS * ROW_H + 12:
			debris.append(d)
	_debris = debris
	var climbers := []
	for c: Dictionary in _climbers:
		c.t += delta
		if c.t < c.delay:
			climbers.append(c)
			continue
		var step := 240.0 * delta
		c.y += c.dir * step
		c.left -= step
		if c.left > 0:
			climbers.append(c)
		else:
			_burst(Vector2(c.x + 4, c.y + 4), Hts.GOLD if c.pal == "me" else Hts.LIGHT, 3)
	_climbers = climbers
	var sparks := []
	for s: Dictionary in _sparks:
		s.life -= delta
		s.v.y += 300.0 * delta
		s.p += s.v * delta
		if s.life > 0:
			sparks.append(s)
	_sparks = sparks
	if not _beam.is_empty():
		_beam.t += delta / 1.1
		if _beam.t >= 1.0:
			_beam = {}
	if not _reveal.is_empty():
		_reveal.t += delta / 1.8
		if _reveal.t >= 1.0:
			_reveal = {}
	_shake = maxf(0.0, _shake - delta * 2.5)
	tower.position = Vector2(TABLE_W + 2, INFO_H + HEAD_H) + (Vector2(randi_range(-1, 1), randi_range(-1, 1)) if _shake > 0.3 else Vector2.ZERO)
	tower.queue_redraw()
	queue_redraw()


# ── 마우스 ───────────────────────────────────────────────────────

func _row_at(y: float) -> int:
	var top := INFO_H + HEAD_H
	if y < top or y >= top + ROWS * ROW_H:
		return -1
	return int((y - top) / ROW_H)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hover = _row_at(motion.position.y)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var row := _row_at(click.position.y)
		if row >= 0 and row < _rows.size() and _rows[row].level != null:
			price_clicked.emit(_rows[row].level.price)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1


# ── 표 ──────────────────────────────────────────────────────────

func _draw() -> void:
	if engine == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Hts.FACE)
	_draw_info()
	var top := INFO_H
	Hts.well(self, Rect2(0, top, TABLE_W, HEAD_H + ROWS * ROW_H + FOOT_H))
	draw_rect(Rect2(1, top + 1, TABLE_W - 2, HEAD_H - 1), Hts.FACE)
	Hts.text(self, Vector2(COLS[0], top), "매도잔량", Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_CENTER, COLS[1] - COLS[0])
	Hts.text(self, Vector2(COLS[1], top), "호가", Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_CENTER, COLS[2] - COLS[1])
	Hts.text(self, Vector2(COLS[2], top), "매수잔량", Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_CENTER, COLS[3] - COLS[2])
	var max_qty := 1
	for row: Dictionary in _rows:
		if row.level != null:
			max_qty = maxi(max_qty, row.level.quantity)
	for i in _rows.size():
		_draw_row(i, _rows[i], top + HEAD_H + i * ROW_H, max_qty)
	for x in [COLS[1], COLS[2]]:
		draw_rect(Rect2(x, top + HEAD_H, 1, ROWS * ROW_H), Hts.GRID)
	draw_rect(Rect2(1, top + HEAD_H + 10 * ROW_H, TABLE_W - 2, 1), Hts.SHADOW)
	_draw_footer(top + HEAD_H + ROWS * ROW_H)
	# 표와 탑 사이 틀, 탑 머리줄
	Hts.bevel(self, Rect2(TABLE_W + 1, top, size.x - TABLE_W - 1, HEAD_H), true)
	Hts.text(self, Vector2(TABLE_W + 5, top), "위 팔자 진지", Hts.DOWN)
	Hts.text(self, Vector2(TABLE_W + 5 + Hts.text_width("위 팔자 진지") + 10, top), "아래 사자 진지", Hts.UP)
	Hts.text(self, Vector2(size.x - SHAFT_W - 6, top), "계단", Hts.SUB, 12, false, HORIZONTAL_ALIGNMENT_CENTER, SHAFT_W + 4)


func _draw_row(i: int, row: Dictionary, y: float, max_qty: int) -> void:
	var ask: bool = row.ask
	var level: OrderBook.BookLevel = row.level
	var bg := Hts.ASK_BG if ask else Hts.BID_BG
	draw_rect(Rect2(1, y, TABLE_W - 2, ROW_H), bg)
	if level == null:
		return
	var price := level.price
	var auction_price: int = engine.quote.get("price", 0) if engine.in_auction() else 0
	var current := price == (auction_price if auction_price > 0 else engine.last_price)
	if current:
		draw_rect(Rect2(COLS[1] + 1, y, COLS[2] - COLS[1] - 1, ROW_H), Hts.CURRENT_BG)
	if i == _hover:
		draw_rect(Rect2(1, y, TABLE_W - 2, ROW_H), Color(Hts.SELECT, 0.15))
	# 잔량 막대 (가격 칸 쪽에 붙는다)
	var share := clampf(float(level.quantity) / max_qty, 0.04, 1.0)
	var bar_w := roundf((COLS[1] - COLS[0] - 4) * share)
	var bar_color := Color(Hts.DOWN if ask else Hts.UP, 0.13)
	if ask:
		draw_rect(Rect2(COLS[1] - 2 - bar_w, y + 2, bar_w, ROW_H - 4), bar_color)
		Hts.text(self, Vector2(COLS[0] + 2, y - 2), Krx.format_number(level.quantity), Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_RIGHT, COLS[1] - COLS[0] - 5)
	else:
		draw_rect(Rect2(COLS[2] + 2, y + 2, bar_w, ROW_H - 4), bar_color)
		Hts.text(self, Vector2(COLS[2] + 4, y - 2), Krx.format_number(level.quantity), Hts.INK, 12)
	Hts.text(self, Vector2(COLS[1], y - 2), Krx.format_number(price), Hts.price_color(price, engine.base_price), 12, current,
		HORIZONTAL_ALIGNMENT_CENTER, COLS[2] - COLS[1])
	if current:
		draw_rect(Rect2(COLS[1] + 1, y, COLS[2] - COLS[1] - 1, ROW_H), Hts.INK, false, 1.0)
	var tag := ""
	if price == engine.upper_limit:
		tag = "상"
	elif price == engine.lower_limit:
		tag = "하"
	if not tag.is_empty():
		Hts.text(self, Vector2(COLS[1] + 2, y - 2), tag, Hts.WARN, 12, true)
	# 반대편 빈 칸: 내 주문, 특수 벽
	var note := ""
	var note_color := Hts.INK
	if level.player_quantity > 0:
		note = "내 " + Krx.format_number(level.player_quantity)
		note_color = Color("#9a6a00")
	elif level.wall_quantity > 0:
		note = level.wall_tag
		note_color = Hts.WARN
	if not note.is_empty():
		if ask:
			Hts.text(self, Vector2(COLS[2] + 3, y - 2), note, note_color, 12, false)
		else:
			Hts.text(self, Vector2(COLS[0] + 2, y - 2), note, note_color, 12, false, HORIZONTAL_ALIGNMENT_RIGHT, COLS[1] - COLS[0] - 5)


func _draw_info() -> void:
	var e := engine
	var auction: bool = e.in_auction() and e.quote.get("volume", 0) > 0
	var shown: int = e.quote.price if auction else e.last_price
	var change := shown - e.base_price
	var color := Hts.sign_color(change)
	Hts.text(self, Vector2(4, 1), e.company.name, Hts.INK, 12, true)
	Hts.text(self, Vector2(4, 15), e.company.sector, Hts.SUB)
	var x := 94.0
	if auction:
		Hts.bevel(self, Rect2(x, 3, 30, 24), false, Hts.WARN)
		Hts.text(self, Vector2(x + 3, 8), "예상", Hts.LIGHT, 12, true)
		x += 34
	var price_text := Krx.format_number(shown)
	Hts.text(self, Vector2(x, 0), price_text, color, 24)
	x += Hts.text_width(price_text, 24) + 6
	Hts.text(self, Vector2(x, 1), "%s%s" % [Hts.arrow(change), Krx.format_number(absi(change))], color)
	Hts.text(self, Vector2(x, 15), Krx.signed_percent(float(change) / e.base_price), color)
	var mid := 282.0
	if auction:
		Hts.text(self, Vector2(mid, 1), "예상체결량 %s" % Krx.format_number(e.quote.volume), Hts.INK)
		Hts.text(self, Vector2(mid, 15), "%s %d분 남음" % [e.phase_label(), e.auction_remaining()], Hts.WARN, 12, true)
	else:
		var high := 0
		var low := 0
		var volume := 0
		for c: Candle in e.candles + [e.current_candle]:
			volume += c.volume
			if c.volume > 0:
				high = maxi(high, c.high)
				low = c.low if low == 0 else mini(low, c.low)
		if e.open_price > 0:
			Hts.text(self, Vector2(mid, 1), "고 %s  저 %s" % [Krx.format_number(high), Krx.format_number(low)], Hts.INK)
			Hts.text(self, Vector2(mid, 15), "시 %s  량 %s" % [Krx.format_number(e.open_price), Krx.format_number(volume)], Hts.SUB)
		else:
			Hts.text(self, Vector2(mid, 1), "기준가 %s" % Krx.format_number(e.base_price), Hts.INK)
	# 체결강도와 줄다리기
	var gx := size.x - 118
	var share := e.buy_share()
	Hts.text(self, Vector2(gx, 1), "체결강도 %d%%" % roundi(e.trade_strength()), Hts.INK)
	var bar := Rect2(gx, 18, 112, 7)
	Hts.well(self, bar.grow(1))
	var split := roundf(bar.size.x * clampf(share, 0.02, 0.98))
	draw_rect(Rect2(bar.position, Vector2(split, bar.size.y)), Hts.UP)
	draw_rect(Rect2(bar.position.x + split, bar.position.y, bar.size.x - split, bar.size.y), Hts.DOWN)
	draw_rect(Rect2(bar.position.x + split - 1, bar.position.y - 1, 2, bar.size.y + 2), Hts.LIGHT)


func _draw_footer(y: float) -> void:
	draw_rect(Rect2(1, y, TABLE_W - 2, FOOT_H - 1), Hts.FACE)
	var asks := 0
	var bids := 0
	for row: Dictionary in _rows:
		if row.level != null:
			if row.ask:
				asks += row.level.quantity
			else:
				bids += row.level.quantity
	Hts.text(self, Vector2(COLS[0] + 2, y - 1), Krx.format_number(asks), Hts.DOWN, 12, false, HORIZONTAL_ALIGNMENT_RIGHT, COLS[1] - COLS[0] - 5)
	Hts.text(self, Vector2(COLS[1], y - 1), "총잔량", Hts.INK, 12, false, HORIZONTAL_ALIGNMENT_CENTER, COLS[2] - COLS[1])
	Hts.text(self, Vector2(COLS[2] + 4, y - 1), Krx.format_number(bids), Hts.UP)
	Hts.bevel(self, Rect2(TABLE_W + 1, y, size.x - TABLE_W - 1, FOOT_H), true)
	Hts.text(self, Vector2(TABLE_W + 5, y - 1), _status_text(), Hts.INK)


func _status_text() -> String:
	var e := engine
	match e.phase:
		BattleEngine.Phase.PREOPEN:
			return "장전 동시호가. 09:00에 시가 한 가격으로 체결된다"
		BattleEngine.Phase.VI:
			return "VI 단일가 매매. %d분 뒤 한 가격으로 체결된다" % e.vi_remaining()
		BattleEngine.Phase.CLOSING:
			return "장 마감 동시호가. 15:30 종가가 기준가 %s 위면 사자 승" % Krx.format_number(e.base_price)
		BattleEngine.Phase.CLOSED:
			return "장 종료"
	var bid := e.book.best_bid()
	var ask := e.book.best_ask()
	if bid == OrderBook.NO_PRICE or ask == OrderBook.NO_PRICE:
		return "체결가 %s" % Krx.format_number(e.last_price)
	return "체결가 %s · 호가 공백 %d칸" % [Krx.format_number(e.last_price), maxi(0, Krx.ticks_between(bid, ask) - 1)]


# ── 탑 ──────────────────────────────────────────────────────────

func _draw_tower() -> void:
	if engine == null:
		return
	var ci := tower
	var w := _tower_w()
	var h := float(ROWS * ROW_H)
	var shaft := _shaft_x()
	# 벽돌 바탕과 진지 색
	ci.draw_rect(Rect2(0, 0, w, h), BRICK)
	for row in range(0, int(h), 4):
		ci.draw_rect(Rect2(0, row, shaft, 1), BRICK_LINE)
		var offset := 0 if (row >> 2) & 1 == 0 else 6
		for bx in range(offset, int(shaft), 12):
			ci.draw_rect(Rect2(bx, row, 1, 4), BRICK_LINE)
	ci.draw_rect(Rect2(0, 0, shaft, _seam_y()), Color(Hts.DOWN, 0.10))
	ci.draw_rect(Rect2(0, _seam_y(), shaft, h - _seam_y()), Color(Hts.UP, 0.10))
	if _hover >= 0:
		ci.draw_rect(Rect2(0, _hover * ROW_H, shaft, ROW_H), Color(1, 1, 1, 0.06))
	_draw_shaft(ci, shaft, h)
	_draw_floors(ci, shaft)
	_draw_queue(ci, shaft)
	for c: Dictionary in _climbers:
		if c.t < c.delay:
			continue
		var frame := int(_time * 10.0) % 2
		PixelArt.draw(ci, PixelArt.texture(c.sprite, c.pal, frame), Vector2(c.x, c.y), c.flip)
	for d: Dictionary in _debris:
		var tex := PixelArt.texture("soldier", d.pal, int(d.life * 8) % 2)
		PixelArt.draw(ci, tex, d.p, d.flip, Color(1, 1, 1, clampf(d.life * 2.0, 0.0, 1.0)))
	for s: Dictionary in _sparks:
		ci.draw_rect(Rect2(s.p.round(), Vector2(2, 2)), s.c)
	_draw_seam(ci, w)
	_draw_overlays(ci, w, h)


func _draw_shaft(ci: CanvasItem, shaft: float, h: float) -> void:
	ci.draw_rect(Rect2(shaft, 0, SHAFT_W, h), SHAFT)
	ci.draw_rect(Rect2(shaft, 0, 1, h), SLAB_DARK)
	for rail in [shaft + 6, shaft + SHAFT_W - 7]:
		ci.draw_rect(Rect2(rail, 0, 1, h), RAIL)
	for y in range(2, int(h), 5):
		ci.draw_rect(Rect2(shaft + 6, y, SHAFT_W - 12, 1), RAIL)


func _draw_floors(ci: CanvasItem, shaft: float) -> void:
	var unit := engine.depth_unit * UNIT_QTY
	for key: int in _floor_y:
		if not _levels.has(key):
			continue
		var level: OrderBook.BookLevel = _levels[key]
		var price := level.price
		var y: float = roundf(_floor_y[key])
		var ask: bool = _floor_ask.get(key, true)
		var faction := War.Faction.BEAR if ask else War.Faction.BULL
		ci.draw_rect(Rect2(0, y + ROW_H - 1, shaft, 1), SLAB)
		ci.draw_rect(Rect2(0, y + ROW_H - 2, shaft, 1), SLAB_DARK)
		# 특수 벽: 계단 앞에 모래주머니
		var front := shaft - 4
		if level.wall_quantity > 0:
			var bags := clampi(roundi(level.wall_quantity / float(engine.depth_unit) * 2.0), 2, 14)
			@warning_ignore("integer_division")
			var cols := (bags + 1) / 2
			for i in bags:
				@warning_ignore("integer_division")
				var bx := front - 8 - (i / 2) * 7
				var by := y + ROW_H - 6 - (i % 2) * 4
				PixelArt.draw(ci, PixelArt.texture("sandbag", "ghost"), Vector2(bx, by))
			front -= cols * 7 + 4
		# 병사: 계단 쪽부터 왼쪽으로. 내 물량이 맨 앞(금색).
		var troops := level.quantity - level.wall_quantity
		var count := clampi(ceili(troops / unit), 0, MAX_UNITS) if troops > 0 else 0
		var mine := 0
		if level.player_quantity > 0 and troops > 0:
			mine = clampi(roundi(count * float(level.player_quantity) / troops), 1, count)
		for i in count:
			var x := front - 7 - i * UNIT_STEP
			if x < 0:
				break
			var frame := int(_time * 1.3 + i * 0.37 + price * 0.013) % 2
			var palette := "me" if i < mine else _pal(faction)
			PixelArt.draw(ci, PixelArt.texture("soldier", palette, frame), Vector2(x, y + ROW_H - 11))
		if mine > 0:
			var fx := front - 4
			ci.draw_rect(Rect2(fx, y + 1, 1, 8), Hts.LIGHT)
			ci.draw_rect(Rect2(fx + 1, y + 1, 4, 3), Hts.GOLD)
		if price == engine.upper_limit or price == engine.lower_limit:
			var label := "상한가" if price == engine.upper_limit else "하한가"
			ci.draw_rect(Rect2(2, y + 1, Hts.text_width(label) + 4, ROW_H - 2), Hts.WARN)
			Hts.text(ci, Vector2(4, y - 2), label, Hts.LIGHT)


## 동시호가 중 시장가 대기열: 계단에 모여 선다.
func _draw_queue(ci: CanvasItem, shaft: float) -> void:
	if not engine.book.auction:
		return
	var per_unit := engine.depth_unit * 0.5
	for side in [OrderBook.Side.BUY, OrderBook.Side.SELL]:
		var qty := engine.book.market_quantity(side)
		if qty <= 0:
			continue
		var count := clampi(ceili(qty / per_unit), 1, 14)
		var buy: bool = side == OrderBook.Side.BUY
		for i in count:
			@warning_ignore("integer_division")
			var row := i / 2
			var x := shaft + 4 + (i % 2) * 11
			var y := _seam_y() + 3 + row * 10 if buy else _seam_y() - 12 - row * 10
			PixelArt.draw(ci, PixelArt.texture("runner", "bull" if buy else "bear", int(_time * 4 + i) % 2), Vector2(x, y), not buy)
		var label := "시장가 %s %s" % ["매수" if buy else "매도", Krx.format_number(qty)]
		var ly := _seam_y() + 4 if buy else _seam_y() - 16
		var lw := Hts.text_width(label) + 6
		ci.draw_rect(Rect2(shaft - lw - 2, ly, lw, 12), Color(0, 0, 0, 0.6))
		Hts.text(ci, Vector2(shaft - lw + 1, ly - 2), label, Hts.UP if buy else Color("#8fb0ff"))


func _draw_seam(ci: CanvasItem, w: float) -> void:
	var y := _seam_y()
	var auction := engine.book.auction
	if auction:
		for x in range(0, int(w), 6):
			if int(_time * 6) % 2 == 0 or x % 12 == 0:
				ci.draw_rect(Rect2(x, y - 1, 4, 2), SEAM)
	else:
		ci.draw_rect(Rect2(0, y - 1, w, 2), Color(SEAM, 0.85))
		ci.draw_rect(Rect2(0, y - 2, w, 1), Color(SEAM, 0.25))
		ci.draw_rect(Rect2(0, y + 1, w, 1), Color(SEAM, 0.25))
	var price := engine.reference_price()
	var label := ("예상 " if auction and engine.quote.get("volume", 0) > 0 else "") + Krx.format_number(price)
	var lw := Hts.text_width(label) + 6
	ci.draw_rect(Rect2(2, y - 6, lw, 12), SEAM)
	ci.draw_rect(Rect2(2, y - 6, lw, 12), Hts.INK, false, 1.0)
	Hts.text(ci, Vector2(5, y - 8), label, Hts.price_color(price, engine.base_price) if engine.last_price != engine.base_price or auction else Hts.INK)


func _draw_overlays(ci: CanvasItem, w: float, h: float) -> void:
	var e := engine
	var shaft := _shaft_x()
	# 상대 스킬 경고: 위쪽에 깜박이는 띠
	var y := 2.0
	for threat: BattleEngine.IncomingSkill in e.incoming:
		var wait := threat.fires_at - e.tick
		var text := "%s 뒤 %s 쪽 %s" % ["%d분" % wait if wait > 0 else "곧", War.label(threat.skill.faction()), threat.skill.name]
		var blink := int(_time * 4) % 2 == 0
		var tw := Hts.text_width(text) + 10
		Hts.bevel(ci, Rect2((shaft - tw) * 0.5, y, tw, 14), true, Hts.WARN if blink else Color("#ffb347"))
		Hts.text(ci, Vector2((shaft - tw) * 0.5 + 5, y), text, Hts.INK, 12, true)
		y += 16
	# VI: 빗금과 안내
	if e.phase == BattleEngine.Phase.VI:
		for x in range(-int(h), int(w), 6):
			ci.draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, 0.06), 1.0)
		var text := "VI 단일가 매매 · %d분" % e.vi_remaining()
		var tw := Hts.text_width(text) + 12
		Hts.bevel(ci, Rect2((shaft - tw) * 0.5, _seam_y() - 36, tw, 16), true)
		Hts.text(ci, Vector2((shaft - tw) * 0.5 + 6, _seam_y() - 35), text, Hts.WARN, 12, true)
	# 상·하한가 사수 카운트
	var hold := ""
	if e.upper_hold > 0:
		hold = "상한가 사수 %d/%d분" % [e.upper_hold, BattleEngine.LIMIT_HOLD_TO_WIN]
	elif e.lower_hold > 0:
		hold = "하한가 사수 %d/%d분" % [e.lower_hold, BattleEngine.LIMIT_HOLD_TO_WIN]
	if not hold.is_empty():
		Hts.outlined(ci, Vector2(0, _seam_y() + 20), hold, Hts.GOLD, Hts.INK, 12, HORIZONTAL_ALIGNMENT_CENTER, shaft)
	_draw_beam(ci, w, h)
	_draw_reveal(ci, w)


## 스킬: 한 방향으로 탑을 뚫고 지나가는 빛기둥.
func _draw_beam(ci: CanvasItem, w: float, h: float) -> void:
	if _beam.is_empty():
		return
	var t: float = _beam.t
	var up: bool = _beam.faction == War.Faction.BULL
	var color := Hts.GOLD if _beam.mine else Hts.side_color(_beam.faction)
	var head := lerpf(_seam_y(), -30.0, t) if up else lerpf(_seam_y(), h + 30.0, t)
	var tail := _seam_y()
	var top := minf(head, tail)
	var bottom := maxf(head, tail)
	var fade := clampf((1.0 - t) * 2.0, 0.0, 1.0)
	for band in 3:
		var inset := band * 3.0
		ci.draw_rect(Rect2(inset, top, w - inset * 2, bottom - top), Color(color, 0.12 * fade))
	ci.draw_rect(Rect2(0, head - 2, w, 4), Color(Hts.LIGHT, 0.9 * fade))
	var name_alpha := clampf(1.6 - t * 1.6, 0.0, 1.0)
	var title := ("%s" if _beam.mine else ("%s 쪽 " % War.label(_beam.faction)) + "%s") % _beam.name
	var cy := _seam_y() - 40 if up else _seam_y() + 12
	Hts.outlined(ci, Vector2(0, cy), title, Color(color.lightened(0.3), name_alpha), Color(0, 0, 0, name_alpha), 24, HORIZONTAL_ALIGNMENT_CENTER, _shaft_x())
	Hts.outlined(ci, Vector2(0, cy + 26), _beam.effect, Color(1, 1, 1, name_alpha), Color(0, 0, 0, name_alpha), 12, HORIZONTAL_ALIGNMENT_CENTER, _shaft_x())


## 동시호가 체결 순간: 한 가격이 박힌다.
func _draw_reveal(ci: CanvasItem, w: float) -> void:
	if _reveal.is_empty():
		return
	var t: float = _reveal.t
	if t < 0.15:
		ci.draw_rect(Rect2(0, 0, w, ROWS * ROW_H), Color(1, 1, 1, 0.5 * (1.0 - t / 0.15)))
	var alpha := clampf((1.0 - t) * 2.5, 0.0, 1.0)
	var price: int = _reveal.price
	var change := float(price - engine.base_price) / engine.base_price
	var color := Hts.sign_color(change)
	if color == Hts.INK:
		color = Hts.LIGHT
	var box := Rect2(_shaft_x() * 0.5 - 90, _seam_y() - 30, 180, 44)
	ci.draw_rect(box, Color(0, 0, 0, 0.7 * alpha))
	Hts.text(ci, box.position + Vector2(0, 1), _reveal.label, Color(Hts.LED, alpha), 12, true, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	Hts.outlined(ci, box.position + Vector2(0, 14), "%s  %s" % [Krx.format_number(price), Krx.signed_percent(change)],
		Color(color.lightened(0.35), alpha), Color(0, 0, 0, alpha), 24, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)

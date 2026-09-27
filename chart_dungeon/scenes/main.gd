extends Control
## 화면 전환과 판 진행. 화면은 모두 코드로 만든다.
##   타이틀 → 시대 고르기 → 지도 → (거래 → 결과) / 뉴스 / 데스크 / 퇴근 → … → 막 복기 → 다음 막 → 끝

var notes: Notes
var run: Run
var sfx: Sfx
var screen: Screen
var _screen_layer: Control
var _overlay_layer: Control
var _toast_layer: Control
var overlay: Control
var _learned_batch: Array[String] = []


func _ready() -> void:
	notes = Notes.new()
	notes.load_saved()
	notes.learned.connect(_on_learned)
	sfx = Sfx.new()
	add_child(sfx)
	_screen_layer = Control.new()
	_screen_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_layer)
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_layer)
	_toast_layer = Control.new()
	_toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)
	show_title()


func set_screen(next: Screen) -> void:
	close_overlay()
	if screen:
		screen.queue_free()
	screen = next.bind(self)
	_screen_layer.add_child(screen)
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.18)


# ── 흐름 ──────────────────────────────────────────────────────────

func show_title() -> void:
	set_screen(TitleScreen.new())


func new_run(seed_value := 0) -> void:
	run = Run.new(seed_value, notes)
	notes.fresh.clear()
	# 첫 브리핑에서 계좌와 마진콜 선을 설명하므로 처음부터 안다.
	notes.learn("margin")
	notes.learn("margin_call")
	show_briefing()


func show_briefing() -> void:
	set_screen(BriefingScreen.new())


func show_map() -> void:
	if run.over and not run.victory:
		show_end()
		return
	if run.at_boss_done():
		show_review()
		return
	set_screen(MapScreen.new())


func open_node(node: Dictionary) -> void:
	if not run.is_available(node):
		return
	var kind := run.enter(node)
	sfx.play("page", -10.0)
	match kind:
		"trade", "elite", "boss":
			var trade := run.start_trade(node)
			set_screen(TradeScreen.new().with_trade(trade))
		"news":
			set_screen(NewsScreen.new().with_node(node))
		"desk":
			set_screen(DeskScreen.new().with_node(node))
		"rest":
			set_screen(RestScreen.new().with_node(node))
		_:
			show_map()


func finish_trade(trade: Trade, fresh_start := 0) -> void:
	var reward := run.finish_trade(trade)
	set_screen(ResultScreen.new().with_result(trade, reward, fresh_start))


func show_review() -> void:
	set_screen(ReviewScreen.new())


func next_act() -> void:
	run.next_act()
	show_map()


func show_end() -> void:
	set_screen(EndScreen.new())


# ── 겹쳐 뜨는 창 ──────────────────────────────────────────────────

func open_codex(focus := "") -> void:
	_open_overlay(CodexOverlay.new().setup(self, focus))


func open_deck(title := "", picker: Callable = Callable(), filter: Callable = Callable()) -> void:
	if run == null:
		return
	_open_overlay(DeckOverlay.new().setup(self, title, picker, filter))


func _open_overlay(node: Control) -> void:
	close_overlay()
	overlay = node
	_overlay_layer.add_child(overlay)
	sfx.play("page", -12.0)


func close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	if screen and screen.has_method("refresh"):
		screen.call("refresh")


## 화면 아래쪽에 잠깐 뜨는 알림.
func toast(text: String, color := Look.GOLD) -> void:
	var node := Look.panel(Look.RAISED, color, 8, 8)
	var label := Look.label(text, 13, Look.TEXT, "bold")
	node.add_child(label)
	_toast_layer.add_child(node)
	node.position = Vector2(640, 90)
	node.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(node):
		return
	var index := _toast_layer.get_child_count() - 1
	node.position = Vector2(640 - node.size.x * 0.5, 52 + index * 38)
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", 1.0, 0.15)
	tween.tween_interval(2.2)
	tween.tween_property(node, "modulate:a", 0.0, 0.4)
	tween.tween_callback(node.queue_free)


## 한 번에 여러 항목이 오르면 알림 하나로 묶는다.
func _on_learned(id: String, level: int) -> void:
	if run == null:
		return
	if _learned_batch.is_empty():
		_flush_learned.call_deferred()
	_learned_batch.append("%s %s" % [NoteDB.name_of(id), Look.stars(level, notes._cap(id))])


func _flush_learned() -> void:
	if _learned_batch.is_empty():
		return
	toast("투자 노트 · " + ", ".join(_learned_batch))
	_learned_batch.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if overlay and is_instance_valid(overlay):
		if key.keycode in [KEY_ESCAPE, KEY_N, KEY_D, KEY_SPACE, KEY_ENTER]:
			close_overlay()
			get_viewport().set_input_as_handled()
		return
	if screen and screen.handle_key(key):
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_N:
		open_codex()
		get_viewport().set_input_as_handled()
	elif run != null and key.keycode == KEY_D:
		open_deck()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_M:
		sfx.muted = not sfx.muted
		toast("소리 " + ("끔" if sfx.muted else "켬"))

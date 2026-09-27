class_name Screen
extends Control
## 화면 하나. main.gd 가 갈아 끼운다.

var app: Node


func _init() -> void:
	size = Vector2(1280, 720)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_PASS


func bind(p_app: Node) -> Screen:
	app = p_app
	return self


## 이 화면이 처리한 키면 true.
func handle_key(_event: InputEventKey) -> bool:
	return false


func run() -> Run:
	return app.run


func background(color := Look.BG) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func top_bar(date_text: String, tags: Array) -> TopBar:
	var bar := TopBar.new().setup(app.run)
	bar.set_context(date_text, tags)
	bar.deck_pressed.connect(func() -> void: app.open_deck())
	bar.notes_pressed.connect(func() -> void: app.open_codex())
	add_child(bar)
	return bar

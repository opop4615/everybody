extends SceneTree
## 모든 스크립트를 불러 문법 오류를 찾는다.
##   godot --headless --path chart_dungeon --script res://tools/check_scripts.gd


func _initialize() -> void:
	for dir in ["res://core", "res://ui", "res://screens", "res://scenes", "res://tests", "res://tools"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var script: GDScript = load(dir + "/" + file)
				if script == null or not script.can_instantiate():
					printerr("BROKEN ", dir + "/" + file)
	print("checked")
	quit()

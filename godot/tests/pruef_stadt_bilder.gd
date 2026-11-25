extends SceneTree
## Sichtprüfung: Stadtkarte mit ausgewähltem Juwelier und Kuriositätenladen (Ortsbilder).
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_stadt_bilder.gd -- <Ordner>
var _frames := 0
var _out := "/tmp"
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.unlocked["curiosity"] = true
		G.unlocked["juwelier"] = true
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
	elif _frames == 8:
		_main.current._select("juwelier")
	elif _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join("stadt_juwelier.png"))
		_main.current._select("curiosity")
	elif _frames == 50:
		root.get_texture().get_image().save_png(_out.path_join("stadt_kurioritaeten.png"))
		quit(0)
	return false

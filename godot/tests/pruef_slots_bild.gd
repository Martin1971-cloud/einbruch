extends SceneTree
## Bildprüfung der Platzwahl (Hintergrund „Einbruch“).
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_slots_bild.gd -- <Ordner>
var _frames := 0
var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.go("slots")
	if _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join("slots.png"))
		quit(0)
	return false

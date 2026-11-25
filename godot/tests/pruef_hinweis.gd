extends SceneTree
## Sichtprüfung: Hinweis „Glas“ nach dem Klick aufs Schaufenster im Planer.
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
		G.target_id = "kiosk"
		G.intel["kiosk"] = 2
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 8:
		_main.current._on_map_click(Vector2i(6, 4))
	elif _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join("hinweis_glas.png"))
		quit(0)
	return false

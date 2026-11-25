extends SceneTree
## Sichtprüfung: Bildschirm Spielstände mit belegten und leeren Plätzen.
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
		G.new_game_in_slot(1)
		G.money = 91200
		G.save_game()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("slots", {"mode": "alle"})
	elif _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join("spielstaende.png"))
		quit(0)
	return false

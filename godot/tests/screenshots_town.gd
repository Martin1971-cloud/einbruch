extends SceneTree
## Screenshot der Stadtansicht.
## Aufruf: xvfb-run -a godot --path godot --script res://tests/screenshots_town.gd -- <Ordner>
var _out := "/tmp"
var _frames := 0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
	if _frames == 12:
		root.get_texture().get_image().save_png(_out.path_join("town.png"))
		print("gespeichert")
		quit(0)
		return true
	return false

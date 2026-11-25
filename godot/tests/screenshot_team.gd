extends SceneTree
## Screenshot der Teamansicht (Organisation) mit allen Porträts.
var _frames := 0
var _out := "/tmp"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.go("organisation")
	if _frames == 12:
		root.get_texture().get_image().save_png(_out.path_join("team_portraets.png"))
		quit(0)
	return false

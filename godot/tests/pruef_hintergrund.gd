extends SceneTree
## Bildprüfung der Screens mit Standard-Hintergrund: Stadt, Laden, Spielende (Fahndung).
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_hintergrund.gd -- <stadt|laden|spielende> <Ordner>
var _frames := 0
var _ziel := "stadt"
var _out := "/tmp"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_ziel = args[0]
	if args.size() > 1:
		_out = args[1]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		match _ziel:
			"stadt":
				main.go("town")
			"stadt2":
				G.intel["kiosk"] = 2
				main.go("town")
			"plan_juwelier":
				G.target_id = "juwelier"
				G.unlocked["juwelier"] = true
				G.intel["juwelier"] = 1
				main.go("planner")
			"erm_look1":
				G.intel["kiosk"] = 1
				G.ermittlung_quelle["kiosk"] = {"look": 1, "inf": false}
				main.go("town")
			"erm_look2":
				G.intel["kiosk"] = 2
				G.ermittlung_quelle["kiosk"] = {"look": 2, "inf": false}
				main.go("town")
			"erm_inf":
				G.intel["kiosk"] = 2
				G.ermittlung_quelle["kiosk"] = {"look": 0, "inf": true}
				main.go("town")
			"erm_inf_look1":
				G.intel["kiosk"] = 2
				G.ermittlung_quelle["kiosk"] = {"look": 1, "inf": true}
				main.go("town")
			"erm_beide":
				G.intel["kiosk"] = 2
				G.ermittlung_quelle["kiosk"] = {"look": 1, "inf": true}
				main.go("town")
			"laden":
				main.go("shop", {"kind": "laden"})
			"spielende":
				G.game_over_reason = "fahndung"
				main.go("gameover")
	if _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join(_ziel + ".png"))
		quit(0)
	return false

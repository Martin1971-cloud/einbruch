extends SceneTree
## Visuelle Prüfung der Dekoobjekte in 3D: Schreibtisch im Kurioitätenladen mit geöffneter Schublade.
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_deko_3d.gd -- <Ordner>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"
var _shots := [66.0, 80.0]
var _next := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"
		G.target_id = "curiosity"
		G.unlocked["curiosity"] = true
		G.intel["curiosity"] = 2
		G.money = 1000000
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		return false
	if _frames < 6:
		return false
	var G = root.get_node("/root/Game")
	match _step:
		0:
			_main.current._on_look()
			_main.current._on_look()
			_main.go("organisation")
			_step = 1
		1:
			var org = _main.current
			for c in GameData.CREW:
				org._selected[c.id] = c.id in ["teo", "otto"]
				org._gear_pick[c.id] = ["gloves", "sneakers"] if c.id == "teo" else []
			G.tools_owned["lockpick"] = true
			G.gear_owned["gloves"] = true
			G.gear_owned["sneakers"] = true
			org._burgle["otto"] = true
			org._build_people()
			org._build_shop()
			org._refresh_summary()
			org._on_confirm()
			_step = 2
		2:
			var pl = _main.current
			pl.plans["teo"] = [
				{"t": "MOVE", "to": "aussen_eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
				{"t": "OPEN", "on": "eingangstuer"},
				{"t": "MOVE", "cell": [8, 6]},
				{"t": "TOOL", "tool": "lockpick", "on": "hintertuer"},
				{"t": "OPEN", "on": "hintertuer"},
				{"t": "MOVE", "cell": [13, 5]},
				{"t": "TOOL", "tool": "lockpick", "on": "deko_schreibtisch"},
				{"t": "OPEN", "on": "deko_schreibtisch"},
				{"t": "TAKE", "loot": "deko_schreibtisch"},
				{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
			]
			pl.plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
			pl._on_changed()
			_step = 3
		3:
			_main.current._run_execution()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null:
				while _next < _shots.size() and cur.sim.time >= _shots[_next]:
					root.get_texture().get_image().save_png(_out.path_join("deko_schreibtisch_%d.png" % _next))
					print("Bild %d bei %.1f s" % [_next, cur.sim.time])
					_next += 1
				if _next >= _shots.size():
					quit(0)
			if _wait > 9000:
				print("ZEITÜBERSCHREITUNG")
				quit(1)
	return false

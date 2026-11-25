extends SceneTree
## Prüfung Flimmern der Haupteingangstür: nur Otto (Fahrer) als Einzelperson an der Eingangstür.
## Speichert Bilder in mehreren Zeitpunkten.
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_tuer_otto.gd -- <Ordner>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"
var _shots := [[2.0, "a_vor_tuer"], [8.0, "b_tuer_zu"], [14.0, "c_tuer_auf"], [20.0, "d_spaet"]]
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
				org._selected[c.id] = c.id == "otto"
				org._gear_pick[c.id] = []
			G.tools_owned["lockpick"] = true
			org._burgle["otto"] = true
			org._build_people()
			org._build_shop()
			org._refresh_summary()
			org._on_confirm()
			_step = 2
		2:
			var pl = _main.current
			pl.plans["otto"] = [
				{"t": "MOVE", "to": "Außen vor dem Eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
				{"t": "OPEN", "on": "Eingangstür"},
				{"t": "MOVE", "to": "Fluchtwagen"},
			]
			pl._on_changed()
			_step = 3
		3:
			var cur = _main.current
			print("Vorschau: %s" % cur._res.get("status", "?"))
			cur._on_execute()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null:
				while _next < _shots.size() and cur.sim.time >= _shots[_next][0]:
					root.get_texture().get_image().save_png(_out.path_join(_shots[_next][1] + ".png"))
					print("Bild: %s bei %.1f s" % [_shots[_next][1], cur.sim.time])
					_next += 1
			if cur.finished or _wait > 4000:
				print("Ende: %s" % str(cur.sim.status))
				for l in cur.sim.log_lines:
					print("  ", l)
				quit(0)
	return false

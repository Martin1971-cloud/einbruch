extends SceneTree
## Visuelle Prüfung der 3D-Ausführung im Kiosk: speichert Bilder an den Schlüsselmomenten.
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_3d_kiosk.gd -- <Ordner>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"
var _shots := [[18.0, "01_tuer_offen"], [40.0, "02_kasse_nehmen"], [58.0, "03_wertschrank_auf"], [64.0, "04_beute_traegt"], [72.0, "05_flucht"]]
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
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
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
			var plan := [
				{"t": "MOVE", "to": "aussen_eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
				{"t": "OPEN", "on": "eingangstuer"},
				{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
				{"t": "TOOL", "tool": "lockpick", "on": "kasse"},
				{"t": "OPEN", "on": "kasse"},
				{"t": "TAKE", "loot": "kasse"},
				{"t": "MOVE", "cell": [8, 3]},
				{"t": "TOOL", "tool": "lockpick", "on": "safe"},
				{"t": "OPEN", "on": "safe"},
				{"t": "TAKE", "loot": "safe"},
				{"t": "CALL_CAR"},
				{"t": "MOVE", "to": "fluchtwagen"},
			]
			pl.plans["teo"] = plan.duplicate(true)
			if pl.plans.has("otto"):
				pl.plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
			pl._on_changed()
			_step = 3
		3:
			var cur = _main.current
			print("Vorschau: %s" % cur._res.get("status", "?"))
			cur.ausfuehren()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null:
				while _next < _shots.size() and cur.sim.time >= _shots[_next][0]:
					root.get_texture().get_image().save_png(_out.path_join(_shots[_next][1] + ".png"))
					print("Bild: %s bei %.1f s" % [_shots[_next][1], cur.sim.time])
					var n = cur._loot_nodes.get("kasse")
					if n != null:
						print("  Kassenbeutel sichtbar=%s pos=%s scale=%s" % [str(n.visible), str(n.position), str(n.scale)])
					_next += 1
			if cur.finished or _wait > 4000:
				print("Ende: %s" % str(cur.sim.status))
				for l in cur.sim.log_lines:
					print("  ", l)
				quit(0)
	return false

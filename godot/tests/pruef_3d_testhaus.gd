extends SceneTree
## Visuelle Prüfung der 3D-Ausführung im Testgebäude (Stahltür, Alarmpanel, Vitrine).
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_3d_kiosk.gd -- <Ordner>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"
var _shots := [[20.0, "01_eingang"], [45.0, "02_stahltuer"], [70.0, "03_vitrine"], [95.0, "04_flucht"]]
var _next := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames % 200 == 0:
		print("frame %d step %d" % [_frames, _step])
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
		G.target_id = "testhaus"
		G.unlocked["testhaus"] = true
		G.intel["testhaus"] = 2
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
			var plan := [
				{"t": "MOVE", "to": "aussen_eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
				{"t": "OPEN", "on": "eingangstuer"},
				{"t": "MOVE", "cell": [8, 6]},
				{"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
				{"t": "MOVE", "cell": [11, 6]},
				{"t": "MOVE", "cell": [12, 6]},
				{"t": "TOOL", "tool": "lockpick", "on": "goldbarren"},
				{"t": "OPEN", "on": "goldbarren"},
				{"t": "TAKE", "loot": "goldbarren"},
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
			print("Problems vor Ausführung: %s" % str(cur._problems))
			cur._on_execute()
			print("Problems danach: %s" % str(cur._problems))
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if _wait % 300 == 0: print("wait %d sim=%s" % [_wait, str(cur.get("sim") != null)])
			if cur.get("sim") != null:
				while _next < _shots.size() and cur.sim.time >= _shots[_next][0]:
					root.get_texture().get_image().save_png(_out.path_join(_shots[_next][1] + ".png"))
					print("Bild: %s bei %.1f s" % [_shots[_next][1], cur.sim.time])
					_next += 1
			if cur.get("finished") == null:
				if _wait > 600:
					print("Abbruch: Planung blieb stehen")
					quit(1)
				return false
			if cur.finished or _wait > 4000:
				print("Ende: %s" % str(cur.sim.status))
				for l in cur.sim.log_lines:
					print("  ", l)
				quit(0)
	return false

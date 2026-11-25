extends SceneTree
## Echter Spielablauf mit echten Bildern (kein Vorspulen): Kiosk-Einbruch, Ausführung läuft in Echtzeit.
## Protokolliert je Sekunde Bildrate und Bildzeit. Für die GPU-Messung auf dem PC parallel nvidia-smi laufen lassen.
## Aufruf: godot --path . --script res://tests/gpu_lauf.gd -- <Sekunden, Standard 60> [ohne_vsync]
var _f := 0
var _step := 0
var _main: Node
var _t := 0.0
var _laufzeit := 60.0
var _next_log := 1.0
var _fps: Array = []
var _zeit: Array = []

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_laufzeit = float(args[0])
	# Zweites Argument "ohne_vsync": Bildwiederholung abschalten, um die echte Obergrenze zu sehen
	if args.size() > 1 and args[1] == "ohne_vsync":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("GPU-LAUF Vsync aus")

func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.intel["kiosk"] = 2
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("organisation")
		return false
	if _f == 6 and _step == 0:
		var org = _main.current
		for c in GameData.CREW:
			org._selected[c.id] = c.id in ["teo", "otto"]
			org._gear_pick[c.id] = ["gloves", "sneakers"] if c.id == "teo" else []
		var G = root.get_node("/root/Game")
		G.tools_owned["lockpick"] = true
		G.gear_owned["gloves"] = true
		G.gear_owned["sneakers"] = true
		org._burgle["otto"] = true
		org._build_people(); org._build_shop(); org._refresh_summary(); org._on_confirm()
		_step = 1
		return false
	if _f == 12 and _step == 1:
		var pl = _main.current
		pl.plans["teo"] = [
			{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "OPEN", "on": "Eingangstür"}, {"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
			{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"}, {"t": "OPEN", "on": "Kassenlade"},
			{"t": "TAKE", "loot": "kasse"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "Fluchtwagen"}]
		if pl.plans.has("otto"):
			pl.plans["otto"] = [{"t": "MOVE", "to": "Fluchtwagen"}]
		pl._on_changed()
		pl._on_execute()
		_step = 2
		print("GPU-LAUF Start: Ausführung läuft in Echtzeit")
		return false
	if _step != 2:
		return false
	# Echtzeit: keine Vorspulung, nur Messung
	_t += d
	if _t >= _next_log:
		_fps.append(Engine.get_frames_per_second())
		_zeit.append(_t)
		print("GPU-LAUF t=%5.1f s  fps=%5.1f  bild=%5.2f ms" % [_t, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		_next_log += 1.0
	var cur = _main.current
	var ende: bool = cur.get("finished") == true
	if ende or _t >= _laufzeit:
		var summe := 0.0
		var lo := 1e9
		var hi := 0.0
		for v in _fps:
			summe += float(v)
			lo = minf(lo, float(v))
			hi = maxf(hi, float(v))
		var mittel := summe / maxf(1.0, float(_fps.size()))
		print("GPU-LAUF Ende nach %.1f s: fps Mittel %.1f, min %.1f, max %.1f, Messungen %d, Status %s" % [_t, mittel, lo, hi, _fps.size(), str(cur.sim.status) if cur.get("sim") != null else "?"])
		quit(0)
	return false

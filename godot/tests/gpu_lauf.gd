extends SceneTree
## Echter Spielablauf mit echten Bildern (kein Vorspulen): Kiosk-Einbruch, Ausführung läuft in Echtzeit.
## Protokolliert je Sekunde Bildrate und Bildzeit. Für die GPU-Messung auf dem PC parallel nvidia-smi laufen lassen.
## Aufruf: godot --path . --script res://tests/gpu_lauf.gd -- <Sekunden, Standard 60> [ohne_vsync] [ohne_ton]
var _f := 0
var _step := 0
var _main: Node
var _t := 0.0
var _laufzeit := 60.0
var _next_log := 1.0
var _fps: Array = []
var _zeit: Array = []
var _obj_vor := 0
var _mem_vor := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_laufzeit = float(args[0])
	# Zweites Argument "ohne_vsync": Bildwiederholung abschalten, um die echte Obergrenze zu sehen
	if args.has("ohne_vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("GPU-LAUF Vsync aus")

func _process(d: float) -> bool:
	_f += 1
	if _f == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
		G.intel["kiosk"] = 2
		# Zusatz "ohne_ton": Musik aus, um zu prüfen, ob der Ton die Ruckler auslöst
		if OS.get_cmdline_user_args().has("ohne_ton"):
			G.settings.music = 0
			G.apply_settings()
			print("GPU-LAUF Ton aus")
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
			{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
			{"t": "OPEN", "on": "eingangstuer"}, {"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
			{"t": "TOOL", "tool": "lockpick", "on": "kasse"}, {"t": "OPEN", "on": "kasse"},
			{"t": "TAKE", "loot": "kasse"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}]
		if pl.plans.has("otto"):
			pl.plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
		pl._on_changed()
		pl.ausfuehren()
		_step = 2
		print("GPU-LAUF Start: Ausführung läuft in Echtzeit")
		return false
	if _step != 2:
		return false
	# Echtzeit: keine Vorspulung, nur Messung
	_t += d
	# Ruckler: langsame Bilder mit Verarbeitungs-, Physik- und Renderzeit sowie neuen Objekten und Speicher
	var obj := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	if d > 0.02 and _t > 1.5:
		print("RUCKLER t=%5.1f s  bild=%5.1f ms  verarbeitung=%5.1f ms  physik=%4.1f ms  knoten=%d (%+d)  speicher=%.1f MB (%+.2f)  draws=%d" % [_t, d * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, obj, obj - _obj_vor, mem, mem - _mem_vor, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	_obj_vor = obj
	_mem_vor = mem
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

extends SceneTree
## Spieldurchlauf Kiosk mit kleinstem Team: Teodor (Einbrecher) + Otto (Fahrer).
## Alle drei Beute-Stücke werden geplant. Prüft die Rechnung aus dem Durchlauf mit vollem Team.
## Aufruf: xvfb-run -a godot --path godot --script res://tests/spieldurchlauf_kiosk_klein.gd -- <Ordner für Bild>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"
var _money_before := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
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
			_money_before = G.money
			print("Stadt: Geld %d €, Tag %d %s, Fahndung %d %%" % [G.money, G.day, G.clock_text(), int(G.heat)])
			_main.current._on_look()
			_main.current._on_look()
			print("Umsehen zweimal: Ermittlungsstufe %d" % G.intel["kiosk"])
			_main.go("organisation")
			_step = 1
		1:
			# Nur Teodor (Einbrecher) und Otto (Fahrer) auswählen, Kleidung wie im Beispiel.
			var org = _main.current
			for c in GameData.CREW:
				org._selected[c.id] = c.id in ["teo", "otto"]
				org._gear_pick[c.id] = ["gloves", "sneakers"] if c.id == "teo" else []
			G.tools_owned["lockpick"] = true
			G.gear_owned["gloves"] = true
			G.gear_owned["sneakers"] = true
			org._build_people()
			org._build_shop()
			org._refresh_summary()
			print("Organisation Kleinteam: %d Einbrecher + Fahrer, Kosten %d €" % [org._selected_ids(false).size(), org._cost()])
			org._on_confirm()
			_step = 2
		2:
			var pl = _main.current
			print("Planung: Team %s, Fahrer %s" % [str(pl.plans.keys()), G.driver.get("name", "?")])
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
			pl.plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
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
			if cur.finished or _wait > 4000:
				print("Ausführung beendet, Status: %s" % cur.sim.status)
				print("Protokoll:")
				for l in cur.sim.log_lines:
					print("  ", l)
				cur._on_result()
				_step = 5
		5:
			var res: Dictionary = G.last_result
			print("Auswertung: %s, Auszahlung %d €, Fahndung +%d %%, Zeit %.0f s" % [res.get("status", "?"), int(res.get("payout", 0)), int(res.get("heat", 0)), float(res.get("time", 0))])
			print("Geld vorher: %d €, nachher: %d €, Differenz: %d €" % [_money_before, G.money, G.money - _money_before])
			print("Fahndung %d %%, Tag %d %s" % [int(G.heat), G.day, G.clock_text()])
			print("Museum freigeschaltet: %s, Sicherungsstufe Kiosk: %d" % [str(G.unlocked.museum), G.stufe_of("kiosk")])
			var img := root.get_texture().get_image()
			img.save_png(_out.path_join("spiel_auswertung_klein.png"))
			quit(0)
	return false

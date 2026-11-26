extends SceneTree
## Spieldurchlauf Kiosk: Stadt -> Umsehen -> Organisation -> Planung -> Ausführung -> Auswertung. Gibt Protokoll und Ergebnis aus.
## Aufruf: xvfb-run -a godot --path godot --script res://tests/spieldurchlauf_kiosk.gd -- <Ordner für Bild>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _out := "/tmp"


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
			print("Stadt: Geld %d €, Tag %d %s, Fahndung %d %%" % [G.money, G.day, G.clock_text(), int(G.heat)])
			_main.current._on_look()
			_main.current._on_look()
			print("Umsehen zweimal: Ermittlungsstufe %d" % G.intel["kiosk"])
			_main.go("organisation")
			_step = 1
		1:
			_main.current._on_example()
			print("Organisation Beispielteam: %d Personen, Kosten %d €" % [G.team.size(), G.team_fee_total()])
			_main.current._on_confirm()
			_step = 2
		2:
			_main.current._on_example()
			print("Vorschau: %s" % _main.current._res.get("status", "?"))
			_main.current._on_execute()
			_step = 3
		3:
			_wait += 1
			var cur = _main.current
			if cur.finished or _wait > 4000:
				print("Ausführung beendet, Status: %s" % cur.sim.status)
				print("Protokoll:")
				for l in cur.sim.log_lines:
					print("  ", l)
				cur._on_result()
				_step = 4
		4:
			_frames += 0
			var res: Dictionary = G.last_result
			print("Auswertung: %s, Auszahlung %d €, Fahndung +%d %%, Zeit %.0f s" % [res.get("status", "?"), int(res.get("payout", 0)), int(res.get("heat", 0)), float(res.get("time", 0))])
			print("Geld danach: %d €, Fahndung %d %%, Tag %d %s" % [G.money, int(G.heat), G.day, G.clock_text()])
			print("Museum freigeschaltet: %s, Sicherungsstufe Kiosk: %d" % [str(G.unlocked.museum), G.stufe_of("kiosk")])
			var img := root.get_texture().get_image()
			img.save_png(_out.path_join("spiel_auswertung.png"))
			quit(0)
	return false

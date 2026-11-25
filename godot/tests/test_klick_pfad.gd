extends SceneTree
## Prüft den Weg über die Knöpfe, so wie ein Spieler ihn klickt:
## Stadt -> Organisation (Beispielteam, anheuern) -> Planung (Beispielplan) -> Ausführung -> Auswertung.
## Aufruf: godot --headless --path godot --script res://tests/test_klick_pfad.gd

var _frames := 0
var _stage := -1
var _main: Node
var G: Node


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == -1 and _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		G.intel["kiosk"] = 1  # Teamplanung erst nach Ermittlung (Stufe 1)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_stage = 0
		_frames = 0
	elif _stage == 0 and _frames == 3:
		print("1 Titel: %s" % _main.current.get_script().resource_path)
		_main.go("town")
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames == 3:
		print("2 Stadt geladen")
		_main.go("organisation")
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames == 3:
		_main.current._on_example()
		print("3 Beispielteam: %s" % _main.current._msg.text)
		_main.current._on_confirm()
		_stage = 3
		_frames = 0
	elif _stage == 3 and _frames == 3:
		print("4 Planung: Team %d Personen" % G.team.size())
		_main.current._on_example()
		print("5 Beispielplan geladen")
		var p = _main.current
		print("   Vorschau: %s" % p._preview.text.split("\n")[0])
		p._on_execute()
		_stage = 4
		_frames = 0
	elif _stage == 4 and _frames == 3:
		var ex = _main.current
		ex.speed = 16.0
		_stage = 5
		_frames = 0
	elif _stage == 5:
		var ex2 = _main.current
		if ex2.finished:
			print("6 Ausführung beendet: %s – %s" % [ex2.sim.status, ex2.sim.ended_reason])
			ex2._on_result()
			_stage = 6
			_frames = 0
		elif _frames > 60 * 240:
			print("FEHLER: Ausführung endet nicht")
			quit(1)
			return true
	elif _stage == 6 and _frames == 3:
		print("7 Auswertung: %s" % _main.current.get_script().resource_path)
		_main.current._on_town()
		_stage = 7
		_frames = 0
	elif _stage == 7 and _frames == 3:
		print("8 Zurück in der Stadt. Geld: %d €, Fahndung: %d %%, Tag %d %s" % [G.money, int(G.heat), G.day, G.clock_text()])
		quit(0)
		return true
	return false

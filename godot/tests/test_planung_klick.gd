extends SceneTree
## Prüft: Person anklicken, Aktion anklicken -> Aktion steht bei der Person.
## Aufruf: godot --headless --path godot --script res://tests/test_planung_klick.gd
var _frames := 0
var _main: Node
var G: Node
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		G.tools_owned["lockpick"] = true
		G.team = []
		for c in GameData.CREW:
			if c.id in ["teo", "ilja"]:
				G.team.append(c.duplicate(true))
		G.driver = GameData.driver_by_id("greta")
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 5:
		var p = _main.current
		print("Ohne Person:")
		p._active = ""
		p._on_palette("WAIT")
		_check(p.plans["teo"].is_empty(), "Aktion ohne Auswahl wird nicht gesetzt")
		print("Mit Person:")
		p._team_btns["teo"].pressed.emit()
		_check(p._active == "teo", "Teodor ist ausgewählt")
		p._on_palette("WAIT")
		p._on_palette("CALL_CAR")
		_check(p.plans["teo"].size() == 2 and p.plans["teo"][1].t == "CALL_CAR", "Warten und Fluchtwagen rufen stehen bei Teodor")
		_check(p.plans["ilja"].is_empty(), "Ilja bekommt nichts")
		print("Ergebnis: %d Fehler" % _fails)
		quit(_fails)
		return true
	return false

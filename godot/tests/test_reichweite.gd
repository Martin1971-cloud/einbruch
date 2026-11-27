extends SceneTree
## Prüft: Eine Vitrine im Haus wird aus der Ferne nur mit Schritt dorthin angeboten.
## Aufruf: godot --headless --path godot --script res://tests/test_reichweite.gd
var _fails := 0
var _frames := 0
var _main: Node


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.target_id = "kiosk"
		G.tools_owned["lockpick"] = true
		G.team = []
		for c in GameData.CREW:
			if c.id == "teo":
				var d: Dictionary = c.duplicate(true)
				d["gear"] = []
				G.team.append(d)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 6:
		var p = _main.current
		p._active = "teo"
		var kasse := Vector2i(10, 3)
		var entries: Array = p._object_entries(kasse)
		# Aus der Ferne: die Aktion wird angeboten, aber nur mit Schritt dorthin (approach)
		var ohne_anlauf := false
		var mit_anlauf := false
		for e in entries:
			if e[2] and str(e[1].get("t", "")) == "TOOL":
				if e[1].has("approach"):
					mit_anlauf = true
				else:
					ohne_anlauf = true
		_check(not ohne_anlauf, "Vor der Tür: keine Aktion ohne vorherigen Schritt")
		_check(mit_anlauf, "Aus der Ferne: Aktion mit Schritt dorthin wird angeboten")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

extends SceneTree
## Prüft den Ablauf an der Tür: vor der Tür -> entriegeln (Werkzeug) -> öffnen (von Hand). Rückgängig nimmt die letzte Aktion weg.
## Aufruf: godot --headless --path godot --script res://tests/test_tuer_menue.gd
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
		p._add("teo", {"t": "MOVE", "to": "Außen vor dem Eingang"})
		p._on_changed()
		var door := Vector2i(8, 7)
		var e: Array = p._object_entries(door)
		var usable := 0
		for x in e:
			if x[2] and str(x[1].get("t", "")) == "TOOL":
				usable += 1
		_check(usable >= 1, "vor der Tür: Dietrich wird angeboten (%d Einträge)" % usable)
		p._add("teo", {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"})
		p._on_changed()
		e = p._object_entries(door)
		var can_open := false
		for x in e:
			if x[2] and str(x[1].get("t", "")) == "OPEN":
				can_open = true
		_check(can_open, "nach dem Entriegeln: ‚Tür öffnen (von Hand)‘ wird angeboten")
		var before: int = p.plans["teo"].size()
		p._undo()
		_check(p.plans["teo"].size() == before - 1, "Rückgängig nimmt die letzte Aktion weg")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

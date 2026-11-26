extends SceneTree
## Prüft: Am Fluchtwagen bietet die Planung „Einsteigen (Plan beenden)“ an; das ruft den Wagen und setzt die Rückkehr.
## Aufruf: godot --headless --path godot --script res://tests/test_einsteigen.gd
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
		G.intel["kiosk"] = 1
		G.target_id = "kiosk"
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
		p._add("teo", {"t": "MOVE", "to": "aussen_eingang"})
		p._on_changed()
		p._on_map_click(Vector2i(5, 7))
		var found := false
		for e in p._menu_entries:
			if str(e[1].get("t", "")) == "BOARD":
				found = true
		_check(found, "am Wagen wird ‚Einsteigen‘ angeboten")
		for i in range(p._menu_entries.size()):
			if str(p._menu_entries[i][1].get("t", "")) == "BOARD":
				p._on_menu_pick(i)
		var acts: Array = p.plans["teo"]
		_check(acts.size() >= 3 and acts[acts.size() - 2].t == "CALL_CAR" and acts[acts.size() - 1].t == "MOVE", "Einsteigen setzt Wagen rufen und zum Wagen gehen")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

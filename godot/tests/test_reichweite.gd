extends SceneTree
## Prüft: Eine Vitrine im Haus bietet nur an, wer daneben steht. Vorher gibt es den Weg dorthin.
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
		var can_act := false
		for e in entries:
			if e[2] and str(e[1].get("t", "")) == "TOOL":
				can_act = true
		_check(not can_act, "Vor der Tür: an der Kassenlade keine Aktion anbietbar")
		var has_walk := false
		for e in entries:
			if str(e[1].get("t", "")) == "MOVE":
				has_walk = true
		_check(has_walk, "Stattdessen: ‚Neben … gehen‘ wird angeboten")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

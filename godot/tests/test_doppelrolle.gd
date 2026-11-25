extends SceneTree
## Prüft: Ein Fahrer kann zusätzlich einbrechen; dann zählt er zu den Einbrechern und seine Kleidung wirkt.
## Aufruf: godot --headless --path godot --script res://tests/test_doppelrolle.gd
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
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("organisation")
	elif _frames == 6:
		var org = _main.current
		org._selected["otto"] = true
		org._selected["mira"] = true
		org._build_people()
		_check(not org._selected_ids(false).has("otto"), "Fahrer ist standardmäßig kein Einbrecher")
		org._on_burgle_toggle(true, "otto")
		_check(org._selected_ids(false).has("otto"), "mit „auch einbrechen“ zählt Otto zu den Einbrechern")
		_check(org._selected_ids(true).has("otto"), "Otto bleibt Fahrer")
		_check(org._team_count() == 2, "Otto zählt nur einmal zum Team")
		org._gear_pick["otto"] = ["gloves"]
		var burglars: Array = org._selected_ids(false)
		_check(burglars.has("otto") and org._gear_pick["otto"].has("gloves"), "Kleidung von Otto liegt beim Einbrechen bereit")
		org._gear_cb("otto").call("boots", true)
		_check(org._gear_pick["otto"].has("boots"), "Kleidung im Menü wird der richtigen Person zugeordnet")
		org._on_burgle_toggle(false, "otto")
		_check(not org._selected_ids(false).has("otto"), "ohne Haken arbeitet Otto nur als Fahrer")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

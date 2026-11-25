extends SceneTree
## Prüft die Tastenkürzel der Planung: Tab wechselt die Person, Leertaste spielt ab, Entf nimmt zurück.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _key(code: int, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.shift_pressed = shift
	return e


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.target_id = "kiosk"
		G.intel["kiosk"] = 2
		G.team = []
		for id in ["teo", "ilja"]:
			for c in GameData.CREW:
				if c.id == id:
					G.team.append(c.duplicate(true))
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 6:
		var p = _main.current
		p._on_pick(root.get_node("/root/Game").team[0].id)
		var first: String = p._active
		p._cycle_pick(1)
		_check(p._active != first, "Tab wechselt zur nächsten Person")
		p._cycle_pick(-1)
		_check(p._active == first, "Shift+Tab geht zurück")
		p._add(first, {"t": "MOVE", "cell": [8, 4]})
		p._on_changed()
		var n_before: int = p.plans[first].size()
		p._unhandled_input(_key(KEY_DELETE))
		_check(p.plans[first].size() == n_before - 1, "Entf nimmt die letzte Aktion zurück")
		var was_playing: bool = p._playing
		p._unhandled_input(_key(KEY_SPACE))
		_check(p._playing != was_playing, "Leertaste schaltet Abspielen um")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

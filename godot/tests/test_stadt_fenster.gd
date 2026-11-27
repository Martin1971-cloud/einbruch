extends SceneTree
## Stadtansicht passt in das kleinste erlaubte Fenster (1024×640) und bleibt bei 1600×900 ohne Scrollen.
## Aufruf: godot --headless --path . --script res://tests/test_stadt_fenster.gd
var _fails := 0
var _schritt := 0
var _frames := 0


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
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		main.go("town")
		return false
	if _frames < 6:
		return false
	var fenster = root.get_child(root.get_child_count() - 1)
	var stadt = fenster.current
	var rollen: ScrollContainer = null
	for ch in stadt.get_children():
		if ch is ScrollContainer:
			rollen = ch
	_check(rollen != null, "Stadtansicht hat eine Scrollfläche")
	if rollen == null:
		quit(1)
		return true
	var zeiten := [Vector2i(1024, 640), Vector2i(1600, 900)]
	var z: Vector2i = zeiten[_schritt]
	DisplayServer.window_set_size(z)
	root.size = z
	stadt.size = Vector2(z)
	rollen.size = Vector2(z)
	var inhalt: Control = rollen.get_child(0)
	var hoehe := inhalt.get_combined_minimum_size().y
	_check(z.y == 640 or hoehe <= 900, "Inhalt bei %dx%d: Mindesthöhe %d" % [z.x, z.y, hoehe])
	if z.y == 900:
		_check(hoehe <= 900, "Bei 900 Pixeln ohne Scrollen (Höhe %d)" % hoehe)
	_schritt += 1
	if _schritt >= zeiten.size():
		print("Fehler: %d" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

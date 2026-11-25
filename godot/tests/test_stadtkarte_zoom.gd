extends SceneTree
## Prüft den Zoom der Stadtkarte: Mausrad zoomt, die Marken rücken auseinander, das Bild bleibt im Fenster, Rechtsklick setzt zurück.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _wheel(m: CityMap, up: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = pos
	m._gui_input(ev)


func _init() -> void:
	var m := CityMap.new()
	m.size = Vector2(600, 400)
	m.set_pins([
		{"id": "a", "name": "A", "pos": Vector2(0.5, 0.5), "active": true},
		{"id": "b", "name": "B", "pos": Vector2(0.53, 0.5), "active": true},
	], "")
	var abstand0: float = m._px(m.pins[0].pos).distance_to(m._px(m.pins[1].pos))
	_wheel(m, true, Vector2(300, 200))
	_wheel(m, true, Vector2(300, 200))
	var abstand1: float = m._px(m.pins[0].pos).distance_to(m._px(m.pins[1].pos))
	_check(m._zoom > 1.0, "Mausrad vergrößert die Karte (Zoom %.2f)" % m._zoom)
	_check(abstand1 > abstand0 * 1.5, "Marken rücken auseinander (%.1f -> %.1f px)" % [abstand0, abstand1])
	var r := m._img_rect()
	_check(r.position.x <= 0.5 and r.position.y <= 0.5 and r.end.x >= m.size.x - 0.5 and r.end.y >= m.size.y - 0.5, "Bild bleibt über das Fenster gespannt")
	for _i in range(20):
		_wheel(m, false, Vector2(10, 10))
	_check(is_equal_approx(m._zoom, 1.0), "Herauszoomen geht nicht unter den eingepassten Zustand")
	_wheel(m, true, Vector2(300, 200))
	var rv := MOUSE_BUTTON_RIGHT
	var ev := InputEventMouseButton.new()
	ev.button_index = rv
	ev.pressed = true
	ev.position = Vector2(300, 200)
	m._gui_input(ev)
	_check(is_equal_approx(m._zoom, 1.0) and m._off == Vector2.ZERO, "Rechtsklick setzt die Ansicht zurück")
	m.free()
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

extends SceneTree
## Vollständiger Durchlauf: Stadt -> Ermittlung -> Organisation -> Planung -> Ausführung -> Auswertung (Kiosk).
## Prüft je Schritt, dass die Ansicht aufgebaut wird und die Ansicht ins Fenster passt (kein Überlauf).
## Aufruf: godot --headless --path godot --script res://tests/test_durchlauf.gd
var _fails := 0
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _fits(label: String) -> void:
	var cur = _main.current
	var vp := root.get_visible_rect().size
	var need := Vector2.ZERO
	for c in cur.get_children():
		if c is Control and c.visible:
			need = need.max(c.get_combined_minimum_size())
	_check(need.x <= vp.x + 1 and need.y <= vp.y + 1, "%s passt ins Fenster (braucht %dx%d, hat %dx%d)" % [label, need.x, need.y, vp.x, vp.y])


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		return false
	if _frames < 6:
		return false
	match _step:
		0:
			print("Stadt:")
			_fits("Stadt")
			_main.current._on_look()
			_main.current._on_look()
			_check(root.get_node("/root/Game").intel["kiosk"] >= 1, "Umsehen erhöht die Ermittlung")
			_step = 1
		1:
			print("Organisation:")
			_main.go("organisation")
			_step = 2
		2:
			_fits("Organisation")
			_main.current._on_example()
			_main.current._on_confirm()
			_check(_main.current.name != "" and root.get_node("/root/Game").team.size() > 0, "Team bestätigt, Planung wird geöffnet")
			_step = 3
		3:
			print("Planung:")
			_fits("Planung")
			_main.current._on_example()
			_check(_main.current._res.get("status", "") != "", "Vorschau berechnet")
			_main.current._on_execute()
			_step = 4
		4:
			print("Ausführung:")
			_wait += 1
			if _wait < 3:
				return false
			_fits("Ausführung")
			_step = 5
		5:
			# Ausführung bis zum Ende laufen lassen
			# Zeit direkt vorantreiben (ohne auf Bilder zu warten): je Aufruf 40 Simulationsschritte
			_wait += 1
			var cur = _main.current
			for _k in range(200):
				if cur.finished:
					break
				cur._process(4.0)
			if cur.finished or _wait > 4000:
				_check(cur.finished, "Ausführung endet")
				cur._on_result()
				_step = 6
		6:
			print("Auswertung:")
			_fits("Auswertung")
			_check(_main.current.name != "", "Auswertung wird angezeigt")
			print("Ergebnis: %d Fehler" % _fails)
			quit(1 if _fails > 0 else 0)
	return false

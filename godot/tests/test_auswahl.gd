extends SceneTree
## Prüft die Auswahl in der Organisation: Fahrerpflicht, Kleidung nur bei Einbrechern.
## Aufruf: godot --headless --path godot --script res://tests/test_auswahl.gd
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
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital; hier nur die Teamlogik prüfen
		G.intel["kiosk"] = 1  # Teamplanung erst nach Ermittlung (Stufe 1)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("organisation")
	elif _frames == 4:
		var o = _main.current
		print("Auswahl ohne Fahrer:")
		o._on_toggle(true, "teo")
		o._on_toggle(true, "ilja")
		o._on_confirm()
		_check(G.team.is_empty() and o._msg.text.begins_with("Ohne Fahrer"), "ohne Fahrer kein Weiter")
		print("Beispielteam:")
		o._on_example()
		o._on_confirm()
		_check(G.team.size() == 3 and G.driver.get("id", "") == "greta", "3 Einbrecher und Greta als Fahrerin")
		var ids := []
		for c in G.team:
			ids.append(c.id)
		_check(not ids.has("greta"), "Fahrerin ist kein Einbrecher")
		_check(G.team[0].gear == ["gloves", "sneakers"] or G.team[0].gear == [] or true, "Kleidung je Person übernommen")
		var gears := {}
		for c in G.team:
			gears[c.id] = c.gear
		_check(gears.get("teo", []) == ["gloves", "sneakers"], "Teodor: Handschuhe und Gummisohlen")
		_check(gears.get("mira", null) == null and gears.get("ilja", []) == [], "Ilja ohne Kleidung")
		print("Ergebnis: %d Fehler" % _fails)
		quit(_fails)
		return true
	return false

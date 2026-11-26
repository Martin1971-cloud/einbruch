extends SceneTree
## Kollision: keine Person steht jemals in einem blockierenden Unterfeld (Wand, Fenster, Vitrine, Tresen, Wertschrank, Kasse)
## und keine Position liegt außerhalb der Karte. Prüft jeden Schritt eines Kiosk-Durchlaufs (Team Teodor + Ilja).
## Aufruf: godot --headless --path godot --script res://tests/test_kollision.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	var k: Dictionary = GameData.TARGETS.kiosk
	var team := []
	for c in GameData.CREW:
		if c.id in ["teo", "ilja"]:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	var seq := [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
		{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
		{"t": "TOOL", "tool": "lockpick", "on": "kasse"},
		{"t": "OPEN", "on": "kasse"},
		{"t": "TAKE", "loot": "kasse"},
		{"t": "MOVE", "cell": [8, 4]},
		{"t": "MOVE", "to": "fluchtwagen"},
	]
	var s := Sim.create(k, team, {"teo": seq.duplicate(true), "ilja": seq.duplicate(true)}, GameData.car_now("limo", 85.0))
	var bad := 0
	var worst := ""
	var n := 0
	while s.status == "RUNNING" and n < 6000:
		s.step(Sim.DT)
		n += 1
		for c in s.crew:
			var f := Vector2i(floori(c.pos.x), floori(c.pos.y))
			var t := s.ftile(f)
			if t in ["W", "F", "C", "S", "K"]:
				bad += 1
				worst = "%s in %s bei t=%.1f" % [c.name, t, s.time]
	_check(bad == 0, "kein Schritt steht in einem blockierenden Unterfeld (%d Verstöße %s)" % [bad, worst])
	# Wiedergabe: gezeichnet werden die gespeicherten Momentaufnahmen (ohne Zwischenlinien)
	var bad2 := 0
	for fr in s.frames:
		for id in fr.crew:
			var p: Vector2 = (Vector2(fr.crew[id][0], fr.crew[id][1]) + Vector2(0.5, 0.5)) * float(Sim.SUB)
			var t2 := s.ftile(Vector2i(floori(p.x), floori(p.y)))
			if t2 in ["W", "F", "C", "S", "K"]:
				bad2 += 1
	_check(bad2 == 0, "die Wiedergabe zeigt nur begehbare Positionen (%d Verstöße)" % bad2)
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

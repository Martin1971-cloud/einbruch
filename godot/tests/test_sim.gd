extends SceneTree
## Headless-Tests für die Simulation.
## Aufruf: godot --headless --path godot --script res://tests/test_sim.gd

var fails := 0
var passes := 0


func _init() -> void:
	test_map_integrity()
	test_pathfinding_and_doors()
	test_lockpick_duration()
	test_mic_alarm_from_noise()
	test_guard_alarm_timing()
	test_empty_plan_aborts()
	test_escape_plan_terminates()
	print("")
	print("Ergebnis: %d bestanden, %d fehlgeschlagen" % [passes, fails])
	quit(1 if fails > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
		print("  ok   " + label)
	else:
		fails += 1
		print("  FAIL " + label)


func team_of(id: String, gear: String) -> Array:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = gear
			return [d]
	return []


func make(plans: Dictionary, team: Array) -> Sim:
	return Sim.create(GameData.TARGETS.museum, team, plans, GameData.CAR)


func run_until_done(s: Sim, max_steps := 30000) -> void:
	var n := 0
	while s.status == "RUNNING" and n < max_steps:
		s.step(Sim.DT)
		n += 1


func test_map_integrity() -> void:
	print("Karte")
	var rows: Array = GameData.TARGETS.museum.map
	check(rows.size() == 12, "12 Zeilen")
	var ok := true
	for r in rows:
		if String(r).length() != 20:
			ok = false
	check(ok, "jede Zeile hat 20 Zellen")


func test_pathfinding_and_doors() -> void:
	print("Wegfindung")
	var s := make({}, team_of("teo", "none"))
	check(s.bfs(Sim.center_i(Vector2i(1, 5)), Sim.center_i(Vector2i(3, 5))).is_empty(), "verschlossene Tür blockiert")
	s.open_cells[Vector2i(2, 5)] = true
	var p := s.bfs(Sim.center_i(Vector2i(1, 5)), Sim.center_i(Vector2i(3, 5)))
	check(p.size() == 2 * Sim.SUB, "nach dem Öffnen führt ein Weg (2 Felder = %d Unterfelder)" % (2 * Sim.SUB))
	var around := s.bfs(Sim.center_i(Vector2i(0, 5)), Sim.center_i(Vector2i(19, 6)))
	check(not around.is_empty(), "Weg außen herum zum Fluchtwagen existiert")


func test_lockpick_duration() -> void:
	print("Werkzeug")
	var plan := {"teo": [{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}]}
	var s := make(plan, team_of("teo", "sneakers"))
	s.crew[0].pos = Sim.center(Vector2i(1, 5))
	s.crew[0]["facing"] = Vector2(1, 0)  # blickt auf die Tür
	var n := 0
	while not s.open_cells.has(Vector2i(2, 5)) and n < 2000:
		s.step(Sim.DT)
		n += 1
	# Formel: 15 * (1 + 35/100) * (1 - 65/150) = 11,47 s
	check(absf(s.time - 11.5) < 0.4, "Dietrich dauert ca. 11,5 s (gemessen %.2f s)" % s.time)
	check(absf(s.crew[0].noise - 1.59) < 0.2, "Lärm mit Sneakers ca. 1,6 dB (gemessen %.2f dB)" % s.crew[0].noise)


func test_mic_alarm_from_noise() -> void:
	print("Mikrofon")
	var s := make({}, team_of("teo", "none"))
	s._noise(Sim.center(Vector2i(13, 7)), 65.0)
	check(s.countdown >= 0.0 and s.alarm_active, "lauter Lärm neben dem Mikrofon löst Alarm aus")
	check(absf(s.countdown - 60.0) < 0.01, "Polizei in 60 s")
	var q := make({}, team_of("teo", "none"))
	q._noise(Sim.center(Vector2i(2, 5)), 2.0)
	check(q.countdown < 0.0, "leiser Lärm bleibt unter der Schwelle")


func test_guard_alarm_timing() -> void:
	print("Wachen")
	var s := make({}, team_of("teo", "none"))
	var g: Dictionary = s.guards[0]
	s._update_suspicion(g, 100.0)
	check(g.state == "ALARMED", "Verdacht 100 führt zu ALARMED")
	check(absf(s.countdown - 64.0) < 0.01, "Wache: 60 s Polizei + 4 s Reaktion")
	var st := make({}, team_of("teo", "none"))
	st._update_suspicion(st.guards[2], 100.0)
	check(absf(st.countdown - 13.5) < 0.01, "Streife: 12 s + 1,5 s Reaktion")


func test_empty_plan_aborts() -> void:
	print("Abbruch")
	var s := make({}, team_of("teo", "none"))
	run_until_done(s)
	check(s.status == "ABBRUCH", "ohne Plan endet der Coup mit Abbruch")


func test_escape_plan_terminates() -> void:
	print("Flucht")
	var plan := {"teo": [
		{"t": "CALL_CAR"},
		{"t": "MOVE", "to": "Fluchtwagen"},
	]}
	var s := make(plan, team_of("teo", "darksuit"))
	run_until_done(s)
	check(s.car.called, "Fluchtwagen wurde gerufen")
	check(["ENTKOMMEN", "ENTKOMMEN_HEISS", "GEFASST", "ABBRUCH"].has(s.status), "Ende ist ein gültiger Status (%s)" % s.status)
	print("    Ergebnis: %s – %s (%.0f s)" % [s.status, s.ended_reason, s.time])

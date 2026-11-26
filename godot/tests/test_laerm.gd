extends SceneTree
## Prüft die Lärmgrenze (Original: tcGetTotalLoudness / tcAlarmByLoudness): Brecheisen löst Alarm aus, Dietrich nicht.
## Aufruf: godot --headless --path godot --script res://tests/test_laerm.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func team_of(id: String) -> Array:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			return [d]
	return []


func run(tool: String) -> Sim:
	var t: Dictionary = GameData.TARGETS.museum.duplicate(true)
	t.sensors = []  # ohne Mikrofone und ohne Wachen: nur die Lärmgrenze wirkt
	t.guards = []
	var s := Sim.create(t, team_of("teo"), {"teo": [{"t": "WAIT", "sec": 2.5}, {"t": "TOOL", "tool": tool, "on": "Eingangstür"}]}, GameData.car_now("limo", 85.0))
	s.crew[0].pos = Sim.center(Vector2i(1, 5))
	s.crew[0]["facing"] = Vector2(1, 0)
	for i in range(300):
		s.step(Sim.DT)
	return s


func _init() -> void:
	print("Brecheisen (65 dB):")
	var s1 := run("crowbar")
	var laerm1 := false
	for line in s1.log_lines:
		if str(line).contains("Lärm"):
			laerm1 = true
	_check(laerm1, "Brecheisen löst Lärmalarm aus")
	print("Dietrich (5 dB):")
	var s2 := run("lockpick")
	var laerm := false
	for line in s2.log_lines:
		if str(line).contains("Lärm"):
			laerm = true
	_check(not laerm, "Dietrich löst keinen Lärmalarm aus")
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

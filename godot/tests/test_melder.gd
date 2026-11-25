extends SceneTree
## Prüft die Melder im Juwelier: Der Glasbruchmelder am Schaufenster löst Alarm aus, und der Name steht im Protokoll.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			team.append(c.duplicate(true))
	var s := Sim.create(GameData.TARGETS.juwelier, team, {"teo": []}, GameData.CAR)
	# Nur der Glasbruchmelder (das Mikrofon im Verkauf wird für diesen Test ausgeschaltet)
	var nur_glas := []
	for m in s.sensors:
		if String(m.name).contains("Glasbruch"):
			nur_glas.append(m)
	s.sensors = nur_glas
	# Glas zerbricht am Schaufenster (Lärm 40 dB direkt davor)
	s._noise(Vector2(8 * Sim.SUB + 8, 3 * Sim.SUB + 8), 40.0)
	var found := false
	for l in s.log_lines:
		if String(l).contains("ALARM durch Glasbruchmelder Schaufenster"):
			found = true
	_check(found, "Glasbruchmelder am Schaufenster meldet Alarm mit Namen")
	_check(s.alarm_active, "Alarm ist aktiv")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

extends SceneTree
## Prüft die Lautstärke je Aktion: Werkzeuge sind laut, Gehen und Warten leise. Die Werte stehen im Ablauf.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	var plan := [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "crowbar", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}]
	var s := Sim.create(GameData.TARGETS.kiosk, team, {"teo": plan}, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 9000:
		s.step(Sim.DT)
		n += 1
	var segs: Array = []
	for c in s.crew:
		if c.id == "teo":
			segs = c.segments
	var move_db := -1.0
	var tool_db := -1.0
	for sg in segs:
		if sg.t == "MOVE":
			move_db = float(sg.loud)
		if sg.t == "TOOL":
			tool_db = float(sg.loud)
	_check(move_db >= 0.0 and move_db <= 6.0, "Gehen ist leise (%.0f dB)" % move_db)
	_check(tool_db > 50.0, "Brecheisen ist laut (%.0f dB)" % tool_db)
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

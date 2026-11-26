extends SceneTree
## Prüft den Juwelier (Gebäude 3): Alarm, Stahltür, Vitrinen.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _team() -> Array:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	return team


func _run(plan: Array) -> Dictionary:
	var s := Sim.create(GameData.TARGETS.juwelier, _team(), {"teo": plan.duplicate(true), "otto": [{"t": "MOVE", "to": "Fluchtwagen"}]}, GameData.CAR)
	var n := 0
	while s.status == "RUNNING" and n < 9000:
		s.step(Sim.DT)
		n += 1
	return {"log": s.log_lines, "sim": s}


func _has(log: Array, text: String) -> bool:
	for l in log:
		if String(l).contains(text):
			return true
	return false


const ENTRY := [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}]


func _init() -> void:
	var s0 := Sim.create(GameData.TARGETS.juwelier, _team(), {"teo": []}, GameData.CAR)
	_check(s0.panel.get("name", "") == "Alarmpanel", "Alarmpanel vorhanden")
	_check(s0.sensors.size() == 2, "Mikrofon im Verkauf und Glasbruchmelder am Schaufenster")
	_check(s0.doors.has(Vector2i(9, 6)) and s0.doors[Vector2i(9, 6)].kind == "stahl", "Stahltür zum Tresorraum")
	_check(Sim.door_tool({"kind": "stahl"}) == "tresor", "Stahltür braucht das Tresor-Werkzeug")

	var r1 := _run(ENTRY + [{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Diamantring"}, {"t": "OPEN", "on": "Diamantring"}, {"t": "TAKE", "loot": "diamantring"}])
	_check(r1.sim.loot["diamantring"].state != "ROOM", "Diamantring aus der Vitrine genommen")

	var r2 := _run(ENTRY + [{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "lockpick", "on": "Stahltür"}])
	_check(_has(r2.log, "nicht geeignet"), "Dietrich passt nicht an die Stahltür")

	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

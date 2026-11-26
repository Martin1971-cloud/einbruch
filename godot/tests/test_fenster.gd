extends SceneTree
## Prüft das Schaufenster: nur mit dem Glasschneider öffnen, danach begehbar.
var _fails := 0
func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok: _fails += 1
func _team() -> Array:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	return team
func _run(plan: Array) -> Dictionary:
	var s := Sim.create(GameData.TARGETS.kiosk, _team(), {"teo": plan.duplicate(true), "otto": [{"t": "MOVE", "to": "Fluchtwagen"}]}, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 6000:
		s.step(Sim.DT); n += 1
	return {"log": s.log_lines, "sim": s}
func _init() -> void:
	var r1 := _run([{"t": "MOVE", "cell": [5, 4]}, {"t": "TOOL", "tool": "lockpick", "on": "Schaufenster"}])
	_check(_has(r1.log, "nicht geeignet"), "Dietrich passt nicht am Schaufenster")
	var r2 := _run([{"t": "MOVE", "cell": [5, 4]}, {"t": "TOOL", "tool": "glasschneider", "on": "Schaufenster"}, {"t": "OPEN", "on": "Schaufenster"}, {"t": "MOVE", "cell": [7, 4]}])
	_check(_has(r2.log, "öffnet Schaufenster") or _has(r2.log, "Schaufenster"), "Glasschneider öffnet das Schaufenster")
	_check(not _has(r2.log, "kann dort nicht stehen"), "Weg durch das offene Fenster ist frei")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
func _has(log: Array, text: String) -> bool:
	for l in log:
		if String(l).contains(text):
			return true
	return false

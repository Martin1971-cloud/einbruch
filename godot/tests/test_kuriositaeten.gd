extends SceneTree
## Prüft den Kuriositätenladen (zwei Etagen): Fenster, Vitrinen, Treppe, Gemälde an der Wand.
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
	var s := Sim.create(GameData.TARGETS.curiosity, _team(), {"teo": plan.duplicate(true), "otto": [{"t": "MOVE", "to": "Fluchtwagen"}]}, GameData.car_now("kombi", 85.0))
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
	var s0 := Sim.create(GameData.TARGETS.curiosity, _team(), {"teo": []}, GameData.CAR)
	_check(s0.doors.has(Vector2i(8, 2)) and s0.doors[Vector2i(8, 2)].kind == "glas", "Schaufenster an der Gasse")
	_check(s0.loot.has("landschaft") and s0.loot["landschaft"].opened, "Gemälde an der Wand ohne Werkzeug")
	_check(s0.loot.has("gemmen") and not s0.loot["gemmen"].opened, "Gemmen-Vitrine im OG verschlossen")

	# Schaufenster: Dietrich passt nicht, Glasschneider öffnet
	var r1 := _run([{"t": "MOVE", "to": "Außen vor dem Schaufenster"}, {"t": "TOOL", "tool": "lockpick", "on": "Schaufenster"}])
	_check(_has(r1.log, "nicht geeignet"), "Dietrich passt nicht am Schaufenster")
	var r2 := _run([{"t": "MOVE", "to": "Außen vor dem Schaufenster"}, {"t": "TOOL", "tool": "glasschneider", "on": "Schaufenster"}, {"t": "OPEN", "on": "Schaufenster"}])
	_check(_has(r2.log, "Schaufenster"), "Glasschneider öffnet das Schaufenster")

	# Erdgeschoss: Uhrensammlung in der Vitrine
	var r3 := _run(ENTRY + [{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Uhrensammlung"}, {"t": "OPEN", "on": "Uhrensammlung"}, {"t": "TAKE", "loot": "uhren"}])
	_check(r3.sim.loot["uhren"].state != "ROOM", "Uhrensammlung im Verkaufsraum genommen")

	# Gemälde an der Wand ohne Werkzeug
	var r4 := _run(ENTRY + [{"t": "MOVE", "cell": [4, 6]}, {"t": "TAKE", "loot": "landschaft"}])
	_check(r4.sim.loot["landschaft"].state != "ROOM", "Gemälde „Landschaft“ wird abgenommen")

	# Treppe: ins OG, Gemmen-Vitrine
	var r5 := _run(ENTRY + [{"t": "MOVE", "cell": [4, 8]}, {"t": "TREPPE"}, {"t": "MOVE", "cell": [4, 17]}, {"t": "TOOL", "tool": "lockpick", "on": "Gemmensammlung"}, {"t": "OPEN", "on": "Gemmensammlung"}, {"t": "TAKE", "loot": "gemmen"}])
	_check(_has(r5.log, "anderen Etage"), "Treppe wechselt die Etage")
	_check(r5.sim.loot["gemmen"].state != "ROOM", "Gemmen im Obergeschoss genommen")

	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

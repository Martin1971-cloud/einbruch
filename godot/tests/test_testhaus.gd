extends SceneTree
## Prüft das Testgebäude: Stahltür braucht das Tresor-Werkzeug, Vitrine lässt sich öffnen, Alarmpanel ist da.
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
	var s := Sim.create(GameData.TARGETS.testhaus, _team(), {"teo": plan.duplicate(true), "otto": [{"t": "MOVE", "to": "Fluchtwagen"}]}, GameData.car_now("kombi", 85.0))
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


const ENTRY_PLAN := [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}]


func _init() -> void:
	# Werkzeug-Zuordnung
	_check(Sim.door_tool({"kind": "stahl"}) == "tresor", "Stahltür: Tresor-Werkzeug")
	_check(Sim.door_tool({"kind": "glas"}) == "glas", "Schaufenster: Glasschneider")
	_check(Sim.door_tool({}) == "schloss", "normale Tür: Schloss-Werkzeug")

	# Aufbau: Tür, Panel, Vitrine und Beute sind im Grundriss richtig gesetzt
	var s0 := Sim.create(GameData.TARGETS.testhaus, _team(), {"teo": []}, GameData.CAR)
	_check(s0.doors.has(Vector2i(9, 6)) and s0.doors[Vector2i(9, 6)].kind == "stahl", "Stahltür an Position [9, 6]")
	_check(s0.panel.get("name", "") == "Alarmpanel", "Alarmpanel vorhanden")
	_check(s0.loot.has("diamant") and s0.loot["diamant"].pos == Vector2i(4, 4), "Diamantkette in der Vitrine [4, 4]")
	_check(Sim.plan_tile(GameData.TARGETS.testhaus, Vector2i(4 * 16 + 8, 4 * 16 + 8)) == "C", "Vitrine liegt auf einem C-Feld")

	# Lockpick passt nicht an die Stahltür
	var r1 := _run([{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}, {"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "lockpick", "on": "Stahltür"}])
	_check(_has(r1.log, "nicht geeignet"), "Dietrich passt nicht an die Stahltür")

	# Schneidbrenner öffnet die Stahltür (Werkzeug wird angesetzt)
	var r2 := _run([{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}, {"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "Stahltür"}])
	_check(_has(r2.log, "setzt Schneidbrenner an Stahltür"), "Schneidbrenner wird an der Stahltür angesetzt")
	_check(not _has(r2.log, "nicht geeignet"), "Schneidbrenner ist für die Stahltür geeignet")

	# Vitrine: Dietrich entriegelt, danach öffnen
	var r3 := _run([{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}, {"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Diamantkette"}, {"t": "OPEN", "on": "Diamantkette"}])
	_check(_has(r3.log, "Diamantkette"), "Vitrine wird bearbeitet")
	_check(r3.sim.loot["diamant"].opened, "Diamantkette: Vitrine ist offen")

	# Gemälde: ohne Werkzeug abnehmen
	var r4 := _run(ENTRY_PLAN + [{"t": "MOVE", "cell": [4, 6]}, {"t": "TAKE", "loot": "gemaelde"}])
	_check(r4.sim.loot["gemaelde"].state != "ROOM", "Gemälde wird ohne Werkzeug abgenommen")

	# Etagen: ohne Treppe kommt man nicht ins Obergeschoss, mit Treppe schon
	var r5 := _run(ENTRY_PLAN + [{"t": "MOVE", "cell": [4, 17]}])
	_check(_has(r5.log, "Kein Weg") or _has(r5.log, "blockiert") or _has(r5.log, "nicht"), "ohne Treppe kein Weg ins Obergeschoss")
	var r6 := _run(ENTRY_PLAN + [{"t": "MOVE", "cell": [4, 8]}, {"t": "TREPPE"}, {"t": "MOVE", "cell": [4, 17]}, {"t": "TOOL", "tool": "lockpick", "on": "Münzsammlung (OG)"}, {"t": "OPEN", "on": "Münzsammlung (OG)"}, {"t": "TAKE", "loot": "muenzen_og"}])
	_check(_has(r6.log, "anderen Etage"), "Treppe wechselt die Etage")
	_check(r6.sim.loot["muenzen_og"].state != "ROOM", "Münzen im Obergeschoss erreicht und genommen")

	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

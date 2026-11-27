extends SceneTree
## Vollständiger Einbruch in den bestehenden Gebäuden Kurioitätenladen und Juwelier:
## der Plan läuft ohne Skriptfehler bis zum Ende, es wird Beute genommen und ausgezahlt.
## Aufruf: godot --headless --path . --script res://tests/test_ziel_durchlauf.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _team(ids: Array) -> Array:
	var out := []
	for c in GameData.CREW:
		if ids.has(c.id):
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			out.append(d)
	return out


func _lauf(tid: String, plan: Array, team: Array, plans: Dictionary) -> Dictionary:
	var sim := Sim.create(GameData.TARGETS[tid], team, plans, GameData.car_now("limo", 85.0))
	var n := 0
	while sim.status == "RUNNING" and n < 20000:
		sim.step(Sim.DT)
		n += 1
	return {"sim": sim, "schritte": n}


func _init() -> void:
	var einstieg := [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
	]
	var ende := [{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}]
	var plan_kurio: Array = einstieg + [
		{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "uhren"}, {"t": "OPEN", "on": "uhren"}, {"t": "TAKE", "loot": "uhren"},
		{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "besteck"}, {"t": "OPEN", "on": "besteck"}, {"t": "TAKE", "loot": "besteck"},
	] + ende
	# Juwelier: Einstieg über das Schaufenster (nicht alarmgesichert), dann das Alarmpanel von innen überbrücken.
	var plan_juwelier: Array = [
		{"t": "MOVE", "to": "aussen_schaufenster"},
		{"t": "TOOL", "tool": "glasschneider", "on": "schaufenster"},
		{"t": "MOVE", "cell": [4, 3]},
		{"t": "TOOL", "tool": "bypass", "on": "alarmpanel"},
		{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "diamantring"}, {"t": "OPEN", "on": "diamantring"}, {"t": "TAKE", "loot": "diamantring"},
		{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "perlen"}, {"t": "OPEN", "on": "perlen"}, {"t": "TAKE", "loot": "perlen"},
		{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
		{"t": "MOVE", "cell": [12, 7]}, {"t": "TOOL", "tool": "lockpick", "on": "tresor"}, {"t": "OPEN", "on": "tresor"}, {"t": "TAKE", "loot": "tresor"},
	] + ende

	for fall in [["curiosity", plan_kurio], ["juwelier", plan_juwelier]]:
		var tid: String = fall[0]
		var plan: Array = fall[1]
		print("== %s ==" % tid)
		var team := _team(["teo"])
		var ergebnis := _lauf(tid, plan, team, {"teo": plan.duplicate(true)})
		var sim: Sim = ergebnis.sim
		_check(sim.status != "RUNNING", "%s: Lauf ist zu Ende (%d Schritte)" % [tid, ergebnis.schritte])
		_check(sim.loot.size() > 0, "%s: Beute vorhanden" % tid)
		var genommen := 0
		for lid in sim.loot:
			if sim.loot[lid].state == "CARRIED":
				genommen += 1
		if tid == "curiosity":
			_check(sim.payout > 0, "%s: es gibt eine Auszahlung (%d €)" % [tid, sim.payout])
		else:
			_check(sim.payout > 0, "%s: es gibt eine Auszahlung (%d €)" % [tid, sim.payout])
			_check(not sim.alarm_active and not sim.log_lines.any(func(l): return "ALARM" in str(l)), "%s: Einstieg über das Schaufenster und Überbrückung bleiben ohne Alarm" % tid)
		var fehler := []
		for sg in sim.crew[0].get("segments", []):
			if str(sg.get("fail", "")) != "" and str(sg.t) != "TAKE":
				fehler.append("%s: %s" % [sg.t, sg.fail])
		_check(fehler.is_empty(), "%s: Werkzeug und Öffnen schlagen nie fehl %s" % [tid, str(fehler)])
		_check(sim.log_lines.size() > 0, "%s: Ereignisprotokoll nicht leer" % tid)
	# Gesicherte Tür aufbrechen (ohne Überbrückung) löst den Alarm aus, wie das Öffnen
	print("== Aufbrechen ==")
	var plan_bruch: Array = [
		{"t": "MOVE", "to": "aussen_schaufenster"}, {"t": "TOOL", "tool": "glasschneider", "on": "schaufenster"},
		{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
		{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}]
	var bruch := _lauf("juwelier", plan_bruch, _team(["teo"]), {"teo": plan_bruch.duplicate(true)})
	_check(bruch.sim.alarm_active or bruch.sim.log_lines.any(func(l): return "ALARM" in str(l)), "juwelier: Stahltür aufbrechen ohne Überbrückung löst Alarm aus")

	# Grundsatz: Jedes Gebäude mit Alarmanlage hat einen Zugang von außen, der nicht alarmgesichert ist.
	print("== Einstieg ohne Alarm ==")
	for tid in GameData.ORDER:
		var t: Dictionary = GameData.TARGETS[tid]
		if tid == "museum":
			continue  # geplant, noch nicht gebaut
		if not t.has("panel"):
			continue
		var sim := Sim.create(t, [], {}, GameData.car_now("limo", 85.0))
		for k in sim.doors.keys():
			sim.open_cells[k] = true
		var starts: Array = []
		for pid in ["aussen_eingang", "aussen_schaufenster"]:
			if t.points.has(pid):
				starts.append(Sim._v2i(t.points[pid]))
		var zugang := false
		for d in t.get("doors", []):
			if t.get("gesichert", []).has(str(d.id)):
				continue
			var tuer := Sim._v2i(d.pos)
			for start in starts:
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = tuer + dd
					if n == start or not sim.path_to(Sim.center(start), n).is_empty():
						zugang = true
		_check(zugang, "%s: mindestens ein nicht alarmgesicherter Zugang von außen" % tid)
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

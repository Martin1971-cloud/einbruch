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


func _erreichbar(sim: Sim, starts: Array, tuer: Vector2i) -> bool:
	for start in starts:
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = tuer + dd
			if n == start or not sim.path_to(Sim.center(start), n).is_empty():
				return true
	return false


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
		{"t": "TOOL", "tool": "glasschneider", "on": "schaufenster"}, {"t": "OPEN", "on": "schaufenster"},
		{"t": "MOVE", "cell": [4, 3]},
		{"t": "TOOL", "tool": "bypass", "on": "alarmpanel"},
		{"t": "MOVE", "cell": [8, 3]}, {"t": "CLOSE", "on": "schaufenster"},
		{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "diamantring"}, {"t": "OPEN", "on": "diamantring"}, {"t": "TAKE", "loot": "diamantring"},
		{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "perlen"}, {"t": "OPEN", "on": "perlen"}, {"t": "TAKE", "loot": "perlen"},
		{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
		{"t": "MOVE", "cell": [12, 7]}, {"t": "TOOL", "tool": "lockpick", "on": "tresor"}, {"t": "OPEN", "on": "tresor"}, {"t": "TAKE", "loot": "tresor"},
		# Ausgang über das Fenster: öffnen, hinausgehen, von außen wieder schließen
		{"t": "MOVE", "cell": [8, 3]}, {"t": "OPEN", "on": "schaufenster"},
		{"t": "MOVE", "to": "aussen_schaufenster"}, {"t": "CLOSE", "on": "schaufenster"},
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
			# Nur der Einstieg zählt: bis zur ersten Vitrine darf kein Alarm kommen (die aufgebrochene Stahltür später ist eine eigene Regel)
			var einstieg_ok := true
			for l in sim.log_lines:
				if "Diamantring" in str(l):
					break
				if "ALARM" in str(l):
					einstieg_ok = false
			_check(einstieg_ok, "%s: Einstieg über das Schaufenster und Überbrückung bleiben ohne Alarm" % tid)
		var fehler := []
		for sg in sim.crew[0].get("segments", []):
			if str(sg.get("fail", "")) != "" and str(sg.t) != "TAKE":
				fehler.append("%s: %s" % [sg.t, sg.fail])
		_check(fehler.is_empty(), "%s: Werkzeug und Öffnen schlagen nie fehl %s" % [tid, str(fehler)])
		_check(sim.log_lines.size() > 0, "%s: Ereignisprotokoll nicht leer" % tid)
	# Gesicherte Tür aufbrechen (ohne Überbrückung) löst den Alarm aus, wie das Öffnen
	print("== Aufbrechen ==")
	var plan_bruch: Array = [
		{"t": "MOVE", "to": "aussen_schaufenster"}, {"t": "TOOL", "tool": "glasschneider", "on": "schaufenster"}, {"t": "OPEN", "on": "schaufenster"},
		{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
		{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}]
	var bruch := _lauf("juwelier", plan_bruch, _team(["teo"]), {"teo": plan_bruch.duplicate(true)})
	_check(bruch.sim.alarm_active or bruch.sim.log_lines.any(func(l): return "ALARM" in str(l)), "juwelier: Stahltür aufbrechen ohne Überbrückung löst Alarm aus")

	# Grundsatz: Jedes Gebäude mit Alarmanlage braucht einen Weg ohne Alarm von außen. Entweder eine
	# Schwachstelle (Tür oder Fenster ohne Alarmkontakt) oder die Eintrittskarte des Informanten für die Haupttür.
	print("== Einstieg ohne Alarm ==")
	for tid in GameData.ORDER:
		var t: Dictionary = GameData.TARGETS[tid]
		if not t.has("panel"):
			continue
		var sim := Sim.create(t, [], {}, GameData.car_now("limo", 85.0))
		for k in sim.doors.keys():
			sim.open_cells[k] = true
		var starts: Array = []
		for pid in ["aussen_eingang", "aussen_schaufenster"]:
			if t.points.has(pid):
				starts.append(Sim._v2i(t.points[pid]))
		var schwachstelle := false
		for d in t.get("doors", []):
			if t.get("gesichert", []).has(str(d.id)):
				continue
			if _erreichbar(sim, starts, Sim._v2i(d.pos)):
				schwachstelle = true
		var karte_weg := false
		var kt := str(t.get("karte_tuer", ""))
		if kt != "" and t.get("gesichert", []).has(kt):
			for d in t.get("doors", []):
				if str(d.id) == kt and _erreichbar(sim, starts, Sim._v2i(d.pos)):
					karte_weg = true
		_check(schwachstelle or karte_weg, "%s: Einstieg ohne Alarm über Schwachstelle oder Eintrittskarte" % tid)

	# Museum (geplant): Die Haupttür öffnet nur mit der Eintrittskarte ohne Alarm
	print("== Museum: Eintrittskarte ==")
	var mus: Dictionary = GameData.TARGETS["museum"]
	var plan_tuer: Array = [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
	]
	var sim_ohne := Sim.create(mus, _team(["teo"]), {"teo": plan_tuer.duplicate(true)}, GameData.car_now("limo", 85.0), false)
	var sim_mit := Sim.create(mus, _team(["teo"]), {"teo": plan_tuer.duplicate(true)}, GameData.car_now("limo", 85.0), true)
	for _i in range(4000):
		if sim_ohne.status == "RUNNING":
			sim_ohne.step(Sim.DT)
		if sim_mit.status == "RUNNING":
			sim_mit.step(Sim.DT)
	# Geprüft wird der Alarmkontakt der Anlage; Wachen, die die Tür sehen, sind ein eigenes System.
	_check(sim_ohne.log_lines.any(func(l): return "ALARM durch Alarmpanel" in str(l)), "museum: ohne Karte löst die Haupttür den Alarm der Anlage aus")
	_check(not sim_mit.log_lines.any(func(l): return "ALARM durch Alarmpanel" in str(l)), "museum: mit Karte kein Alarm der Anlage an der Haupttür")
	_check(sim_mit.log_lines.any(func(l): return "Eintrittskarte" in str(l)), "museum: die Karte wird im Protokoll genannt")
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

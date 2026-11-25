extends SceneTree
## Balancing-Testdurchlauf (ohne Grafik): je Gebäude drei Teamgrößen, Ergebnis, Auszahlung und Kosten.
## Aufruf: godot --headless --path . --script res://tests/balance_lauf.gd


func _crew(id: String) -> Dictionary:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			return d
	return {}


func _run(target_id: String, team_ids: Array, plan: Array) -> Dictionary:
	var team := []
	var plans := {}
	for id in team_ids:
		team.append(_crew(id))
	# Teodor macht den Einbruch, die anderen gehen zum Wagen
	for id in team_ids:
		plans[id] = [{"t": "MOVE", "to": "Fluchtwagen"}]
	plans["teo"] = plan.duplicate(true)
	plans["otto"] = [{"t": "MOVE", "to": "Fluchtwagen"}]
	if not team_ids.has("otto"):
		team.append(_crew("otto"))
	var s := Sim.create(GameData.TARGETS[target_id], team, plans, GameData.CAR)
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	var fees := 0
	for c in team:
		fees += int(c.fee)
	return {"status": s.status, "payout": s.payout, "fees": fees, "car": int(GameData.CAR.fee), "time": s.time, "alarm": s.alarm_active}


func _plans() -> Dictionary:
	var entry := [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"}]
	var back := [{"t": "MOVE", "to": "Fluchtwagen"}]
	return {
		"kiosk": [
			{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"},
			{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"}, {"t": "OPEN", "on": "Kassenlade"}, {"t": "TAKE", "loot": "kasse"},
			{"t": "MOVE", "cell": [8, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "Wertschrank"}, {"t": "OPEN", "on": "Wertschrank"}, {"t": "TAKE", "loot": "safe"},
			{"t": "CALL_CAR"}, {"t": "MOVE", "to": "Fluchtwagen"},
		],
		"curiosity": entry + [
			{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Uhrensammlung"}, {"t": "OPEN", "on": "Uhrensammlung"}, {"t": "TAKE", "loot": "uhren"},
			{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Silberbesteck"}, {"t": "OPEN", "on": "Silberbesteck"}, {"t": "TAKE", "loot": "besteck"},
			{"t": "MOVE", "cell": [4, 6]}, {"t": "TAKE", "loot": "landschaft"},
			{"t": "MOVE", "cell": [4, 8]}, {"t": "TREPPE"}, {"t": "MOVE", "cell": [4, 17]}, {"t": "TOOL", "tool": "lockpick", "on": "Gemmensammlung"}, {"t": "OPEN", "on": "Gemmensammlung"}, {"t": "TAKE", "loot": "gemmen"},
			{"t": "MOVE", "cell": [4, 20]}, {"t": "TREPPE"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "Fluchtwagen"},
		],
		"juwelier": entry + [
			{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Diamantring"}, {"t": "OPEN", "on": "Diamantring"}, {"t": "TAKE", "loot": "diamant"},
			{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "Perlenkette"}, {"t": "OPEN", "on": "Perlenkette"}, {"t": "TAKE", "loot": "perlen"},
			{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "Stahltür"},
			{"t": "MOVE", "cell": [12, 7]}, {"t": "TOOL", "tool": "lockpick", "on": "Tresorinhalt (Schmuck und Bargeld)"}, {"t": "OPEN", "on": "Tresorinhalt (Schmuck und Bargeld)"}, {"t": "TAKE", "loot": "tresor"},
			{"t": "CALL_CAR"}, {"t": "MOVE", "to": "Fluchtwagen"},
		],
	}


func _init() -> void:
	var plans := _plans()
	var teams := [["teo"], ["teo", "ilja"], ["teo", "ilja", "rosa"]]
	for tid in ["kiosk", "curiosity", "juwelier"]:
		print("== %s ==" % tid)
		for t in teams:
			var r := _run(tid, t, plans[tid])
			var net: int = int(r.payout) - int(r.fees) - int(r.car)
			print("  Team %d: %-22s Auszahlung %7d  Kosten %6d  Ergebnis %+7d  Zeit %5.0f s  Alarm %s" % [t.size(), str(r.status), int(r.payout), int(r.fees) + int(r.car), net, float(r.time), str(r.alarm)])
	quit(0)

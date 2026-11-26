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


func _run_plans(target_id: String, team_ids: Array, plans: Dictionary) -> Dictionary:
	var team := []
	for id in team_ids:
		team.append(_crew(id))
	if not team_ids.has("otto"):
		team.append(_crew("otto"))
	var s := Sim.create(GameData.TARGETS[target_id], team, plans, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	var fees := 0
	for c in team:
		fees += int(c.fee)
	return {"status": s.status, "payout": s.payout, "fees": fees, "car": int(GameData.CARS.limo.rent), "time": s.time, "alarm": s.alarm_active}


func _run(target_id: String, team_ids: Array, plan: Array) -> Dictionary:
	var team := []
	var plans := {}
	for id in team_ids:
		team.append(_crew(id))
	# Teodor macht den Einbruch, die anderen gehen zum Wagen
	for id in team_ids:
		plans[id] = [{"t": "MOVE", "to": "fluchtwagen"}]
	plans["teo"] = plan.duplicate(true)
	plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
	if not team_ids.has("otto"):
		team.append(_crew("otto"))
	var s := Sim.create(GameData.TARGETS[target_id], team, plans, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	var fees := 0
	for c in team:
		fees += int(c.fee)
	return {"status": s.status, "payout": s.payout, "fees": fees, "car": int(GameData.CARS.limo.rent), "time": s.time, "alarm": s.alarm_active}


## Verteilt den Plan auf das Team: der Eingang bleibt bei Teodor, jeder Werkzeug-Block (Gehen + Werkzeug + Öffnen + Beute)
## geht reihum an die Teammitglieder. Alle gehen am Ende zum Fluchtwagen, Teodor ruft den Wagen.
func _verteilt(plan: Array, ids: Array) -> Dictionary:
	var blocks: Array = []
	var cur: Array = []
	var pending_move: Dictionary = {}
	var ende: Array = []
	for a in plan:
		if a.t == "CALL_CAR" or (a.t == "MOVE" and a.get("to", "") == "Fluchtwagen"):
			ende.append(a)
			continue
		if a.t == "MOVE" and a.has("cell"):
			if not cur.is_empty():
				blocks.append(cur)
				cur = []
			pending_move = a
			continue
		if a.t == "TOOL":
			if not cur.is_empty():
				blocks.append(cur)
			cur = []
		# Gehbewegung und Aktion (Werkzeug, Beute, Treppe) bleiben im selben Block
		if cur.is_empty() and not pending_move.is_empty():
			cur.append(pending_move)
			pending_move = {}
		cur.append(a)
	if not cur.is_empty():
		blocks.append(cur)
	var out := {}
	for id in ids:
		out[id] = []
	# erster Block (Eingang) gehört Teodor, die übrigen reihum an alle, die das Werkzeug können (Fähigkeit mindestens erreicht)
	var zaehler := 0
	var letzter := "teo"
	var oben := false   # Zwischen Treppe hinauf und Treppe hinunter bleibt eine Person zusammen
	for i in range(blocks.size()):
		var who: String = "teo"
		if i > 0:
			if oben or not _hat_werkzeug(blocks[i]):
				who = letzter
			else:
				var kandidaten := _kann(blocks[i], ids)
				who = kandidaten[zaehler % kandidaten.size()]
				zaehler += 1
		out[who].append_array(blocks[i])
		letzter = who
		if _hat_treppe(blocks[i]):
			oben = not oben
	for id in ids:
		if id != "teo":
			# Warten vor der Tür, bis Teodor den Eingang geöffnet hat (sonst scheitern die Wege sofort)
			out[id] = [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "WAIT", "sec": 18.0}] + out[id]
			out[id].append({"t": "MOVE", "to": "fluchtwagen"})
	out["teo"].append_array(ende)
	return out


func _hat_treppe(block: Array) -> bool:
	for a in block:
		if a.t == "TREPPE":
			return true
	return false


func _hat_werkzeug(block: Array) -> bool:
	for a in block:
		if a.t == "TOOL":
			return true
	return false


## Wer kann einen Block ausführen? Alle Teammitglieder, deren Fähigkeit für das Werkzeug mindestens den Mindestwert hat.
func _kann(block: Array, ids: Array) -> Array:
	var werkzeug := ""
	for a in block:
		if a.t == "TOOL":
			werkzeug = str(a.tool)
	if werkzeug == "":
		return ids
	var t: Dictionary = GameData.TOOLS[werkzeug]
	var ok: Array = []
	for id in ids:
		var c := _crew(id)
		if float(c.skills.get(t.type, 0)) >= float(t.get("min", 0)):
			ok.append(id)
	return ok if not ok.is_empty() else ["teo"]


func _plans() -> Dictionary:
	var entry := [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"}]
	var back := [{"t": "MOVE", "to": "fluchtwagen"}]
	return {
		"kiosk": [
			{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"},
			{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "kasse"}, {"t": "OPEN", "on": "kasse"}, {"t": "TAKE", "loot": "kasse"},
			{"t": "MOVE", "cell": [8, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "safe"}, {"t": "OPEN", "on": "safe"}, {"t": "TAKE", "loot": "safe"},
			{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
		],
		"curiosity": entry + [
			{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "uhren"}, {"t": "OPEN", "on": "uhren"}, {"t": "TAKE", "loot": "uhren"},
			{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "besteck"}, {"t": "OPEN", "on": "besteck"}, {"t": "TAKE", "loot": "besteck"},
			{"t": "MOVE", "cell": [4, 6]}, {"t": "TAKE", "loot": "landschaft"},
			{"t": "MOVE", "cell": [4, 8]}, {"t": "TREPPE"}, {"t": "MOVE", "cell": [4, 17]}, {"t": "TOOL", "tool": "lockpick", "on": "gemmen"}, {"t": "OPEN", "on": "gemmen"}, {"t": "TAKE", "loot": "gemmen"},
			{"t": "MOVE", "cell": [4, 20]}, {"t": "TREPPE"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
		],
		"juwelier": entry + [
			{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "diamantring"}, {"t": "OPEN", "on": "diamantring"}, {"t": "TAKE", "loot": "diamantring"},
			{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "perlen"}, {"t": "OPEN", "on": "perlen"}, {"t": "TAKE", "loot": "perlen"},
			{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
			{"t": "MOVE", "cell": [12, 7]}, {"t": "TOOL", "tool": "lockpick", "on": "tresor"}, {"t": "OPEN", "on": "tresor"}, {"t": "TAKE", "loot": "tresor"},
			{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
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
	print("== mit verteilter Arbeit (gleiche Teams, Arbeit geteilt) ==")
	for tid in ["kiosk", "curiosity", "juwelier"]:
		print("== %s verteilt ==" % tid)
		for t in teams:
			if t.size() < 2:
				continue
			var ids: Array = t
			var r := _run_plans(tid, ids, _verteilt(plans[tid], ids))
			var net: int = int(r.payout) - int(r.fees) - int(r.car)
			print("  Team %d: %-22s Auszahlung %7d  Kosten %6d  Ergebnis %+7d  Zeit %5.0f s  Alarm %s" % [t.size(), str(r.status), int(r.payout), int(r.fees) + int(r.car), net, float(r.time), str(r.alarm)])
	quit(0)

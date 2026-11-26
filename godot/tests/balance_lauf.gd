extends SceneTree
## Balancing-Testdurchlauf (ohne Grafik): je Gebäude, Fahrzeug und Teamgröße Ergebnis, Auszahlung und Kosten.
## Aufruf: godot --headless --path . --script res://tests/balance_lauf.gd

## Grundausrüstung für jedes Teammitglied (einmalige Anschaffung, wirkt auch in der Simulation).
const GEAR_BASIS := "gloves"
const AUTOS := ["limo", "kleinwagen", "kleinlaster", "kombi", "sport"]


func _crew(id: String) -> Dictionary:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = [GEAR_BASIS]
			return d
	return {}


## Einmalige Kosten der Werkzeuge: jedes Werkzeug, das in irgendeinem Plan vorkommt, wird einmal gekauft.
func _werkzeug_kosten(plans: Dictionary) -> int:
	var nutzt := {}
	for pid in plans:
		for a in plans[pid]:
			if a.t == "TOOL":
				nutzt[str(a.tool)] = true
	var summe := 0
	for w in nutzt:
		summe += int(GameData.TOOLS[w].price)
	return summe


## Einmalige Kosten der Kleidung: je Teammitglied (inkl. Otto).
func _kleidung_kosten(anzahl: int) -> int:
	return anzahl * int(GameData.GEAR[GEAR_BASIS].price)


## Ein Lauf mit festem Plan: Teodor führt den Einbruch aus, die anderen gehen zum Wagen.
func _run(target_id: String, team_ids: Array, plan: Array, car: String) -> Dictionary:
	var team := []
	var plans := {}
	for id in team_ids:
		team.append(_crew(id))
	for id in team_ids:
		plans[id] = [{"t": "MOVE", "to": "fluchtwagen"}]
	plans["teo"] = plan.duplicate(true)
	if not team_ids.has("otto"):
		team.append(_crew("otto"))
	plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
	return _lauf(target_id, team, plans, car)


func _lauf(target_id: String, team: Array, plans: Dictionary, car: String) -> Dictionary:
	var s := Sim.create(GameData.TARGETS[target_id], team, plans, GameData.car_now(car, 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	var fees := 0
	for c in team:
		fees += int(c.fee)
	return {"status": s.status, "payout": s.payout, "fees": fees, "time": s.time, "alarm": s.alarm_active,
		"crew": team.size(), "werkzeug": _werkzeug_kosten(plans), "car": car, "heat": s.fence_heat()}


## Verteilt den Plan auf das Team: der Eingang bleibt bei Teodor, jeder Werkzeug-Block (Gehen + Werkzeug + Öffnen + Beute)
## geht reihum an die Teammitglieder, die das Werkzeug können. Alle warten vor der Tür, bis der Eingang offen ist.
func _verteilt(plan: Array, ids: Array) -> Dictionary:
	var blocks: Array = []
	var cur: Array = []
	var pending_move: Dictionary = {}
	var ende: Array = []
	for a in plan:
		if a.t == "CALL_CAR" or (a.t == "MOVE" and a.get("to", "") == "fluchtwagen"):
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
		if cur.is_empty() and not pending_move.is_empty():
			cur.append(pending_move)
			pending_move = {}
		cur.append(a)
	if not cur.is_empty():
		blocks.append(cur)
	var out := {}
	for id in ids:
		out[id] = []
	var zaehler := 0
	var letzter := "teo"
	var oben := false
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


## Aufgaben je Person (ohne Gehen und Warten), zur Diagnose der Verteilung.
func _aufgaben(plans: Dictionary) -> String:
	var teile := []
	for id in plans:
		var n := 0
		for a in plans[id]:
			if a.t != "MOVE" and a.t != "WAIT":
				n += 1
		teile.append("%s %d" % [id, n])
	return ", ".join(teile)


func _plans() -> Dictionary:
	var entry := [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"}]
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


func _zeile(r: Dictionary) -> String:
	var car_rent := int(GameData.CARS[r.car].rent)
	var car_kauf := 0 if car_rent > 0 else int(GameData.CARS[r.car].price)
	var net: int = int(r.payout) - int(r.fees) - car_rent
	var ausr: int = int(r.werkzeug) + _kleidung_kosten(int(r.crew)) + car_kauf
	var kontostand: int = Game.START_MONEY - ausr + net
	return "  %-10s %d Pers.: %-16s Auszahlung %6d  Laufkosten %6d  Ergebnis %+8d  Erstausstattung %6d  Kontostand %+8d  Zeit %4.0f s  Alarm %-5s Hitze %5.1f" % [
		r.car, int(r.crew), str(r.status), int(r.payout), int(r.fees) + car_rent, net, ausr, kontostand, float(r.time), str(r.alarm), float(r.heat)]


func _init() -> void:
	var plans := _plans()
	var teams := [["teo"], ["teo", "ilja"], ["teo", "ilja", "rosa"]]
	print("Startgeld: %d €, Grundausrüstung je Person: %s" % [Game.START_MONEY, GEAR_BASIS])
	for tid in ["kiosk", "curiosity", "juwelier"]:
		print("== %s ==" % tid)
		for car in AUTOS:
			for t in teams:
				print(_zeile(_run(tid, t, plans[tid], car)))
	print("== mit verteilter Arbeit (Otto gehört jetzt zum Team der Aufgaben) ==")
	for tid in ["kiosk", "curiosity", "juwelier"]:
		print("== %s verteilt ==" % tid)
		for t in [["teo", "otto"], ["teo", "ilja", "otto"], ["teo", "ilja", "rosa", "otto"]]:
			var verteilt := _verteilt(plans[tid], t)
			var r := _lauf(tid, _teamliste(t), verteilt, "limo")
			print(_zeile(r))
			print("      Aufgaben je Person: %s" % _aufgaben(verteilt))
	quit(0)


func _teamliste(ids: Array) -> Array:
	var team := []
	for id in ids:
		team.append(_crew(id))
	return team

extends SceneTree
## Kiosk mit mehreren Personen: Arbeitsteilung über Signal "tuer" (Teodor öffnet die Tür, die anderen folgen).
## Aufruf: godot --headless --path . --script res://tests/kiosk_team.gd


func _crew(id: String) -> Dictionary:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			return d
	return {}


func _run(team_ids: Array, plans: Dictionary) -> Dictionary:
	var team := []
	for id in team_ids:
		team.append(_crew(id))
	var all := plans.duplicate(true)
	if not team_ids.has("otto"):
		team.append(_crew("otto"))
	all["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
	var s := Sim.create(GameData.TARGETS.kiosk, team, all, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	var fees := 0
	for c in team:
		fees += int(c.fee)
	return {"status": s.status, "payout": s.payout, "fees": fees, "car": int(GameData.CARS.limo.rent), "time": s.time, "log": s.log_lines}


func _init() -> void:
	var door := [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "FLAG_WAIT", "flag": "tuer"}]
	var teo_entry := [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"}, {"t": "FLAG_SET", "flag": "tuer"}]
	var variants := {
		"Teo allein": {
			"ids": ["teo"],
			"plans": {"teo": [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"},
				{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "kasse"}, {"t": "OPEN", "on": "kasse"}, {"t": "TAKE", "loot": "kasse"},
				{"t": "MOVE", "cell": [8, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "safe"}, {"t": "OPEN", "on": "safe"}, {"t": "TAKE", "loot": "safe"},
				{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}]},
		},
		"Teo + Ilja": {
			"ids": ["teo", "ilja"],
			"plans": {
				"teo": teo_entry + [{"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "kasse"}, {"t": "OPEN", "on": "kasse"}, {"t": "TAKE", "loot": "kasse"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}],
				"ilja": door + [{"t": "MOVE", "cell": [8, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "safe"}, {"t": "OPEN", "on": "safe"}, {"t": "TAKE", "loot": "safe"}, {"t": "MOVE", "to": "fluchtwagen"}],
			},
		},
		"Teo + Ilja + Rosa": {
			"ids": ["teo", "ilja", "rosa"],
			"plans": {
				"teo": teo_entry + [{"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "kasse"}, {"t": "OPEN", "on": "kasse"}, {"t": "TAKE", "loot": "kasse"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"}],
				"ilja": door + [{"t": "MOVE", "cell": [8, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "safe"}, {"t": "OPEN", "on": "safe"}, {"t": "MOVE", "to": "fluchtwagen"}],
				"rosa": door + [{"t": "MOVE", "cell": [8, 3]}, {"t": "WAIT", "sec": 40}, {"t": "TAKE", "loot": "safe"}, {"t": "MOVE", "to": "fluchtwagen"}],
			},
		},
	}
	for name in variants:
		var v: Dictionary = variants[name]
		var r := _run(v.ids, v.plans)
		var net: int = int(r.payout) - int(r.fees) - int(r.car)
		print("== %s ==" % name)
		print("  %s · Auszahlung %d · Kosten %d · Ergebnis %+d · Zeit %.0f s" % [str(r.status), int(r.payout), int(r.fees) + int(r.car), net, float(r.time)])
		for l in r.log:
			if String(l).contains("nicht") or String(l).contains("fehl") or String(l).contains("kann"):
				print("    | ", l)
	quit(0)

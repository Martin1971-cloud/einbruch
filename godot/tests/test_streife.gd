extends SceneTree
## Streife: fährt in zufälligen Abständen von 3 bis 5 Minuten vorbei und sieht offene Türen.
## Aufruf: godot --headless --path . --script res://tests/test_streife.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _team() -> Array:
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			return [d]
	return []


func _lauf(plan: Array, sekunden: float) -> Sim:
	var sim := Sim.create(GameData.TARGETS["kiosk"], _team(), {"teo": plan}, GameData.car_now("limo", 85.0))
	var n := 0
	while sim.time < sekunden and sim.status == "RUNNING" and n < 200000:
		sim.step(Sim.DT)
		n += 1
	return sim


func _streife_alarm(sim: Sim) -> bool:
	return sim.log_lines.any(func(l): return "Streife" in str(l) and "ALARM" in str(l))


func _init() -> void:
	var oeffnen := [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
	]
	var warten := [{"t": "WAIT", "sec": 900.0}]

	# Offene Tür bleibt offen: die Streife sieht sie und schlägt Alarm
	var offen := _lauf(oeffnen + warten, 900.0)
	_check(_streife_alarm(offen), "offene Tür: die Streife schlägt Alarm")

	# Tür wieder zu, bevor die Streife kommt: kein Streifenalarm
	var zu := _lauf(oeffnen + [{"t": "CLOSE", "on": "eingangstuer"}] + warten, 900.0)
	_check(not _streife_alarm(zu), "geschlossene Tür: die Streife sieht nichts")

	# Abstände: in 900 Sekunden kommen 3 bis 5 Streifen
	_check(zu.patrol_count >= 3 and zu.patrol_count <= 5, "in 15 Minuten kommen 3 bis 5 Streifen (gezählt: %d)" % zu.patrol_count)
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

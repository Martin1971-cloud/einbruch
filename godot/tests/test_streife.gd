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

	# Schonfrist: wer die Tür innerhalb der Schonfrist wieder schließt, bleibt unbemerkt, auch wenn die Streife kommt
	var schnell := _lauf(oeffnen + [{"t": "WAIT", "sec": 10.0}, {"t": "CLOSE", "on": "eingangstuer"}] + warten, 900.0)
	_check(not _streife_alarm(schnell), "Tür innerhalb der Schonfrist geschlossen: die Streife bemerkt nichts")

	# Auch offene Fenster und Stahltüren fallen der Streife auf
	var fenster := Sim.create(GameData.TARGETS["juwelier"], _team(), {"teo": [{"t": "MOVE", "to": "aussen_schaufenster"}, {"t": "TOOL", "tool": "glasschneider", "on": "schaufenster"}, {"t": "OPEN", "on": "schaufenster"}, {"t": "WAIT", "sec": 900.0}]}, GameData.car_now("limo", 85.0))
	var n_f := 0
	while fenster.time < 900.0 and fenster.status == "RUNNING" and n_f < 200000:
		fenster.step(Sim.DT)
		n_f += 1
	_check(fenster.log_lines.any(func(l): return "Streife" in str(l) and "ALARM" in str(l)), "offenes Schaufenster: die Streife schlägt Alarm")

	# Abstände: in 900 Sekunden kommen 3 bis 5 Streifen
	_check(zu.patrol_count >= 4 and zu.patrol_count <= 6, "Kiosk: in 15 Minuten kommen 4 bis 6 Streifen (gezählt: %d)" % zu.patrol_count)

	# Abstand nach Gesamtbeute: Kiosk 3 Minuten, Kurioitätenladen 2 Minuten, Juwelier 1 Minute
	_check(is_equal_approx(GameData.patrol_mittel_s(GameData.TARGETS["kiosk"]), 180.0), "Kiosk: Streife im Mittel alle 3 Minuten")
	_check(is_equal_approx(GameData.patrol_mittel_s(GameData.TARGETS["curiosity"]), 120.0), "Kurioitätenladen: Streife im Mittel alle 2 Minuten")
	_check(is_equal_approx(GameData.patrol_mittel_s(GameData.TARGETS["juwelier"]), 60.0), "Juwelier: Streife im Mittel jede Minute")

	# Hauptweg: 60 Sekunden offen und dann geschlossen ist unbedenklich, auch wenn die Streife länger als 90 Sekunden zurückliegt
	var haupt := _lauf(oeffnen + [{"t": "WAIT", "sec": 60.0}, {"t": "CLOSE", "on": "eingangstuer"}] + warten, 900.0)
	_check(not _streife_alarm(haupt), "Hauptweg 60 Sekunden offen, dann geschlossen: kein Alarm")
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

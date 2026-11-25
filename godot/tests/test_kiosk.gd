extends SceneTree
## Prüft den Einstiegs-Kiosk: keine Wache, kein Alarm, Tür und Kasse mit Dietrich lösbar, Museum bleibt bis zum Erfolg gesperrt.
## Aufruf: godot --headless --path godot --script res://tests/test_kiosk.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func team_of(id: String) -> Array:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			return [d]
	return []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var k: Dictionary = GameData.TARGETS.kiosk
	print("Kiosk-Aufbau:")
	_check(k.guards.is_empty(), "keine Wachen")
	_check(k.sensors.is_empty(), "keine Sensoren")
	_check(not k.has("panel"), "kein Alarmpanel")
	_check(k.loot.size() == 2, "zwei Beutestücke: Kasse und Wertschrank (Original)")

	print("Einbruch mit Dietrich:")
	var plans := {"teo": [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
		{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
		{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"},
		{"t": "OPEN", "on": "Kassenlade"},
		{"t": "TAKE", "loot": "kasse"},
		{"t": "CALL_CAR"},
		{"t": "MOVE", "to": "Fluchtwagen"},
	]}
	var res := Sim.preview(k, team_of("teo"), plans, GameData.CAR)
	_check(str(res.status).begins_with("ENTKOMMEN"), "Kiosk gelingt mit Dietrich (%s)" % res.status)
	_check(int(res.get("payout", 0)) > 0, "Beute wird ausgezahlt")
	_check(float(res.get("alarm_time", -1.0)) < 0.0, "kein Alarm")

	print("Fortschritt:")
	var G = root.get_node("/root/Game")
	G.reset()
	_check(not G.unlocked.museum, "Museum ist zu Beginn gesperrt")
	G.target_id = "kiosk"
	G.apply_result({"status": "ENTKOMMEN", "payout": 0, "heat": 0, "time": 60, "used": {}})
	_check(G.unlocked.get("curiosity", false), "Nach dem Kiosk ist der Kuriositätenladen offen")
	_check(not G.unlocked.museum, "Das Museum bleibt bis nach dem Juwelier gesperrt")
	_check(G.stufe_of("kiosk") == 1, "Sicherungsstufe des Kiosk steigt")

	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

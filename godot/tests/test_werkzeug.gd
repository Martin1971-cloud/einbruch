extends SceneTree
## Prüft die Vorkenntnisse der Werkzeuge (Quelle: tcGetNecessaryAbility) und den Kampf der Wachen.
## Aufruf: godot --headless --path godot --script res://tests/test_werkzeug.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func person(skills: Dictionary) -> Array:
	var d: Dictionary = {}
	for c in GameData.CREW:
		if c.id == "teo":
			d = c.duplicate(true)
	d["skills"] = skills
	d["gear"] = []
	return [d]


func run(team: Array, plan: Array, target: Dictionary = GameData.TARGETS.kiosk) -> Dictionary:
	return Sim.preview(target, team, {"teo": plan}, GameData.car_now("limo", 85.0))


func fail_text(res: Dictionary) -> String:
	for s in res.segments.get("teo", []):
		if str(s.get("fail", "")) != "":
			return s.fail
	return ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var low := {"TECH": 5, "FORCE": 5, "ELECTRONICS": 5, "FAHREN": 5}
	var pre := [{"t": "MOVE", "to": "aussen_eingang"}]
	print("Dietrich braucht Schlösser:")
	var r1 := run(person(low), pre + [{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}])
	_check(fail_text(r1).contains("Vorkenntnisse"), "ohne Schlösser-Wissen: %s" % fail_text(r1))
	print("Brecheisen braucht niemanden:")
	var r2 := run(person(low), pre + [{"t": "TOOL", "tool": "crowbar", "on": "eingangstuer"}])
	_check(fail_text(r2) == "", "Brecheisen ohne Vorkenntnisse möglich")
	print("Elektroset (Bypass) braucht Elektronik:")
	var r3 := run(person(low), [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "bypass", "on": "eingangstuer"}], GameData.TARGETS.museum)
	_check(fail_text(r3).contains("Vorkenntnisse") or fail_text(r3).contains("Alarmpanel") or fail_text(r3) != "", "Bypass ohne Elektronik: %s" % fail_text(r3))
	print("Chloroform und starke Wache:")
	var strong := {"TECH": 5, "FORCE": 30, "ELECTRONICS": 5, "FAHREN": 5}
	var museum: Dictionary = GameData.TARGETS.museum
	var g_gal := {}
	for g in museum.guards:
		if g.id == "g_gal":
			g_gal = g
	_check(int(g_gal.kampf) == 60, "Galerie-Wache hat Kampf 60")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

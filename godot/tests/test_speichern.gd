extends SceneTree
## Prüft Speichern und Laden: Geld, Ermittlung, Werkzeuge, Team und Sicherungsstufe bleiben erhalten.
## Aufruf: godot --headless --path godot --script res://tests/test_speichern.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var G = root.get_node("/root/Game")
	G.reset()
	G.money = 12345
	G.day = 3
	G.hour = 14.5
	G.heat = 27.0
	G.intel["kiosk"] = 2
	G.tools_owned["crowbar"] = true
	G.gear_owned["gloves"] = true
	G.team = [{"id": "teo", "name": "Teodor Vance", "skills": {"TECH": 40}, "gear": ["gloves"]}]
	G.driver = {"id": "greta", "name": "Greta Lind", "skills": {"FAHREN": 80}, "gear": []}
	G.stufe["kiosk"] = 1
	G.save_game()
	_check(G.has_save(), "Spielstand ist geschrieben")
	G.reset()
	_check(G.money != 12345, "Zurücksetzen hat den Stand gelöscht")
	_check(G.load_game(), "Spielstand wird geladen")
	_check(G.money == 12345, "Geld bleibt erhalten")
	_check(G.day == 3 and absf(G.hour - 14.5) < 0.01, "Tag und Uhrzeit bleiben erhalten")
	_check(G.intel["kiosk"] == 2, "Ermittlung bleibt erhalten")
	_check(G.tools_owned.has("crowbar") and G.gear_owned.has("gloves"), "Werkzeug und Kleidung bleiben erhalten")
	_check(G.team.size() == 1 and G.team[0].id == "teo", "Team bleibt erhalten")
	_check(G.driver.get("id", "") == "greta", "Fahrerin bleibt erhalten")
	_check(G.stufe_of("kiosk") == 1, "Sicherungsstufe bleibt erhalten")
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

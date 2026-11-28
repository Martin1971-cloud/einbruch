extends SceneTree
## Schreibtisch ohne Beute im Kurioitätenladen: Hintertür öffnen, Schreibtisch öffnen, durchsuchen, nichts drin.
## Aufruf: godot --headless --path . --script res://tests/test_deko_schreibtisch.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	var t: Dictionary = GameData.TARGETS["curiosity"]
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			team.append(d)
	var plan := [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
		{"t": "MOVE", "cell": [8, 6]},
		{"t": "TOOL", "tool": "lockpick", "on": "hintertuer"},
		{"t": "OPEN", "on": "hintertuer"},
		{"t": "MOVE", "cell": [13, 5]},
		{"t": "TOOL", "tool": "lockpick", "on": "deko_schreibtisch"},
		{"t": "OPEN", "on": "deko_schreibtisch"},
		{"t": "TAKE", "loot": "deko_schreibtisch"},
		{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
	]
	var s := Sim.create(t, team, {"teo": plan}, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 8000:
		s.step(Sim.DT)
		n += 1
	var log_text := "\n".join(s.log_lines)
	_check(log_text.find("Hintertür ist entriegelt") >= 0, "Hintertür lässt sich mit Dietrich öffnen")
	_check(log_text.find("öffnet Schreibtisch") >= 0, "Schreibtisch ohne Beute lässt sich öffnen")
	_check(log_text.find("nichts drin") >= 0, "Durchsuchen meldet: nichts drin")
	_check(s.loot["deko_schreibtisch"].opened, "Schreibtisch steht im Zustand offen (Animation folgt dem Zustand)")
	_check(s.loot["deko_schreibtisch"].state == "ROOM", "nichts wird getragen")
	_check(s.crew[0].carried.is_empty(), "Tragegepäck bleibt leer")
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

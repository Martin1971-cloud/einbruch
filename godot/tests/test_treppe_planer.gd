extends SceneTree
## Treppe steigen: die Person startet am Treppenende ihrer Etage und kommt im anderen Geschoss an.
## Aufruf: godot --headless --path . --script res://tests/test_treppe_planer.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	var team := []
	for c in GameData.CREW:
		if c.id == "otto":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			team.append(d)
	var t: Dictionary = GameData.TARGETS["curiosity"]
	# Vom Eingang zum EG-Ende der Treppe, dann steigen: die Person muss im OG ankommen
	var plan := [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
		{"t": "MOVE", "cell": [4, 8]},
		{"t": "TREPPE", "approach": [4, 8]},
	]
	var sim := Sim.create(t, team, {"otto": plan}, GameData.car_now("limo", 85.0))
	var n := 0
	while sim.status == "RUNNING" and n < 8000:
		sim.step(Sim.DT)
		n += 1
	var log_text := "\n".join(sim.log_lines)
	_check(log_text.find("auf der anderen Etage") >= 0, "Treppe steigen: die Person ist auf der anderen Etage")
	_check(log_text.find("fail") < 0 and not sim.log_lines.any(func(l): return "keine Treppe" in str(l)), "kein Fehlschlag beim Treppensteigen")
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

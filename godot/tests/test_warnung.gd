extends SceneTree
## Vorschau-Warnung: zwei Personen am selben Schloss -> die Simulation meldet das Warten.
## Aufruf: godot --headless --path godot --script res://tests/test_warnung.gd
func _init() -> void:
	var k: Dictionary = GameData.TARGETS.kiosk
	var team := []
	for c in GameData.CREW:
		if c.id in ["teo", "ilja"]:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	var seq := [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
		{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
		{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"},
		{"t": "OPEN", "on": "Kassenlade"},
		{"t": "TAKE", "loot": "kasse"},
	]
	var res := Sim.preview(k, team, {"teo": seq.duplicate(true), "ilja": seq.duplicate(true)}, GameData.CAR)
	var found := false
	for line in res.log:
		if str(line).contains("wartet, bis"):
			found = true
	print("  %s  Warnung bei gleichzeitiger Arbeit" % ("ok  " if found else "FAIL"))
	quit(0 if found else 1)

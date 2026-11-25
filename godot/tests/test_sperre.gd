extends SceneTree
## Objektsperre: zwei Personen am selben Schloss, die zweite wartet. Beute, die schon weg ist, bleibt weg.
## Aufruf: godot --headless --path godot --script res://tests/test_sperre.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func team_of(ids: Array) -> Array:
	var out := []
	for c in GameData.CREW:
		if c.id in ids:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			out.append(d)
	return out


func _init() -> void:
	var k: Dictionary = GameData.TARGETS.kiosk
	var plan := {
		"teo": [
			{"t": "MOVE", "to": "Außen vor dem Eingang"},
			{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "OPEN", "on": "Eingangstür"},
			{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
			{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"},
			{"t": "OPEN", "on": "Kassenlade"},
			{"t": "TAKE", "loot": "kasse"},
		],
		"ilja": [
			{"t": "MOVE", "to": "Außen vor dem Eingang"},
			{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "OPEN", "on": "Eingangstür"},
			{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
			{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"},
			{"t": "OPEN", "on": "Kassenlade"},
			{"t": "TAKE", "loot": "kasse"},
		],
	}
	var s := Sim.create(k, team_of(["teo", "ilja"]), plan, GameData.CAR)
	var n := 0
	var waited := false
	var both_work := false
	while s.status == "RUNNING" and n < 6000:
		s.step(Sim.DT)
		n += 1
		var busy_teo := false
		var busy_ilja := false
		for c in s.crew:
			if c.id == "teo" and c.started and c.idx == 1:
				busy_teo = true
			if c.id == "ilja" and c.started and c.idx == 1:
				busy_ilja = true
		if busy_teo and busy_ilja:
			both_work = true
		for c in s.crew:
			if c.get("waiting", false):
				waited = true
	_check(not both_work, "nicht zwei Personen gleichzeitig am selben Schloss")
	_check(waited, "die zweite Person wartet")
	var takes := 0
	for line in s.log_lines:
		if str(line).contains("nimmt Kassenlade"):
			takes += 1
	_check(takes == 1, "Kassenlade wird nur einmal genommen (%d)" % takes)
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

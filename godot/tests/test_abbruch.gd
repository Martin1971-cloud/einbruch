extends SceneTree
## Prüft: Start am Wagen, Abbruch per Funk bringt alle zurück zum Wagen, Wagen fährt erst bei allen an Bord los.
## Aufruf: godot --headless --path godot --script res://tests/test_abbruch.gd
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
	var plans := {"teo": [
		{"t": "MOVE", "cell": [0, 5]}, {"t": "MOVE", "cell": [1, 5]},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
		{"t": "MOVE", "cell": [5, 5]}, {"t": "MOVE", "cell": [5, 4]},
		{"t": "TOOL", "tool": "lockpick", "on": "Gemälde „Hafen bei Nacht“"},
		{"t": "OPEN", "on": "Gemälde „Hafen bei Nacht“"},
		{"t": "TAKE", "loot": "gemaelde"},
		{"t": "MOVE", "to": "Fluchtwagen"},
	]}
	var s := Sim.create(GameData.TARGETS.museum, team_of("teo"), plans, GameData.CAR)
	print("Start:")
	_check(Vector2(s.crew[0].pos) == Sim.center(s.escape_cell), "Teodor startet am Fluchtwagen")
	for i in range(100):
		s.step(Sim.DT)
	print("Abbruch nach 10 s:")
	s.abort()
	var n := 0
	while s.status == "RUNNING" and n < 20000:
		s.step(Sim.DT)
		n += 1
	_check(s.departed, "Wagen fährt los, nachdem alle am Wagen sind")
	_check(s.status != "RUNNING", "Coup endet (Status: %s)" % s.status)
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

extends SceneTree
## Prüft: Wache ausschalten (neben der Wache), danach ist sie aus dem Spiel.
## Aufruf: godot --headless --path godot --script res://tests/test_wache.gd
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
	print("Ausschalten neben der Wache:")
	var plans := {"teo": [{"t": "NEUTRALIZE", "guard": "g_gal"}]}
	var s := Sim.create(GameData.TARGETS.museum, team_of("teo"), plans, GameData.car_now("limo", 85.0))
	s.guards[1].state = "PATROL"
	s.guards[1].dwell = 999.0
	s.crew[0].pos = Vector2(s.guards[1].pos) + Vector2(Sim.SUB, 0)
	s.crew[0]["facing"] = Vector2(-1, 0)  # blickt auf die Wache (Original: Blickrichtung)
	for i in range(200):
		s.step(Sim.DT)
	_check(s.guards[1].state == "OUT", "Galerie-Wache ist ausgeschaltet")
	print("Zu weit weg:")
	var s2 := Sim.create(GameData.TARGETS.museum, team_of("teo"), plans, GameData.car_now("limo", 85.0))
	s2.guards[1].state = "PATROL"
	s2.guards[1].dwell = 999.0
	for i in range(20):
		s2.step(Sim.DT)
	_check(s2.guards[1].state != "OUT", "Aus der Ferne geht es nicht")
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

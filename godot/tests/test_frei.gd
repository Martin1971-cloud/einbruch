extends SceneTree
## Freie Bewegung in der Planung: Ziel ist ein Punkt in Unterfeldern. Wände und geschlossene Türen sind kein Ziel.
## Aufruf: godot --headless --path godot --script res://tests/test_frei.gd
var _fails := 0
var U := Sim.SUB / 8  # Koordinaten sind in Einheiten von 8 Unterfeldern geschrieben


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
	var k: Dictionary = GameData.TARGETS.kiosk
	print("Planung: freier Punkt im Raum (Tür erst öffnen):")
	var plan := {"teo": [
		{"t": "MOVE", "to": "aussen_eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
		{"t": "OPEN", "on": "eingangstuer"},
		{"t": "MOVE", "fine": [71 * U, 35 * U]},
	]}
	var s := Sim.create(k, team_of("teo"), plan, GameData.car_now("limo", 85.0))
	var n := 0
	while s.status == "RUNNING" and n < 4000 and not s.crew[0].done:
		s.step(Sim.DT)
		n += 1
	var fails := ""
	for seg in s.crew[0].segments:
		if str(seg.get("fail", "")) != "":
			fails = seg.fail
	_check(fails == "", "freier Punkt im Raum wird angefahren (%s)" % fails)
	var p: Vector2 = s.crew[0].pos
	_check(p.distance_to(Vector2(71 * U, 35 * U)) < 0.6, "Teodor steht am Punkt (%.1f, %.1f)" % [p.x, p.y])

	print("Planung: Wand als Ziel:")
	var s2 := Sim.create(k, team_of("teo"), {"teo": [{"t": "MOVE", "fine": [52 * U, 35 * U]}]}, GameData.car_now("limo", 85.0))
	n = 0
	while s2.status == "RUNNING" and n < 4000 and not s2.crew[0].done:
		s2.step(Sim.DT)
		n += 1
	var f2 := ""
	for seg in s2.crew[0].segments:
		if str(seg.get("fail", "")) != "":
			f2 = seg.fail
	_check(f2 != "", "Wand/Fenster als Ziel wird abgelehnt (%s)" % f2)

	print("Planungsgrundriss:")
	_check(Sim.plan_tile(k, Vector2i(71 * U, 35 * U)) == ".", "Innenraum ist begehbar")
	_check(Sim.plan_tile(k, Vector2i(50 * U, 20 * U)) == "W", "Wand erkannt")
	_check(Sim.plan_tile(k, Vector2i(50 * U, 35 * U)) == "F", "Schaufenster in der Wand ist Glas (F)")
	_check(Sim.plan_tile(k, Vector2i(-5, 0)) == "W", "außerhalb ist Wand")
	print("Ergebnis: %d Fehler" % _fails)
	quit(_fails)

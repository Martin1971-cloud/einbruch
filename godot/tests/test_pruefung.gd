extends SceneTree
## Prüft die Planungs-Gegenprobe: Beute ohne offene Vitrine und Wege durch verschlossene Türen werden als Fehler gemeldet.
## Aufruf: godot --headless --path godot --script res://tests/test_pruefung.gd
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
	print("Beute ohne Vitrine:")
	var p1 := {"teo": [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
		{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
		{"t": "TAKE", "loot": "kasse"},
	]}
	var r1 := Sim.preview(k, team_of("teo"), p1, GameData.car_now("limo", 85.0))
	var segs1: Array = r1.segments.teo
	var f1 := ""
	for s in segs1:
		if str(s.get("fail", "")) != "":
			f1 = s.fail
	_check(f1.contains("noch zu"), "Vitrine zu: Beute nehmen wird gemeldet (%s)" % f1)

	print("Tür im Weg:")
	var p2 := {"teo": [{"t": "MOVE", "cell": [8, 4]}]}
	var r2 := Sim.preview(k, team_of("teo"), p2, GameData.car_now("limo", 85.0))
	var f2 := ""
	for s in r2.segments.teo:
		if str(s.get("fail", "")) != "":
			f2 = s.fail
	_check(f2.contains("Tür"), "Weg durch zu Tür wird gemeldet (%s)" % f2)

	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

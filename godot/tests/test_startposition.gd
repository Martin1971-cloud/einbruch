extends SceneTree
## Prüft die Startposition bei Objektaktionen: Eine Person darf nur an einem Objekt handeln,
## wenn sie in Reichweite steht und die Sichtlinie frei ist (keine Wand, kein Tresen dazwischen).
## Aufruf: godot --headless --path godot --script res://tests/test_startposition.gd

var _fehler := 0


func _init() -> void:
	var k: Dictionary = GameData.TARGETS.kiosk
	# Fall 1: Aufbrechen, ohne vorher hinzugehen -> muss am Start scheitern
	var log1 := _lauf(k, [{"t": "TOOL", "tool": "lockpick", "on": "Wertschrank"}])
	_pruefe("ohne Weg wird nicht gehandelt", _hat(log1, "steht nicht vor"), true)
	_pruefe("ohne Weg wird keine Tür aufgebrochen", _hat(log1, "Wertschrank aufbrechen"), false)

	# Fall 2: Erst zur Eingangstür, dann aufbrechen -> muss gelingen
	var log2 := _lauf(k, [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
	])
	_pruefe("mit Weg kein Abbruch am Start", _hat(log2, "steht nicht vor"), false)

	# Fall 3: Durch die geschlossene Tür hindurch auf den Wertschrank zugreifen -> Sichtlinie blockiert
	var log3 := _lauf(k, [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Wertschrank"},
	])
	_pruefe("Wand/Tür blockiert Sichtlinie", _hat(log3, "steht nicht vor"), true)

	# Fall 4: Beim Öffnen schaut die Person zum Objekt (Tür liegt nördlich von "Außen", also y < 0)
	var blick := _blick(k, [
		{"t": "MOVE", "to": "Außen vor dem Eingang"},
		{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
		{"t": "OPEN", "on": "Eingangstür"},
	])
	_pruefe("beim Öffnen schaut die Person zur Tür (Blick nach Norden)", blick.y < -0.5, true)

	print("Ergebnis: %d Fehler" % _fehler)
	quit(1 if _fehler > 0 else 0)


func _lauf(k: Dictionary, plan: Array) -> Array:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	var s := Sim.create(k, team, {"teo": plan.duplicate(true)}, GameData.CAR)
	var n := 0
	while s.status == "RUNNING" and n < 4000:
		s.step(Sim.DT)
		n += 1
	return s.log_lines


func _blick(k: Dictionary, plan: Array) -> Vector2:
	var team := []
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			team.append(d)
	var s := Sim.create(k, team, {"teo": plan.duplicate(true)}, GameData.CAR)
	var n := 0
	while s.status == "RUNNING" and n < 4000:
		s.step(Sim.DT)
		n += 1
	return s.crew[0].get("facing", Vector2.ZERO)


func _hat(log: Array, text: String) -> bool:
	for l in log:
		if String(l).contains(text):
			return true
	return false


func _pruefe(name: String, ist: bool, soll: bool) -> void:
	if ist == soll:
		print("  ok    ", name)
	else:
		print("  FEHLER ", name, " (erwartet %s)" % str(soll))
		_fehler += 1

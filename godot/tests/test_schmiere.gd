extends SceneTree
## Prüft die Schmiere: Ohne Posten meldet die Streife eine offene Tür sofort. Mit Posten gibt es eine Vorwarnzeit.
## Außerdem: Die Aktion „Posten“ läuft durch die Simulation.
var _fails := 0
var _frames := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _offene_tuer(s: Sim) -> Vector2i:
	for p in s.doors:
		s.open_cells[p] = true
		s.open_since[p] = 0.0
		return p
	return Vector2i(-1, -1)

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var ohne := Sim.create(GameData.TARGETS.museum, [], {}, GameData.car_now("limo", 85.0))
	ohne.guards.clear()
	ohne.time = 100.0
	_offene_tuer(ohne)
	ohne._next_patrol = 0.0
	ohne._check_patrols(0.0)
	_check(ohne.alarm_active, "Ohne Schmiere: offene Tür löst die Streife sofort aus")

	var mit := Sim.create(GameData.TARGETS.museum, [], {}, GameData.car_now("limo", 85.0))
	mit.guards.clear()
	mit.time = 100.0
	_offene_tuer(mit)
	mit.posten_zeiten = [[95.0, 130.0]]
	mit._next_patrol = 0.0
	mit._check_patrols(0.0)
	_check(not mit.alarm_active and mit.vorwarnung_bis > 0.0, "Mit Schmiere auf Posten: Vorwarnung statt Alarm")
	mit.time = mit.vorwarnung_bis - 0.1
	mit._pruefe_vorwarnung()
	_check(not mit.alarm_active, "Während der Vorwarnzeit: noch kein Alarm")
	mit.time = mit.vorwarnung_bis
	mit._pruefe_vorwarnung()
	_check(mit.alarm_active, "Nach der Vorwarnzeit bei offener Tür: Alarm")

	var geschlossen := Sim.create(GameData.TARGETS.museum, [], {}, GameData.car_now("limo", 85.0))
	geschlossen.guards.clear()
	geschlossen.time = 100.0
	_offene_tuer(geschlossen)
	geschlossen.posten_zeiten = [[95.0, 130.0]]
	geschlossen._next_patrol = 0.0
	geschlossen._check_patrols(0.0)
	geschlossen.open_cells.clear()
	geschlossen.time = geschlossen.vorwarnung_bis
	geschlossen._pruefe_vorwarnung()
	_check(not geschlossen.alarm_active, "Tür in der Vorwarnzeit geschlossen: kein Alarm")

	var team := [GameData.CREW[0].duplicate(true)]
	team[0]["gear"] = "none"
	var plans := {team[0].id: [{"t": "POSTEN", "sec": 5.0}]}
	var res := Sim.preview(GameData.TARGETS.museum, team, plans, GameData.car_now("limo", 85.0))
	_check(res.has("status"), "Aktion Posten läuft durch die Simulation")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
	return true

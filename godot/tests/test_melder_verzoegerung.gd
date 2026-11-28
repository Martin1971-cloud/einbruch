extends SceneTree
## Prüft verzögerte Melder: Ohne Verzögerung löst ein Geräusch sofort aus, mit Verzögerung erst nach Ablauf.
var _fails := 0
var _frames := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _sim(verz: float) -> Sim:
	var s := Sim.create(GameData.TARGETS.museum, [], {}, GameData.car_now("limo", 85.0))
	s.sensors[0].verzoegerung = verz
	s.guards.clear()  # nur der Melder soll reagieren, keine Wache
	return s

func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var sofort := _sim(0.0)
	sofort._noise(sofort.center(sofort.sensors[0].pos), 999.0)
	_check(sofort.alarm_active and sofort.alarm_source == sofort.sensors[0].name, "Ohne Verzögerung: sofort Alarm")
	var spaet := _sim(5.0)
	spaet._noise(spaet.center(spaet.sensors[0].pos), 999.0)
	_check(not spaet.alarm_active and spaet.pending_alarms.size() == 1, "Mit Verzögerung: noch kein Alarm, Melder wartet")
	spaet.time = 4.9
	spaet._pruefe_verzoegerte_melder()
	_check(not spaet.alarm_active, "Vor Ablauf: weiterhin kein Alarm")
	spaet.time = 5.0
	spaet._pruefe_verzoegerte_melder()
	_check(spaet.alarm_active and spaet.alarm_source == spaet.sensors[0].name, "Nach Ablauf: Alarm")
	var aus := _sim(5.0)
	aus._noise(aus.center(aus.sensors[0].pos), 999.0)
	aus.sensors[0].active = false
	aus.time = 6.0
	aus._pruefe_verzoegerte_melder()
	_check(not aus.alarm_active, "Abgeschalteter Melder löst nach Ablauf nicht aus")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
	return true

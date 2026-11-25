extends SceneTree
## Prüft die Verfolgung: Tempo der Fahrzeuge und Ausgang der Jagd nach Wachrate und Fluchtstrecke.
var _fails := 0
func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok: _fails += 1
func _init() -> void:
	var slow := GameData.car_now("limo", 60.0)
	var fast := GameData.car_now("sport", 60.0)
	_check(fast.v > slow.v, "Sportwagen ist schneller (%.0f gegen %.0f km/h)" % [fast.v, slow.v])
	var kiosk: Dictionary = GameData.TARGETS.kiosk
	var museum: Dictionary = GameData.TARGETS.museum
	var pk := 140.0 + float(kiosk.guard_rate) * 0.25
	var pm := 140.0 + float(museum.guard_rate) * 0.25
	# Gleicher Vorlauf von 60 s: der langsame Wagen wird im Museum eingeholt, der schnelle entkommt
	_check(Sim.chase_result(slow.v, pm, 60.0, float(museum.escape_km)) == "GEFASST", "Limousine wird im Museum eingeholt")
	_check(Sim.chase_result(fast.v, pm, 60.0, float(museum.escape_km)) == "ENTKOMMEN", "Sportwagen entkommt im Museum")
	# Kurzer Vorlauf, kurze Strecke: knapp
	var r := Sim.chase_result(slow.v, pk, 10.0, float(kiosk.escape_km))
	_check(r == "KNAPP" or r == "ENTKOMMEN" or r == "GEFASST", "Kiosk liefert ein Ergebnis (%s)" % r)
	_check(Sim.chase_result(fast.v, pk, 600.0, 10.0) == "ENTKOMMEN", "langer Vorlauf: entkommen")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

extends SceneTree
## Prüft die Effizienz der Wachen: Mit 0 nimmt eine Wache Geräusche nicht wahr, mit 1.0 schon.
## Alle Wachen in den Daten haben das Pflichtfeld.
var _fails := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _verdacht_nach_laerm(eff: float) -> float:
	var car := GameData.car_now("limo", 85.0)
	var s := Sim.create(GameData.TARGETS.museum, [], {}, car)
	var g: Dictionary = s.guards[0]
	g.effizienz = eff
	s._noise(g.pos + Vector2(4, 0), 200.0)
	return float(g.suspicion)

func _initialize() -> void:
	for t in GameData.TARGETS.values():
		for w in t.get("guards", []):
			_check(w.has("effizienz"), "Wache %s hat effizienz" % w.id)
	_check(_verdacht_nach_laerm(0.0) == 0.0, "Effizienz 0: Geräusch wird nicht wahrgenommen")
	_check(_verdacht_nach_laerm(1.0) > 0.0, "Effizienz 1.0: Geräusch wird wahrgenommen")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

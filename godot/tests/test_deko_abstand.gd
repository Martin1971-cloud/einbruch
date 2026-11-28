extends SceneTree
## Abstand der Dekoobjekte: Anlaufseite frei, nicht eingeschlossen, kein anderes Objekt direkt daneben.
## Aufruf: godot --headless --path . --script res://tests/test_deko_abstand.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _init() -> void:
	for tid in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[tid]
		var hat_deko := false
		for l in t.loot:
			if l.get("leer", false):
				hat_deko = true
		if not hat_deko:
			continue
		print("== %s ==" % tid)
		var sim := Sim.create(t, [], {}, GameData.car_now("limo", 85.0))
		for k in sim.doors.keys():
			sim.open_cells[k] = true
		# Felder mit anderen Objekten (Beute, Türen) und mit Wand/Tresen/Tresor (nicht begehbar)
		var objekt_felder := {}
		for l in t.loot:
			objekt_felder[Sim._v2i(l.pos)] = true
		for k in sim.doors.keys():
			objekt_felder[k] = true
		if sim.panel.has("pos"):
			objekt_felder[sim.panel.pos] = true
		for l in t.loot:
			if not l.get("leer", false):
				continue
			var cell := Sim._v2i(l.pos)
			var nachbarn: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var frei := 0
			var anlauf := false
			for d in nachbarn:
				var n: Vector2i = cell + d
				var ok := sim.body_clear(Sim.center(n))
				if ok:
					frei += 1
					if not sim.path_to(Sim.center(Sim._v2i(t.points.aussen_eingang)), n).is_empty() or n == Sim._v2i(t.points.aussen_eingang):
						anlauf = true
			_check(anlauf, "%s %s: Anlaufseite frei und erreichbar" % [tid, l.id])
			_check(frei >= 2, "%s %s: nicht eingeschlossen (mind. 2 freie Nachbarfelder, hat %d)" % [tid, l.id, frei])
			# Abstand: kein anderes Objekt (Beute, Tür, Alarmpanel) auf einem der vier Nachbarfelder; diagonal ist erlaubt
			var nah := ""
			for d in nachbarn:
				var n: Vector2i = cell + d
				if objekt_felder.has(n):
					nah += " %s" % str(n)
			_check(nah == "", "%s %s: kein anderes Objekt direkt daneben%s" % [tid, l.id, nah])
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

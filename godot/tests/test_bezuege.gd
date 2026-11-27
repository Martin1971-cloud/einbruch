extends SceneTree
## Bezüge und Tabellen: IDs sauber benannt und eindeutig, alle Verweise zeigen auf Vorhandenes,
## Koordinaten liegen im Grundriss, Textschlüssel existieren, Grundrisscodes sind bekannt.
## Aufruf: godot --headless --path . --script res://tests/test_bezuege.gd
var _fails := 0
const ID_MUSTER := "^[a-z][a-z0-9_]*$"
const KACHELN := [".", "o", "W", "D", "F", "T", "C", "H", "S", "K", "R", "Z", "P"]
const DEKO_KACHELN := ["C", "S", "R", "Z", "P"]
## Geplante Gebäude: noch nicht gebaut, der Grundriss ist ein Platzhalter. Kennungen und Verweise werden trotzdem geprüft.
## Wenn ein Gebäude fertig ist, aus dieser Liste nehmen; dann gelten alle Regeln voll.
const PLANUNG := ["museum"]


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("  FAIL " + label)
		_fails += 1


func _id_ok(id: String) -> bool:
	var rx := RegEx.new()
	rx.compile(ID_MUSTER)
	return rx.search(id) != null


func _init() -> void:
	print("== Ziele ==")
	for tid in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[tid]
		_check(_id_ok(tid), "%s: Ziel-ID im Format snake_case" % tid)
		_check(str(t.get("sprecher", "")) != "" and GameData.SPRECHER.any(func(e): return str(e.id) == str(t.sprecher)), "%s: Ansprechperson existiert" % tid)
		if not PLANUNG.has(tid):
			_check(t.get("fine", {}).has("paint"), "%s: Feingrundriss vorhanden" % tid)
		var sim := Sim.create(t, [], {}, GameData.car_now("limo", 85.0))
		var w := sim.fine_w
		var h := sim.fine_h
		var cell_w := ceili(float(w) / Sim.SUB)
		var cell_h := ceili(float(h) / Sim.SUB)

		# Codes im Grundriss sind bekannt
		for y in range(h):
			for x in range(w):
				var c := sim.ftile(Vector2i(x, y))
				if not KACHELN.has(c):
					_check(false, "%s: unbekannter Grundrisscode '%s' bei %d,%d" % [tid, c, x, y])
					break

		# Beute: IDs, eindeutig, Format, Position, Name, Dekoobjekte mit passender Kachel
		var ids := {}
		for l in t.loot:
			var lid := str(l.id)
			_check(_id_ok(lid), "%s: Beute-ID '%s' im Format snake_case" % [tid, lid])
			_check(not ids.has(lid), "%s: Beute-ID '%s' doppelt" % [tid, lid])
			ids[lid] = true
			var p := Sim._v2i(l.pos)
			_check(p.x >= 0 and p.y >= 0 and p.x < cell_w and p.y < cell_h, "%s %s: Position %s liegt im Grundriss" % [tid, lid, str(p)])
			var nm := GameData.name_von(lid)
			_check(nm != lid, "%s %s: hat einen Anzeigenamen in den Daten" % [tid, lid])
			_check(Texte.t(nm) != nm, "%s %s: Anzeigename '%s' hat einen Text" % [tid, lid, nm])
			if l.get("leer", false):
				var kachel := sim.ftile(p * Sim.SUB + Vector2i(8, 8))
				_check(DEKO_KACHELN.has(kachel), "%s %s: Dekoobjekt steht auf Kachel %s (erwartet C, S, R, Z oder P)" % [tid, lid, kachel])
				_check(float(l.get("value", 0)) == 0.0, "%s %s: Dekoobjekt hat keinen Wert" % [tid, lid])
				_check(float(l.get("weight", 0.0)) == 0.0, "%s %s: Dekoobjekt hat kein Gewicht" % [tid, lid])
			else:
				_check(int(l.get("value", 0)) > 0, "%s %s: Beute hat einen Wert" % [tid, lid])

		# Türen: IDs eindeutig und im Format, Position im Grundriss
		var dids := {}
		for d in t.get("doors", []):
			var did := str(d.id)
			_check(_id_ok(did), "%s: Tür-ID '%s' im Format snake_case" % [tid, did])
			_check(not dids.has(did), "%s: Tür-ID '%s' doppelt" % [tid, did])
			dids[did] = true
			var dp := Sim._v2i(d.pos)
			_check(dp.x >= 0 and dp.y >= 0 and dp.x < cell_w and dp.y < cell_h, "%s %s: Türposition liegt im Grundriss" % [tid, did])

		# Punkte: alle Positionen im Grundriss
		for pid in t.get("points", {}):
			var pp := Sim._v2i(t.points[pid])
			_check(_id_ok(str(pid)), "%s: Punkt-ID '%s' im Format snake_case" % [tid, pid])
			_check(pp.x >= 0 and pp.y >= 0 and pp.x < cell_w and pp.y < cell_h, "%s: Punkt '%s' liegt im Grundriss" % [tid, pid])

		# Gesichert: Türen oder Beuteobjekte (Vitrinen, Tresore), die es im Ziel gibt
		for g in t.get("gesichert", []):
			_check(dids.has(str(g)) or ids.has(str(g)), "%s: gesichertes Objekt '%s' gibt es nicht" % [tid, g])

	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

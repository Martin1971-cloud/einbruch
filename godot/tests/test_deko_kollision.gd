extends SceneTree
## Dekoobjekte ohne Beute: gleiche Kollision wie Vitrinen, keine Überlappung mit Beute, Laufwege bleiben frei.
## Aufruf: godot --headless --path . --script res://tests/test_deko_kollision.gd
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _teo() -> Array:
	for c in GameData.CREW:
		if c.id == "teo":
			var d: Dictionary = c.duplicate(true)
			d["gear"] = []
			return [d]
	return []


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
		var sim := Sim.create(t, _teo(), {"teo": []}, GameData.car_now("limo", 85.0))
		# Vergleich: eine echte Vitrine desselben Ziels (Kachel "C")
		var vitrine_ok := false
		for y in range(sim.fine_h):
			for x in range(sim.fine_w):
				if sim.ftile(Vector2i(x, y)) == "C":
					vitrine_ok = true
		_check(vitrine_ok, "%s: Vitrinen-Kachel C kommt im Grundriss vor (Referenz)" % tid)
		for l in t.loot:
			if not l.get("leer", false):
				continue
			var cell := Sim._v2i(l.pos)
			var erwartet: String = {"deko_vitrine": "C", "deko_regal": "R", "deko_zeitung": "Z", "deko_schreibtisch": "P", "deko_tisch": "P", "deko_glasschrank": "C"}.get(l.id, "?")
			var nur_kachel := true
			var sub_anders := ""
			for y in range(Sim.SUB):
				for x in range(Sim.SUB):
					var f := Vector2i(cell.x * Sim.SUB + x, cell.y * Sim.SUB + y)
					if sim.ftile(f) != erwartet:
						nur_kachel = false
						sub_anders = sim.ftile(f)
			_check(nur_kachel, "%s %s: ganze Zelle ist Kachel %s (sonst %s)" % [tid, l.id, erwartet, sub_anders])
			_check(not sim.passable_f(cell * Sim.SUB + Vector2i(8, 8)), "%s %s: blockiert wie eine Vitrine" % [tid, l.id])
			var andere := 0
			for m in t.loot:
				if m != l and Sim._v2i(m.pos) == cell:
					andere += 1
			_check(andere == 0, "%s %s: keine andere Beute auf demselben Feld" % [tid, l.id])
		# Laufwege: alle Türen offen, dann muss jede Beute von außen über ein Nachbarfeld erreichbar sein
		for k in sim.doors.keys():
			sim.open_cells[k] = true
		# Startpunkte: Eingang und die Treppen (für Beute im Obergeschoss)
		var starts := [Sim._v2i(t.points.aussen_eingang)]
		for k in ["treppe_eg", "treppe_og"]:
			if t.points.has(k):
				starts.append(Sim._v2i(t.points[k]))
		for l in t.loot:
			var cell := Sim._v2i(l.pos)
			var erreichbar := false
			for start in starts:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = cell + d
					if n == start or not sim.path_to(Sim.center(start), n).is_empty():
						erreichbar = true
			_check(erreichbar, "%s %s: von außen über ein Nachbarfeld erreichbar" % [tid, l.id])
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

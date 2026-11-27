extends SceneTree
## Jede Tür muss denselben Schlüssel für Simulation und Anzeige haben, sonst dreht sich ihr Blatt nie.
## Aufruf: godot --headless --path . --script res://tests/test_tuer_scharnier.gd
var _fails := 0


func _init() -> void:
	for tid in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[tid]
		if not t.get("fine", {}).has("paint"):
			continue
		var sim := Sim.create(t, [], {}, GameData.car_now("limo", 85.0))
		var summen := {}
		var anzahl := {}
		for y in range(sim.fine_h):
			for x in range(sim.fine_w):
				var f := Vector2i(x, y)
				if sim.ftile(f) != "D":
					continue
				var k: Vector2i = sim.door_key(f)
				summen[k] = summen.get(k, Vector2(0, 0)) + Vector2(f)
				anzahl[k] = anzahl.get(k, 0) + 1
		for k in summen:
			var mitte: Vector2 = summen[k] / float(anzahl[k])
			var zelle: Vector2i = Vector2i(floori(mitte.x / Sim.SUB), floori(mitte.y / Sim.SUB))
			var anzeige: Vector2i = sim.door_key(Vector2i(floori(mitte.x), floori(mitte.y)))
			if anzeige != k:
				print("  FAIL %s: Tür %s, Anzeige-Schlüssel %s" % [tid, str(k), str(anzeige)])
				_fails += 1
			if not sim.doors.has(k):
				print("  FAIL %s: Schlüssel %s gehört zu keiner Tür" % [tid, str(k)])
				_fails += 1
	print("Fehler: %d" % _fails)
	quit(1 if _fails > 0 else 0)

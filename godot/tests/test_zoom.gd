extends SceneTree
## Prüft Zoom und Verschieben der Grundrissansicht: der Punkt unter dem Mauszeiger bleibt fest,
## und Klicks treffen nach dem Zoomen das richtige Feld.
var _fails := 0
var _clicked: Array = []


func _init() -> void:
	var g := GridView.new()
	g.size = Vector2(800, 600)
	g.target = GameData.TARGETS.kiosk
	g.intel = 2
	g.cell_clicked.connect(func(c: Vector2i) -> void: _clicked.append(c))
	root.add_child(g)
	g._layout()
	var p := Vector2(400, 300)
	var w_before := (p - g._origin) / g._cw
	g._zoom_at(p, 1.25)
	g._zoom_at(p, 1.25)
	var w_after := (p - g._origin) / g._cw
	_check(w_before.distance_to(w_after) < 0.001, "Zoom lässt den Punkt unter dem Zeiger stehen")
	_check(g._zoom > 1.5, "Zoom wirkt (%.2f)" % g._zoom)
	# Klick auf die Mitte des Feldes (9,3) nach dem Zoomen
	var center := g._origin + Vector2(9.5 * g._cw, 3.5 * g._ch)
	g._click(center)
	_check(_clicked.size() == 1 and _clicked[0] == Vector2i(9, 3), "Klick nach Zoom trifft Feld (9,3): %s" % str(_clicked))
	# Verschieben
	var before := g._origin
	g._pan += Vector2(30, 0)
	g._layout()
	_check(absf((g._origin - before).x - 30.0) < 0.001, "Verschieben um 30 Pixel")
	# Zurücksetzen
	g._reset_view()
	_check(g._zoom == 1.0 and g._pan == Vector2.ZERO, "Doppelklick setzt Ansicht zurück")
	# Zoomknöpfe: "+" vergrößert, "−" verkleinert
	var z0: float = g._zoom
	g.zoom_box.get_child(0).pressed.emit()
	_check(g._zoom > z0, "Knopf + vergrößert")
	var z1: float = g._zoom
	g.zoom_box.get_child(1).pressed.emit()
	_check(g._zoom < z1, "Knopf − verkleinert")
	g._zoom_at(p, 1.5)
	g.zoom_box.get_child(2).pressed.emit()
	_check(g._zoom == 1.0 and g._pan == Vector2.ZERO, "Knopf Alles zeigt die ganze Karte")
	# Grenzen: auch bei extremem Verschieben und Zoom bleibt das Gebäude sichtbar
	for z in [1.0, 2.5, 8.0]:
		g._zoom = z
		for d in [Vector2(5000, 0), Vector2(-5000, 0), Vector2(0, 5000), Vector2(0, -5000)]:
			g._pan = Vector2.ZERO
			g._pan += d
			g._clamp_pan()
			g._layout()
			var sc: float = g._cw
			var b := g._bounds()
			var left: float = g._origin.x + b.position.x * sc
			var top: float = g._origin.y + b.position.y * sc
			var vis_w: float = minf(left + b.size.x * sc, g.size.x) - maxf(left, 0.0)
			var vis_h: float = minf(top + b.size.y * sc, g.size.y) - maxf(top, 0.0)
			_check(vis_w >= 159.0 and vis_h >= 159.0, "Zoom %.1f, Verschieben %s: Gebäude sichtbar (%.0f x %.0f px)" % [z, str(d), vis_w, vis_h])
	g._reset_view()
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, name: String) -> void:
	if ok:
		print("  ok   ", name)
	else:
		print("  FAIL ", name)
		_fails += 1

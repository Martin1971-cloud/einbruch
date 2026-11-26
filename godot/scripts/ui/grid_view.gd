class_name GridView
extends GridZeichnung
## Rasteransicht: Eingabe (Klick, Zoom, Verschieben) und Auskunft (Hinweise beim Darüberfahren).
## Die Darstellung steht in grid_kern.gd und grid_zeichnung.gd.

func _init() -> void:
	custom_minimum_size = Vector2(420, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true  # Zeichnung bleibt in der Fläche, überdeckt keine Überschriften
	# Zoomknöpfe am rechten Rand, mittig: sichtbare Bedienung neben dem Mausrad
	zoom_box = VBoxContainer.new()
	zoom_box.add_theme_constant_override("separation", 6)
	zoom_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	zoom_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zoom_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	zoom_box.add_child(UI.button("+", func() -> void: _zoom_center(1.25), 40))
	zoom_box.add_child(UI.button("−", func() -> void: _zoom_center(0.8), 40))
	zoom_box.add_child(UI.button(Texte.t("grid.alles"), func() -> void: _reset_view(), 40))
	add_child(zoom_box)

func _gui_input(event: InputEvent) -> void:
	if target.is_empty():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.25)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 0.8)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
					_reset_view()
					return
				_pressing = true
				_dragged = false
				_press = mb.position
				return
			var was_drag := _dragged
			_pressing = false
			if mb.button_index == MOUSE_BUTTON_LEFT and not was_drag:
				_click(_press)
			return
	elif event is InputEventMouseMotion and not _pressing:
		var hc := Vector2i(floori((event.position.x - _origin.x) / _cw), floori((event.position.y - _origin.y) / _ch))
		if hc != _hover_cell:
			_hover_cell = hc
			queue_redraw()
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		if not _dragged and mm.position.distance_to(_press) < 4.0:
			return
		if not _dragged:
			follow = false
			if _tween != null:
				_tween.kill()
				_tween = null
		_dragged = true
		_pan += mm.relative
		_clamp_pan()
		_layout()
		queue_redraw()

## Ein Klick auf das Feld an Position pos (Bildschirm): Limousine, Feld, Person.
func _click(pos: Vector2) -> void:
	_layout()
	# Klick auf die Limousine zählt wie ein Klick auf das Wagenfeld (Einsteigen)
	if target.points.has("fluchtwagen"):
		var car_ex := Sim._v2i(target.points["fluchtwagen"])
		if _car_rect(car_ex).has_point(pos):
			cell_clicked.emit(car_ex)
			return
	var cx := int(floor((pos.x - _origin.x) / _cw))
	var cy := int(floor((pos.y - _origin.y) / _ch))
	if cx >= 0 and cy >= 0 and cx < String(target.map[0]).length() and cy < target.map.size():
		var here := Vector2i(cx, cy)
		var sb := Sim.SUB
		point_clicked.emit(Vector2i(floori((pos.x - _origin.x) * sb / _cw), floori((pos.y - _origin.y) * sb / _ch)))
		# Steht eine Person auf diesem Feld, wird sie ausgewählt. Mehrere auf einem Feld: reihum.
		var on_cell: Array = []
		for c in team:
			if Sim._v2i(c.start) == here:
				on_cell.append(c.id)
		# Auf dem Wagenfeld stehen am Start alle: Ist die gewählte Person dort, öffnet ein Klick das Wagenmenü
		var car_cell := Sim._v2i(target.points.fluchtwagen) if target.has("points") and target.points.has("fluchtwagen") else Vector2i(-1, -1)
		if here == car_cell and on_cell.has(selected_id):
			cell_clicked.emit(here)
			return
		if not on_cell.is_empty() and target.has("points"):
			var idx := on_cell.find(selected_id)
			person_clicked.emit(on_cell[(idx + 1) % on_cell.size()])
			return
		cell_clicked.emit(here)

## Zoom um die Mausposition: der Punkt unter dem Zeiger bleibt an derselben Stelle.
func _zoom_at(p: Vector2, factor: float) -> void:
	if target.is_empty():
		return
	if _tween != null:
		_tween.kill()
		_tween = null
	_layout()
	var w := (p - _origin) / _cw
	_zoom = clampf(_zoom * factor, 1.0, 8.0)
	var sc_new := _fit_scale() * _zoom
	_pan = (p - w * sc_new) - _base_origin(sc_new)
	_clamp_pan()
	_layout()
	queue_redraw()

## Ansicht auf ein Feld (Zelle, Feldkoordinaten) zentrieren. zoom > 0 setzt zugleich die Vergrößerung.
## animate: weicher Übergang (Auswahl), sonst sofort (Abspielen, jeder Frame).
func focus_on(cell: Vector2, zoom := -1.0, animate := true) -> void:
	if target.is_empty():
		return
	var z1: float = _zoom if zoom <= 0.0 else clampf(zoom, 1.0, 8.0)
	var sc := _fit_scale() * z1
	var want := size * 0.5 - Vector2(cell.x + 0.5, cell.y + 0.5) * sc
	# Fokus zentriert die Person auch am Rand des Gebäudes (nur manuelles Verschieben wird begrenzt)
	var z0 := _zoom
	var p0 := _pan
	var p1: Vector2 = want - _base_origin(sc)
	if _tween != null:
		_tween.kill()
		_tween = null
	if not animate or not is_inside_tree():
		_zoom = z1
		_pan = p1
		_layout()
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(func(t: float) -> void:
		_zoom = lerpf(z0, z1, t)
		_pan = p0.lerp(p1, t)
		_layout()
		queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Zoomknopf: Zoom um die Mitte der Ansicht.
func _zoom_center(factor: float) -> void:
	if target.is_empty():
		return
	_zoom_at(size * 0.5, factor)

func _reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT and _hover_cell != Vector2i(-1, -1):
		_hover_cell = Vector2i(-1, -1)
		queue_redraw()

func set_frame(f: Dictionary, noise: Array) -> void:
	## Zeigt den Zustand zu einem Zeitpunkt der Vorschau. Leeres Dictionary = Planungsansicht.
	_frame = f
	_noise = noise
	# Beim Abspielen folgt die Ansicht der gewählten Person (Position aus der Simulation)
	if follow and selected_id != "" and f.has("crew") and f.crew.has(selected_id):
		var cd: Array = f.crew[selected_id]
		focus_on(Vector2(float(cd[0]), float(cd[1])), -1.0, false)
	queue_redraw()

func set_state(p_target: Dictionary, p_intel: int, p_plans: Dictionary, p_team: Array) -> void:
	target = p_target
	intel = p_intel
	plans = p_plans
	team = p_team
	queue_redraw()

func set_planned_obj(d: Dictionary) -> void:
	_planned_obj = d
	queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	## Beim Darüberfahren: zuerst ein Haltepunkt oder eine Objekt-Aktion im Plan, sonst die Zelle.
	if target.is_empty():
		return ""
	if target.has("panel") and intel >= 1 and _c(target.panel.pos).distance_to(at_position) < _cell * 0.6:
		var namen: Array = []
		for z in _gesicherte_zellen():
			namen.append(Texte.t(str(z.name)))
		var status := Texte.t("grid.alarm_aus") if alarm_aus() else Texte.t("grid.alarm_aktiv")
		return "%s – %s\n%s" % [Texte.t(str(target.panel.name)), status, ", ".join(namen)]
	var best := -1
	var bd := _cell * 0.45
	for i in range(_waypoints.size()):
		var d := (_waypoints[i].pos as Vector2).distance_to(at_position)
		if d < bd:
			bd = d
			best = i
	var wp_txt := ""
	if best >= 0:
		var w: Dictionary = _waypoints[best]
		var txt := String(describe.call(w.action)) if describe.is_valid() else str(w.action.get("t", ""))
		wp_txt = "%s: %s" % [w.who, txt]
	var cx := int(floor((at_position.x - _origin.x) / _cw))
	var cy := int(floor((at_position.y - _origin.y) / _ch))
	var rows: Array = target.map
	if cy < 0 or cy >= rows.size():
		return ""
	var row: String = rows[cy]
	if cx < 0 or cx >= row.length():
		return ""
	var cell := Vector2i(cx, cy)
	# Beute am Feld: Wert immer anzeigen (auch bei einem Planhinweis darüber)
	for l in target.loot:
		if Sim._v2i(l.pos) == cell:
			var parts_txt := ""
			if l.has("parts"):
				var ps: Array = []
				for pt in l.parts:
					ps.append("%s %d €" % [Texte.t(str(pt[0])), int(pt[1])])
				parts_txt = " (%s)" % ", ".join(ps)
			var state := str(_frame.get("loot", {}).get(l.id, "ROOM")) if not _frame.is_empty() else "ROOM"
			var status := "" if state == "ROOM" else " – genommen"
			var loot_txt := "Beute: %s – %d €%s, Gewicht %.1f kg%s" % [Texte.t(l.name), int(l.value), parts_txt, float(l.weight), status]
			return loot_txt if wp_txt == "" else loot_txt + "\n" + wp_txt
	if wp_txt != "":
		return wp_txt
	if intel >= 1:
		for g in target.guards:
			if Sim._v2i(g.start) == cell:
				return Texte.t("gridv.sicht") % [Texte.t(g.name), int(g.vision), int(g.hearing)]
	for d in target.doors:
		if Sim._v2i(d.pos) == cell:
			return "%s – verschlossen (Dietrich, Brecheisen oder Bypass)" % Texte.t(d.name)
	match row.substr(cx, 1):
		"F":
			return Texte.t("gridv.fenster")
		"W":
			return Texte.t("gridv.wand")
		"o":
			return Texte.t("gridv.aussen")
		_:
			for room in target.get("rooms", []):
				if Sim._v2i(room.pos) == cell:
					return Texte.t(room.name).capitalize()
			return Texte.t("gridv.raum")

class_name GridView
extends Control

signal cell_clicked(cell: Vector2i)
signal point_clicked(fine: Vector2i)   # genaue Stelle in Unterfeldern (vor cell_clicked)
signal person_clicked(id: String)  # Klick auf eine Person im Grundriss (wählt sie aus)
var describe: Callable = Callable()   # Text einer Aktion (vom Planer gesetzt)
var _waypoints: Array = []
var selected_id := ""  # die gerade ausgewählte Person (wird markiert)
var _door_swing := {}    # Öffnungsgrad der Türen (0 = zu, 1 = offen), für die weiche Bewegung
var follow := false    # beim Abspielen der gewählten Person folgen (Verschieben beendet es)
var backdrop: Texture2D = null  # Hintergrundbild hinter dem Grundriss (ersetzt den Rasen außen)
var backdrop_alpha := 0.45       # Helligkeit des Hintergrundbilds
var _tween: Tween
const FOCUS_ZOOM := 2.0
var show_end := true   # Türen und Vitrinen im Endzustand des Plans zeigen (nicht bei der Wiedergabe)
## Grundriss für die Planung in gestalteter Darstellung: Parkettboden, plastische Wände,
## Schatten, Rasen, leuchtende Beute und geschwungene Wege. Skaliert in die verfügbare Fläche.

const COLORS := {
	"mira": Color(0.36, 0.78, 1.0),
	"ilja": Color(0.55, 0.95, 0.55),
	"teo": Color(1.0, 0.72, 0.32),
	"rosa": Color(1.0, 0.5, 0.78),
	"otto": Color(0.78, 0.56, 1.0),
	"greta": Color(0.45, 0.92, 0.88),
}
const ROUTE := Color(0.3, 0.95, 0.55)
const FLOOR_A := Color(0.88, 0.8, 0.66)
const FLOOR_B := Color(0.84, 0.75, 0.6)
const PLANK := Color(0.72, 0.6, 0.45, 0.35)
const WALL_TOP := Color(0.46, 0.5, 0.62)
const WALL := Color(0.19, 0.21, 0.3)
const WALL_SHADOW := Color(0.08, 0.09, 0.14)
const GRASS_A := Color(0.16, 0.33, 0.25)
const GRASS_B := Color(0.13, 0.28, 0.21)
const DOOR := Color(0.55, 0.36, 0.2)
const GOLD := Color(0.98, 0.8, 0.35)
const CYAN := Color(0.3, 0.9, 1.0)
const RED := Color(1.0, 0.32, 0.32)
const GLASS := Color(0.55, 0.8, 0.98)

var target: Dictionary = {}
var intel := 0
var plans: Dictionary = {}
var team: Array = []
var _cell := 26.0
var _origin := Vector2.ZERO
var _zoom := 1.0             # Zoomfaktor (1 = eingepasst)
var _pan := Vector2.ZERO      # Verschiebung in Bildschirmpunkten
var _pressing := false
var _dragged := false
var _press := Vector2.ZERO
var _hover_cell := Vector2i(-1, -1)  # Feld unter dem Mauszeiger (für Beutebilder im Planmodus)
const SPRITE_CELLS := 1.0  # Figur im Grundriss: Höhe in Feldern
var zoom_box: VBoxContainer
var _cw := 26.0  # Feldbreite (Felder füllen die Fläche, sind nicht zwingend quadratisch)
var _ch := 26.0  # Feldhöhe
var _frame: Dictionary = {}   # aktuelle Momentaufnahme der Simulation (leer = Planungsansicht)
var _noise: Array = []
var _planned_obj: Dictionary = {}  # Zustand der Türen und Vitrinen am Ende der Planung

const STATE_COL := {
	"PATROL": Color(0.35, 0.85, 0.55),
	"RESPOND": Color(0.45, 0.72, 1.0),
	"ALERT": Color(0.98, 0.85, 0.3),
	"INVESTIGATE": Color(1.0, 0.6, 0.25),
	"ALARMED": Color(1.0, 0.28, 0.28),
}
## Anzeige eines Zustands der Wache (Texte aus der Texttabelle)
static func _state_label(st: String) -> String:
	match st:
		"PATROL":
			return Texte.t("gridv.z_patrol")
		"RESPOND":
			return Texte.t("gridv.z_respond")
		"ALERT":
			return Texte.t("gridv.z_alert")
		"INVESTIGATE":
			return Texte.t("gridv.z_investigate")
		"ALARMED":
			return Texte.t("gridv.z_alarmed")
	return st


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
	zoom_box.add_child(UI.button("Alles", func() -> void: _reset_view(), 40))
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
	if target.points.has("Fluchtwagen"):
		var car_ex := Sim._v2i(target.points["Fluchtwagen"])
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
		var car_cell := Sim._v2i(target.points.Fluchtwagen) if target.has("points") and target.points.has("Fluchtwagen") else Vector2i(-1, -1)
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


func _clamp_pan() -> void:
	# Das Gebäude bleibt immer mit einem Teil im Bild. Bei der kleinsten Stufe ist es ganz zu sehen und zentriert.
	if _zoom <= 1.0:
		_pan = Vector2.ZERO
		return
	var sc := _fit_scale() * _zoom
	var b := _bounds()
	var bw := float(b.size.x) * sc
	var bh := float(b.size.y) * sc
	var min_vis := 160.0
	var x_off := sc * 0.5           # linker Rand des Gebäudes ohne Verschiebung
	var y_off := (size.y - bh) * 0.5  # oberer Rand ohne Verschiebung
	var lo_x := min_vis - bw - x_off
	var hi_x := size.x - min_vis - x_off
	var lo_y := min_vis - bh - y_off
	var hi_y := size.y - min_vis - y_off
	_pan.x = clampf(_pan.x, minf(lo_x, hi_x), maxf(lo_x, hi_x))
	_pan.y = clampf(_pan.y, minf(lo_y, hi_y), maxf(lo_y, hi_y))


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


func _layout() -> void:
	# Der Ausschnitt passt sich dem Gebäude an (eingepasst beim Start), mit Zoom und Verschiebung.
	# Felder sind quadratisch (1 Feld = 1 m), damit die Proportionen des Gebäudes stimmen.
	var sc := _fit_scale() * _zoom
	_cw = sc
	_ch = sc
	_cell = sc * 0.72
	_origin = _base_origin(sc) + _pan


## Maßstab, bei dem das Gebäude ganz in die Fläche passt.
func _fit_scale() -> float:
	var b := _bounds()
	return minf(size.x / float(b.size.x), size.y / float(b.size.y))


## Ursprung ohne Verschiebung: horizontal linksbündig mit kleinem Rand, vertikal zentriert.
func _base_origin(sc: float) -> Vector2:
	var b := _bounds()
	return Vector2(sc * 0.5, (size.y - float(b.size.y) * sc) * 0.5) - Vector2(b.position) * sc


## Rechteck (in Feldern) um das Gebäude: alle Felder außer Freiflächen, dazu Wagen und Beute, mit Rand von 2 Feldern.
func _bounds() -> Rect2i:
	if target.is_empty():
		return Rect2i(0, 0, 20, 12)
	var mn := Vector2i(999, 999)
	var mx := Vector2i(-999, -999)
	var rows: Array = target.map
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if row.substr(x, 1) != "o":
				mn = Vector2i(mini(mn.x, x), mini(mn.y, y))
				mx = Vector2i(maxi(mx.x, x), maxi(mx.y, y))
	for k in target.get("points", {}):
		var v := Sim._v2i(target.points[k])
		mn = Vector2i(mini(mn.x, v.x), mini(mn.y, v.y))
		mx = Vector2i(maxi(mx.x, v.x), maxi(mx.y, v.y))
	# Der Wagen steht außerhalb: sein Rechteck (4,2 m lang) gehört in den Ausschnitt
	if target.points.has("Fluchtwagen"):
		var ex := Sim._v2i(target.points["Fluchtwagen"])
		var o := _car_out(ex)
		for d in [2.5 - 2.1, 2.5 + 2.1]:
			var q: Vector2 = Vector2(ex) + o * d
			mn = Vector2i(mini(mn.x, floori(q.x)), mini(mn.y, floori(q.y)))
			mx = Vector2i(maxi(mx.x, floori(q.x)), maxi(mx.y, floori(q.y)))
	mn -= Vector2i(1, 1)
	mx += Vector2i(1, 1)
	mn = Vector2i(maxi(mn.x, 0), maxi(mn.y, 0))
	mx = Vector2i(mini(mx.x, 19), mini(mx.y, 11))
	return Rect2i(mn, mx - mn + Vector2i(1, 1))


func _c(cell) -> Vector2:
	var v := Sim._v2i(cell)
	return _origin + Vector2(v.x * _cw + _cw * 0.5, v.y * _ch + _ch * 0.5)


## Rechteck in Unterfeldern (wie in Sim.paint) auf den Bildschirm.
func _frect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var sb := float(Sim.SUB)
	return Rect2(_origin + Vector2(x0 * _cw / sb, y0 * _ch / sb), Vector2((x1 - x0) * _cw / sb, (y1 - y0) * _ch / sb))


## Feiner Grundriss: Innenraum, Wände, Fenster, Türen und Vitrinen als Rechtecke.
## Türblatt: 1,0 m breit, in der Öffnung zentriert, 25 cm dick.
func _thin_leaf(r: Rect2) -> Rect2:
	var t := 0.25 * sqrt(_cw * _ch)
	var leaf := 1.0 * sqrt(_cw * _ch)
	if r.size.x >= r.size.y:
		return Rect2(r.get_center().x - leaf * 0.5, r.get_center().y - t * 0.5, leaf, t)
	return Rect2(r.get_center().x - t * 0.5, r.get_center().y - leaf * 0.5, t, leaf)


## Mauerstück als dünne Linie (25 cm) auf der Mittelachse. Richtung aus den Nachbarn: Wände laufen
## in Richtung der Wand-Nachbarn, Ecken und Einzelstücke nach der Form.
func _wall_line(r: Array, rect: Rect2) -> Rect2:
	var t := 0.25 * sqrt(_cw * _ch)
	var x0 := int(r[0])
	var y0 := int(r[1])
	var x1 := int(r[2])
	var y1 := int(r[3])
	var mx := (x0 + x1) / 2
	var my := (y0 + y1) / 2
	var up := Sim.plan_tile(target, Vector2i(mx, y0 - 1)) == "W" or Sim.plan_tile(target, Vector2i(mx, y1)) == "W"
	var side := Sim.plan_tile(target, Vector2i(x0 - 1, my)) == "W" or Sim.plan_tile(target, Vector2i(x1, my)) == "W"
	var vertical: bool
	if up and not side:
		vertical = true
	elif side and not up:
		vertical = false
	else:
		vertical = rect.size.y > rect.size.x
	var c := rect.get_center()
	if vertical:
		return Rect2(c.x - t * 0.5, rect.position.y, t, rect.size.y)
	return Rect2(rect.position.x, c.y - t * 0.5, rect.size.x, t)


## Wand oder Tür im Grundriss: wie in 3D 25 cm dick, zentriert auf dem Originalmaß.
func _thin(r: Rect2) -> Rect2:
	var t := 0.25 * sqrt(_cw * _ch)
	if r.size.x >= r.size.y:
		return Rect2(r.position.x, r.get_center().y - t * 0.5, r.size.x, t)
	return Rect2(r.get_center().x - t * 0.5, r.position.y, t, r.size.y)


## Fluchtwagen als Limousine (4,6 × 1,8 m) außerhalb des Gebäudes, Front zum Haus (wie in 3D).
## Richtung vom Gebäude weg, in der der Wagen steht (wie in der 3D-Ansicht).
func _car_out(ex: Vector2i) -> Vector2:
	var w: float = float(target.map[0].length())
	var h: float = float(target.map.size())
	var out := Vector2(signf(float(ex.x) - w * 0.5), signf(float(ex.y) - h * 0.5))
	if absf(out.x) >= absf(out.y):
		return Vector2(out.x, 0.0)
	return Vector2(0.0, out.y)


## Rechteck der Limousine auf dem Bildschirm (für Zeichnung und Klick).
func _car_rect(ex: Vector2i) -> Rect2:
	var out := _car_out(ex)
	var center := _c(ex) + Vector2(out.x * 2.5 * _cw, out.y * 2.5 * _ch)
	var along := 4.2 * (_cw if out.x != 0.0 else _ch)
	var across := 1.6 * (_ch if out.x != 0.0 else _cw)
	return Rect2(center - Vector2(along, across) * 0.5, Vector2(along, across)) if out.x != 0.0 else Rect2(center - Vector2(across, along) * 0.5, Vector2(across, along))


func _draw_car(ex: Vector2i) -> void:
	var out := _car_out(ex)
	var body := _car_rect(ex)
	var center := body.get_center()
	var along := body.size.x if out.x != 0.0 else body.size.y
	var across := body.size.y if out.x != 0.0 else body.size.x
	draw_rect(Rect2(body.position + Vector2(2, 3), body.size), Color(0, 0, 0, 0.35))
	draw_rect(body, Color(0.08, 0.08, 0.1))
	draw_rect(body.grow(-across * 0.12), Color(0.35, 0.5, 0.62, 0.9))
	# Scheinwerfer zum Gebäude
	var front := center - out * along * 0.5
	draw_circle(front + Vector2(-out.y, out.x) * across * 0.3, _cell * 0.1, Color(1, 1, 0.8))
	draw_circle(front - Vector2(-out.y, out.x) * across * 0.3, _cell * 0.1, Color(1, 1, 0.8))
	_text_center(center + Vector2(0, -across * 0.5 - _cell * 0.3), "Fluchtwagen", Color(0.97, 0.85, 0.5), maxf(9.0, _cell * 0.36))


func _draw_fine(spec: Dictionary) -> void:
	# Außenkanten: senkrechte Wände enden an der Außenkante der waagerechten und umgekehrt.
	# So ragt an keiner Ecke ein Wandstück über das Gebäude hinaus (wie beim Original-Mauerwerk).
	var t := 0.25 * sqrt(_cw * _ch)
	var lines := []
	var vx0 := INF
	var vx1 := -INF
	var hy0 := INF
	var hy1 := -INF
	for r in spec.paint:
		if String(r[4]) == "W":
			var wl := _wall_line(r, _frect(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
			lines.append(wl)
			if wl.size.x < wl.size.y:
				vx0 = minf(vx0, wl.get_center().x)
				vx1 = maxf(vx1, wl.get_center().x)
			else:
				hy0 = minf(hy0, wl.get_center().y)
				hy1 = maxf(hy1, wl.get_center().y)
	var wi := 0
	for r in spec.paint:
		var rect := _frect(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		match String(r[4]):
			".":
				_tile(rect, "parkett", 0, 0)
			"W":
				var line: Rect2 = lines[wi]
				wi += 1
				if line.size.x < line.size.y:
					if hy0 < INF:
						var y0 := maxf(line.position.y, hy0 - t * 0.5)
						var y1 := minf(line.end.y, hy1 + t * 0.5)
						line = Rect2(line.position.x, y0, line.size.x, maxf(0.0, y1 - y0))
				elif vx0 < INF:
					var x0 := maxf(line.position.x, vx0 - t * 0.5)
					var x1 := minf(line.end.x, vx1 + t * 0.5)
					line = Rect2(x0, line.position.y, maxf(0.0, x1 - x0), line.size.y)
				draw_rect(line.grow(1.0), Color(0.08, 0.09, 0.14))
				draw_rect(line, WALL_TOP)
			"F":
				# Schaufenster: offen = Öffnung (Boden sichtbar), zu = Glas
				var anc_w := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				if _is_open(anc_w.x, anc_w.y):
					draw_rect(rect, Color(0.8, 0.84, 0.9) * 0.97)
				else:
					rect = _thin(rect)
					draw_rect(rect, GLASS)
			"D":
				rect = _thin_leaf(rect)
				var anc := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				# Weiche Bewegung: das Blatt schwingt von zu (0) nach offen (1) und zurück
				var goal := 1.0 if _is_open(anc.x, anc.y) else 0.0
				var cur: float = _door_swing.get(anc, goal)
				if absf(cur - goal) > 0.001:
					cur = move_toward(cur, goal, 0.12)
					queue_redraw()
				_door_swing[anc] = cur
				var leaf := 1.0 * sqrt(_cw * _ch)
				var tk := 0.25 * sqrt(_cw * _ch)
				if cur > 0.001:
					# Blatt im Winkel zur Wand, am Scharnier; Winkel wächst mit der Bewegung
					var horiz := rect.size.x > rect.size.y
					var hinge_p := rect.position + (Vector2(0, rect.size.y * 0.5) if horiz else Vector2(rect.size.x * 0.5, 0))
					var ang := -PI * 0.5 * cur if horiz else PI * 0.5 * cur
					var tip := hinge_p + Vector2(cos(ang), sin(ang)) * leaf if horiz else hinge_p + Vector2(cos(ang), sin(ang)) * leaf
					draw_line(hinge_p, tip, DOOR, tk)
				if cur < 0.999:
					draw_rect(rect, DOOR.lerp(Color(0, 0, 0, 0), cur))
					if goal < 0.5:
						draw_circle(rect.get_center() + Vector2(rect.size.x * 0.3, 0), maxf(1.5, _cell * 0.06), GOLD)
			"C":
				draw_rect(rect, Color(0.93, 0.9, 0.86))
				draw_rect(rect, GOLD, false, 1.0)
			"S":
				draw_rect(rect, Color(0.55, 0.55, 0.6))
				draw_rect(rect, GOLD, false, 1.0)
			"K":
				# Kassengerät, 0,45 m, auf dem Tresen
				var kc := rect.get_center()
				var ks := 0.45 * sqrt(_cw * _ch)
				draw_rect(Rect2(kc - Vector2(ks, ks) * 0.5, Vector2(ks, ks)), Color(0.85, 0.2, 0.2))


## Mitte eines Unterfeldes auf dem Bildschirm.
func _fpos(f: Vector2i) -> Vector2:
	var sb := float(Sim.SUB)
	return _origin + Vector2((f.x + 0.5) * _cw / sb, (f.y + 0.5) * _ch / sb)


var _icons := {}


## Beuteicon aus der Tabelle (GameData.LOOT_TABLE), oder null.
func font_for_label() -> Font:
	return ThemeDB.fallback_font


## Geldbetrag mit Punkten als Tausendertrennung (16.000).
func _grp_money(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	var i := t.length()
	while i > 3:
		out = "." + t.substr(i - 3, 3) + out
		i -= 3
	return ("-" if n < 0 else "") + t.substr(0, i) + out


func _loot_icon(lid: String) -> Texture2D:
	var name: String = String(GameData.LOOT_TABLE.get(lid, {}).get("icon", ""))
	if name == "":
		return null
	if not _icons.has(name):
		var path := "res://assets/icons/loot/%s.png" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


func _rect(x: int, y: int) -> Rect2:
	return Rect2(_origin + Vector2(x * _cw, y * _ch), Vector2(_cw, _ch))


func _hash(x: int, y: int) -> float:
	## Deterministische Pseudo-Zufallszahl für Muster (kein Flackern beim Neuzeichnen).
	var n := x * 374761 + y * 668265
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 1023) / 1023.0


var _tiles := {}


func _tile_tex(name: String) -> Texture2D:
	if not _tiles.has(name):
		var path := "res://assets/tiles/%s.png" % name
		_tiles[name] = load(path) if ResourceLoader.exists(path) else null
	return _tiles[name]


## Kachel in die Zelle legen. Ein Ausschnitt je Zelle, damit nicht alles gleich aussieht.
## Grundriss-Stil B (modern, flach): reine Flächen, dünne Linien, kühle Palette.
const FLAT := true
const FLAT_COL := {
	"parkett": Color(0.80, 0.84, 0.90),
	"mauer": Color(0.16, 0.20, 0.28),
	"rasen": Color(0.12, 0.17, 0.22),
	"fenster": Color(0.55, 0.78, 0.95),
}


func _tile(r: Rect2, name: String, x: int, y: int) -> void:
	if FLAT:
		draw_rect(r, FLAT_COL.get(name, Color(0.8, 0.84, 0.9)))
		draw_rect(r, Color(0.45, 0.52, 0.64, 0.35), false, 1.0)
		return
	var tex := _tile_tex(name)
	if tex == null:
		draw_rect(r, FLOOR_A)
		return
	var n := float(tex.get_width())
	var ox := floorf(_hash(x, y) * (n - 64.0))
	var oy := floorf(_hash(y, x) * (n - 64.0))
	draw_texture_rect_region(tex, r, Rect2(ox, oy, 64, 64))


## Etage der ausgewählten Person (Index) oder -1. Position aus der Vorschau, sonst vom Start.
func _active_floor_idx() -> int:
	if not target.has("floors") or selected_id == "":
		return -1
	var y := -1.0
	if _frame.has("crew") and _frame.crew.has(selected_id):
		y = float(_frame.crew[selected_id][1]) / float(Sim.SUB)
	else:
		for c in team:
			if c.id == selected_id and c.has("start"):
				y = float(Sim._v2i(c.start).y)
	if y < 0.0:
		return -1
	for i in range(target.floors.size()):
		var rows: Array = target.floors[i].rows
		if y >= float(rows[0]) and y < float(rows[1]):
			return i
	return -1


## Andere Etagen werden abgedunkelt, die Etage der ausgewählten Person bleibt hell.
func _draw_dim_floors() -> void:
	var act := _active_floor_idx()
	if act < 0:
		return
	var w: float = String(target.map[0]).length() * _cw
	for i in range(target.floors.size()):
		if i == act:
			continue
		var rows: Array = target.floors[i].rows
		var y0: float = _origin.y + float(rows[0]) * _ch
		var h: float = float(int(rows[1]) - int(rows[0])) * _ch
		draw_rect(Rect2(_origin.x, y0, w, h), Color(0.03, 0.05, 0.09, 0.5))


## Etagen: Trennlinie und Name am Anfang jeder Etage (nur wenn das Ziel Etagen hat).
func _draw_floors() -> void:
	if not target.has("floors"):
		return
	var w: float = String(target.map[0]).length() * _cw
	var font := ThemeDB.fallback_font
	for i in range(target.floors.size()):
		var fl: Dictionary = target.floors[i]
		var y: float = _origin.y + float(fl.rows[0]) * _ch
		if i > 0:
			draw_line(Vector2(_origin.x, y), Vector2(_origin.x + w, y), Color(0.97, 0.85, 0.55, 0.75), 2.0)
		draw_string(font, Vector2(_origin.x + 6, y + 18), Texte.d(str(fl.name)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.97, 0.85, 0.55, 0.9))


func _draw() -> void:
	if target.is_empty():
		return
	_layout()
	if backdrop != null:
		# Bild füllt die Fläche (gleichmäßig skaliert, Mitte sichtbar), etwas abgedunkelt
		var ts := backdrop.get_size()
		var k := maxf(size.x / ts.x, size.y / ts.y)
		var sz := ts * k
		draw_texture_rect(backdrop, Rect2((size - sz) * 0.5, sz), false, Color(backdrop_alpha, backdrop_alpha, backdrop_alpha + 0.05))
	var rows: Array = target.map
	var frame := Rect2(_origin, Vector2(String(rows[0]).length() * _cw, rows.size() * _ch))
	var fine: Dictionary = Sim.fine_spec(target) if target.has("fine") else {}
	# Schatten des Gebäudes auf dem Rasen (mit feinem Grundriss entfällt er, die Wände sind dünn)
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			if fine.is_empty() and (row.substr(x, 1) == "W" or row.substr(x, 1) == "F"):
				draw_rect(Rect2(_rect(x, y).position + Vector2(_cw * 0.1, _ch * 0.16), Vector2(_cw, _ch)), Color(0, 0, 0, 0.28))
	# Untergrund
	for y in range(rows.size()):
		var row2: String = rows[y]
		for x in range(row2.length()):
			var t := row2.substr(x, 1)
			var r := _rect(x, y)
			if not fine.is_empty() and t != "o":
				continue
			match t:
				"F":
					_tile(r, "mauer", x, y)
					_tile(r.grow(-_cell * 0.14), "fenster", x, y)
					draw_line(r.position + Vector2(_cell * 0.5, _cell * 0.14), r.position + Vector2(_cell * 0.5, _cell * 0.86), Color(0.2, 0.25, 0.35, 0.8), 1.0)
					draw_rect(r.grow(-_cell * 0.14), Color(0.8, 0.92, 1.0, 0.8), false, 1.0)
				"W":
					_tile(r, "mauer", x, y)
					draw_rect(Rect2(r.position, Vector2(r.size.x, maxf(2.0, _cell * 0.12))), WALL_TOP)
					draw_rect(Rect2(r.position + Vector2(0, r.size.y - _cell * 0.1), Vector2(r.size.x, _cell * 0.1)), WALL_SHADOW)
				"o":
					if backdrop != null:
						continue   # außen kein Rasen: das Hintergrundbild bleibt sichtbar
					_tile(r, "rasen", x, y)
					var d := _hash(x, y)
					if d > 0.6:
						draw_circle(r.position + Vector2(_cell * d * 0.8 + 2, _cell * 0.6), _cell * 0.05, Color(0.3, 0.5, 0.35, 0.5))
				"D":
					draw_rect(r, FLOOR_A)
				_:
					_tile(r, "parkett", x, y)
					# Dielen: horizontale Fugen in unregelmäßigem Abstand
					var k := _hash(x, y)
					draw_line(r.position + Vector2(0, _ch * (0.33 + k * 0.1)), r.position + Vector2(_cw, _ch * (0.33 + k * 0.1)), PLANK, 1.0)
					draw_line(r.position + Vector2(0, _ch * (0.72 - k * 0.12)), r.position + Vector2(_cw, _ch * (0.72 - k * 0.12)), PLANK, 1.0)
	if not fine.is_empty():
		_draw_fine(fine)
	# Türen mit Schwung und Griff (mit feinem Grundriss sind sie oben gezeichnet)
	for y in range(rows.size()):
		var row3: String = rows[y]
		for x in range(row3.length()):
			if fine.is_empty() and row3.substr(x, 1) == "D":
				var c := _c(Vector2i(x, y))
				if _is_open(x, y):
					draw_arc(c, _cell * 0.5, 0, PI * 0.5, 12, Color(0.55, 0.36, 0.2, 0.7), 2.0)
					continue
				draw_rect(Rect2(_rect(x, y).position + Vector2(_cell * 0.1, _cell * 0.25), Vector2(_cell * 0.8, _cell * 0.5)), DOOR)
				draw_circle(c + Vector2(_cell * 0.22, 0), _cell * 0.07, GOLD)
				draw_arc(c, _cell * 0.5, 0, PI * 0.5, 12, Color(0.55, 0.36, 0.2, 0.35), 1.0)
	# Raumnamen
	for room in target.get("rooms", []):
		var p := _c(room.pos)
		var txt: String = Texte.d(room.name)
		var fs := maxi(9, int(_cell * 0.4))
		var sz := ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(ThemeDB.fallback_font, p + Vector2(-sz.x * 0.5 + 1, fs * 0.35 + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.04, 0.03, 0.7))
		draw_string(ThemeDB.fallback_font, p + Vector2(-sz.x * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.9, 0.7, 0.9))
	# Außenrahmen
	draw_rect(frame, Color(0.9, 0.85, 0.7, 0.18), false, 2.0)

	# Wachen: Sichtradius und Routen (ab Ermittlungsstand 1)
	for g in (target.guards if _frame.is_empty() else []):
		var start := _c(g.start)
		if intel >= 1:
			var vis := float(g.vision) * _cell
			draw_circle(start, vis, Color(RED, 0.08))
			draw_arc(start, vis, 0, TAU, 56, Color(RED, 0.35), 1.5)
			var route: Array = g.route
			for i in range(route.size()):
				_dashed(_c(route[i]), _c(route[(i + 1) % route.size()]), Color(RED, 0.8), 2.0)
			draw_circle(start + Vector2(1.5, 2), _cell * 0.36, Color(0, 0, 0, 0.35))
			draw_circle(start, _cell * 0.36, Color(0.9, 0.2, 0.2))
			draw_arc(start, _cell * 0.36, 0, TAU, 24, Color(1, 1, 1, 0.85), 1.5)
		else:
			draw_circle(start, _cell * 0.36, Color(0.42, 0.44, 0.5))
			_text_center(start, "?", Color.WHITE, _cell * 0.45)

	# Sensoren und Alarmpanel
	if intel >= 2:
		for s in target.sensors:
			var sp := _c(s.pos)
			draw_circle(sp, _cell * 0.7, Color(CYAN, 0.18))
			draw_circle(sp, _cell * 0.4, Color(CYAN, 0.35))
			draw_rect(Rect2(sp - Vector2(_cell * 0.2, _cell * 0.2), Vector2(_cell * 0.4, _cell * 0.4)), CYAN)
		if target.has("panel"):
			var pp := _c(target.panel.pos)
			draw_circle(pp, _cell * 0.7, Color(CYAN, 0.2))
			draw_rect(Rect2(pp - Vector2(_cell * 0.3, _cell * 0.3), Vector2(_cell * 0.6, _cell * 0.6)), Color(0.08, 0.16, 0.2))
			draw_rect(Rect2(pp - Vector2(_cell * 0.3, _cell * 0.3), Vector2(_cell * 0.6, _cell * 0.6)), CYAN, false, 2.0)
	else:
		for s in target.sensors:
			draw_rect(Rect2(_c(s.pos) - Vector2(_cell * 0.12, _cell * 0.12), Vector2(_cell * 0.24, _cell * 0.24)), Color(0.4, 0.45, 0.5))

	# Fluchtwagen am Ausgang: alle Einbrecherinnen starten hier und steigen hier wieder ein
	if target.points.has("Fluchtwagen"):
		_draw_car(Sim._v2i(target.points["Fluchtwagen"]))
	# Beute mit Leuchten
	for l in target.loot:
		# Hinweis nur, solange die Beute noch im Objekt liegt (Planung immer)
		if not _frame.is_empty() and str(_frame.get("loot", {}).get(l.id, "ROOM")) != "ROOM":
			continue
		# Beute ist immer sichtbar: goldener Ring, Bild und Wert. Die Details (Gewicht, Kategorie) zeigt der Hover.
		var lp := _c(l.pos)
		var hot: bool = Sim._v2i(l.pos) == _hover_cell
		var ico := _loot_icon(l.id)
		var isz := _cell * 1.15
		draw_circle(lp, isz * 0.62, Color(GOLD, 0.22 if not hot else 0.4))
		draw_arc(lp, isz * 0.62, 0, TAU, 28, GOLD, 2.0 if not hot else 3.0)
		if hot and ico != null:
			# Mit Maus: das Beutestück als Bild
			draw_texture_rect(ico, Rect2(lp - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false)
		else:
			# Ohne Maus: nur ein Markierungspunkt, das Bild bleibt dem Darüberfahren vorbehalten
			draw_circle(lp, _cell * 0.3, GOLD)
			draw_circle(lp, _cell * 0.3, Color(0.05, 0.06, 0.09), false, 1.5)
		# Wertangabe als kleines Schild unter dem Objekt
		var val := "%s €" % _grp_money(int(l.value))
		var fs := maxi(10, int(_cell * 0.34))
		var vsz := font_for_label().get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var vb := Rect2(lp + Vector2(-vsz.x * 0.5 - 4, isz * 0.62 + 2), Vector2(vsz.x + 8, fs + 6))
		draw_rect(vb, Color(0.05, 0.06, 0.09, 0.9))
		draw_rect(vb, GOLD, false, 1.0)
		draw_string(font_for_label(), vb.position + Vector2(4, fs + 1), val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.85, 0.55))
		_draw_lock_marker(Sim._v2i(l.pos))

	# Geplante Wege je Person. Jede Person bekommt einen kleinen seitlichen Versatz, damit sich Wege an
	# Engstellen (Tür, Tresen) nicht überdecken. Haltepunkte und Objekt-Aktionen sind anklickbar (Hover).
	_waypoints.clear()
	var nteam := team.size()
	for ti in range(nteam):
		var c: Dictionary = team[ti]
		var col: Color = COLORS.get(c.id, Color.WHITE)
		var fade := 1.0 if (selected_id == "" or c.id == selected_id) else 0.22
		var shift := Vector2.ONE * (float(ti) - float(nteam - 1) * 0.5) * 0.16 * _cell if nteam > 1 else Vector2.ZERO
		var pos := _c(c.start) + shift
		var n := 1
		var actions: Array = plans.get(c.id, [])
		var pts: Array = [pos]          # Haltepunkte (für die Nummern)
		var line: Array = [pos]         # Weg entlang der begehbaren Unterfelder
		var prev_f: Vector2i = Sim.center_i(Sim._v2i(c.start))
		for a in actions:
			var goal := Vector2i(-1, -1)
			var obj_pos := Vector2(-1, -1)
			if a.t == "MOVE" and a.has("fine"):
				goal = Vector2i(int(a.fine[0]), int(a.fine[1]))
			elif a.t == "MOVE" and a.has("cell"):
				goal = Sim.center_i(Vector2i(int(a.cell[0]), int(a.cell[1])))
			elif a.t == "MOVE" and target.points.has(a.get("to", "")):
				goal = Sim.center_i(Sim._v2i(target.points[a.get("to", "")]))
			elif a.has("on") and target.points.has(a.get("on", "")):
				obj_pos = _c(target.points[a.on])
			elif a.has("loot"):
				for l in target.loot:
					if l.id == a.loot:
						obj_pos = _c(l.pos)
			if goal.x < 0:
				if obj_pos.x >= 0:
					_waypoints.append({"pos": obj_pos + shift, "action": a, "who": c.name, "color": col})
				continue
			for f in Sim.plan_route(target, prev_f, goal):
				line.append(_fpos(f) + shift)
			if line.size() == 1:
				line.append(_fpos(goal) + shift)
			var gp := _fpos(goal) + shift
			pts.append(gp)
			_waypoints.append({"pos": gp, "action": a, "who": c.name, "color": col})
			prev_f = goal
		# Keine Laufwege mehr: nur die nummerierten Aktionsmarken. Die Marken der gewählten Person sind größer.
		var mr := _cell * (0.44 if c.id == selected_id else 0.36)
		for i in range(1, pts.size()):
			var q: Vector2 = pts[i]
			draw_circle(q + Vector2(1, 2), mr, Color(0, 0, 0, 0.35 * fade))
			draw_circle(q, mr, Color(col, fade))
			_text_center(q, str(n), Color(0.05, 0.05, 0.08), _cell * 0.4)
			n += 1

	# Personen auf Startpositionen
	for i in range(team.size()):
		var c: Dictionary = team[i]
		if not _frame.is_empty():
			break
		var col2: Color = COLORS.get(c.id, Color.WHITE)
		var pc := _c(c.start)
		if c.id == selected_id:
			draw_arc(pc, _cell * 0.6, 0, TAU, 24, Color(0.98, 0.85, 0.35), 3.0)
		_draw_sprite(pc, "crew_%s" % c.id, false, Vector2(0, 1))
		_number_badge(pc, i + 1, COLORS.get(c.id, Color.WHITE))
	if not _frame.is_empty():
		_draw_dynamic()



## Kleines Zeichen am Schloss: rotes Schloss = verschlossen, gelb = entriegelt, grüner Ring = offen.
func _draw_lock_marker(cell: Vector2i) -> void:
	var st := _obj_at(cell.x, cell.y)
	if st.is_empty():
		return
	var p := _c(cell) + Vector2(_cell * 0.32, -_cell * 0.32)
	var s := _cell * 0.2
	if bool(st.get("open", false)):
		draw_arc(p, s, 0, TAU, 16, Color(0.5, 1.0, 0.55), 2.5)
	elif bool(st.get("locked", false)):
		draw_rect(Rect2(p - Vector2(s, s * 0.6), Vector2(s * 2, s * 1.6)), Color(0.9, 0.2, 0.2))
		draw_arc(p + Vector2(0, -s * 0.6), s * 0.6, PI, TAU, 8, Color(0.9, 0.2, 0.2), 2.0)
	else:
		draw_circle(p, s * 0.8, Color(1.0, 0.85, 0.3))


## Person im Grundriss. Läuft sie, wechseln die Beine und der Körper hebt sich leicht (Original: livDoAnims).
func _draw_walker(cp: Vector2, col: Color, initial: String, cdata: Array, key := "") -> void:
	var moving: bool = bool(cdata[4]) if cdata.size() > 4 else false
	if key != "":
		# Figur als Sprite wie in 3D, aber nur ein Feld hoch: bleibt im Grundriss und ragt nicht über die Wände
		var dir := Vector2(cdata[5], cdata[6]) if cdata.size() > 6 else Vector2(0, 1)
		var act := str(cdata[7]) if cdata.size() > 7 else ""
		var t := Time.get_ticks_msec() / 1000.0
		var n := dir.normalized() if dir.length() > 0.001 else Vector2(0, 1)
		var lift := 0.0
		if act == "TAKE":
			# Bücken und Aufnehmen: die Figur senkt sich kurz
			lift = absf(sin(t * 6.0)) * _cell * 0.12
		_draw_sprite(cp + Vector2(0, lift), key, moving, dir)
		var hand := cp + n * _cell * 0.32 + Vector2(0, _cell * 0.1)
		if act == "TOOL":
			# Werkzeug am Schloss: Funken pulsieren an der Hand
			var pulse := 0.5 + 0.5 * sin(t * 14.0)
			draw_circle(hand, _cell * (0.12 + 0.08 * pulse), Color(1.0, 0.85, 0.3, 0.55 + 0.4 * pulse))
			draw_arc(hand, _cell * 0.22, 0, TAU, 12, Color(1.0, 0.85, 0.3, 0.8), 1.5)
		elif act == "OPEN":
			# Tür oder Vitrine geht auf: ein Bogen zeigt die Bewegung
			var a0 := n.angle() - 0.6 + 0.6 * sin(t * 4.0)
			draw_arc(cp + n * _cell * 0.4, _cell * 0.35, a0, a0 + 0.9, 10, Color(1.0, 0.85, 0.3, 0.9), 2.0)
		elif act == "TAKE":
			# Beute wird aufgenommen: ein goldener Punkt steigt über dem Kopf auf
			var up := fmod(t * 1.5, 1.0)
			draw_circle(cp + Vector2(0, -_cell * (0.6 + 0.3 * up)), _cell * 0.12, Color(0.98, 0.82, 0.25, 1.0 - up))
		return
	var phase := 0.0
	var bob := 0.0
	if moving:
		phase = fmod(float(_frame.get("t", 0.0)) * 6.0, TAU)
		bob = absf(sin(phase)) * _cell * 0.06
		var step := sin(phase) * _cell * 0.22
		draw_line(cp + Vector2(-_cell * 0.12, _cell * 0.34), cp + Vector2(-_cell * 0.12 + step, _cell * 0.6), Color(0.05, 0.07, 0.12), 3.0)
		draw_line(cp + Vector2(_cell * 0.12, _cell * 0.34), cp + Vector2(_cell * 0.12 - step, _cell * 0.6), Color(0.05, 0.07, 0.12), 3.0)
	var body := cp + Vector2(0, -bob)
	draw_circle(cp + Vector2(1, 2), _cell * 0.44, Color(0, 0, 0, 0.4))
	draw_circle(body, _cell * 0.44, Color(0.05, 0.07, 0.12))
	draw_circle(body, _cell * 0.38, col)
	_text_center(body, initial, Color(0.05, 0.05, 0.08), _cell * 0.42)


## Nummer einer Person über ihrer Figur. Die Zuordnung Nummer -> Name steht in der Legende.
func _number_badge(cp: Vector2, n: int, col: Color) -> void:
	var p := cp + Vector2(_cell * 0.42, -_cell * 0.95)
	draw_circle(p, _cell * 0.24, Color(0.05, 0.06, 0.1, 0.95))
	draw_arc(p, _cell * 0.24, 0, TAU, 16, col, 2.0)
	_text_center(p, str(n), Color(0.98, 0.96, 0.9), _cell * 0.3)


## Figur als Bild aus assets/sprites: Blickrichtung (Vorn, Rücken, Seite), Gehzyklus bei Bewegung.
var _sprite_cache := {}


func _sprite(key: String, pose: String) -> Texture2D:
	var k := "%s_%s" % [key, pose]
	if not _sprite_cache.has(k):
		_sprite_cache[k] = load("res://assets/sprites/%s.png" % k) if ResourceLoader.exists("res://assets/sprites/%s.png" % k) else null
	return _sprite_cache[k]


func _draw_sprite(cp: Vector2, key: String, moving: bool, dir: Vector2) -> void:
	var view := ""
	var flip := false
	if absf(dir.x) >= absf(dir.y) and dir.length() > 0.001:
		view = "_side"
		flip = dir.x < 0.0
	elif dir.y < 0.0:
		view = "_back"
	var pose := "idle"
	if moving:
		var t := float(_frame.get("t", 0.0))
		pose = ["walk1", "walk2", "walk3", "walk4"][int(t * 8.0) % 4]
	var tex := _sprite(key + view, pose)
	if tex == null:
		return
	# Im Grundriss nur ein Feld hoch, damit die Figur im Feld bleibt (in 3D 1,8 m)
	var h := SPRITE_CELLS * _ch
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var r := Rect2(cp.x - w * 0.5, cp.y + _ch * 0.4 - h, w, h)
	if flip:
		r.position.x += w
		r.size.x = -w
	draw_texture_rect(tex, r, false)
	# Blickrichtung: kleines Dreieck am Fuß, zeigt wohin die Person schaut
	var d := dir.normalized() if dir.length() > 0.001 else Vector2(0, 1)
	var tip := cp + d * _cell * 0.62
	var side := Vector2(-d.y, d.x) * _cell * 0.16
	var base := cp + d * _cell * 0.38
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(0.98, 0.9, 0.5, 0.95))


func _text_center(p: Vector2, txt: String, col: Color, fs: float) -> void:
	var size := ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs))
	draw_string(ThemeDB.fallback_font, p + Vector2(-size.x * 0.5, size.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), col)


func _dashed(a: Vector2, b: Vector2, col: Color, width := 2.0) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.5:
		return
	var dir := d / length
	var t := 0.0
	var dash := 5.0
	while t < length:
		var s := minf(t + dash, length)
		draw_line(a + dir * t, a + dir * s, col, width)
		t += dash * 2.0


func _arrow_head(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	if d.length() < 1.0:
		return
	var dir := d.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := b - dir * (_cell * 0.42)
	var s := _cell * 0.24
	draw_colored_polygon(PackedVector2Array([tip + dir * s, tip - perp * s * 0.6, tip + perp * s * 0.6]), col)


func set_planned_obj(d: Dictionary) -> void:
	_planned_obj = d
	queue_redraw()


## Zustand eines Schlosses an dieser Zelle: Momentaufnahme, sonst Planungsstand.
func _obj_at(x: int, y: int) -> Dictionary:
	var src: Dictionary = _frame.get("obj", {}) if (not _frame.is_empty() and not show_end) else _planned_obj
	return src.get("%d,%d" % [x, y], {})


func _is_open(x: int, y: int) -> bool:
	if _frame.is_empty() or show_end:
		return bool(_obj_at(x, y).get("open", false))
	for oc in _frame.get("open", []):
		if int(oc[0]) == x and int(oc[1]) == y:
			return true
	return false


func _pos_of(x: float, y: float) -> Vector2:
	return _origin + Vector2((x + 0.5) * _cw, (y + 0.5) * _ch)


func _draw_dynamic() -> void:
	var font := ThemeDB.fallback_font
	var t: float = _frame.t
	# Geräuschwellen: wachsende Ringe, die schnell verblassen
	for n in _noise:
		var age: float = t - float(n.t)
		if age < 0.0 or age > 2.5:
			continue
		var r := _cell * (0.6 + age * 3.0)
		var a := 0.5 * (1.0 - age / 2.5)
		draw_arc(_pos_of(n.x, n.y), r, 0, TAU, 40, Color(0.95, 0.95, 1.0, a), 2.0)
	# Wachen mit Sichtkegel, Verdachtsring und Sichtlinien
	for g in target.guards:
		var data: Array = _frame.guards.get(g.id, [])
		if data.is_empty() or data[2] == "IDLE" or intel < 1:
			continue
		var gp := _pos_of(data[0], data[1])
		var st: String = data[2]
		var col: Color = STATE_COL.get(st, Color.WHITE)
		var facing := Vector2(data[5], data[6]) if data.size() > 6 else Vector2(1, 0)
		var cone := _cone(Vector2(data[0], data[1]), facing, float(g.vision))
		draw_colored_polygon(cone, Color(col, 0.16))
		var outline := cone.duplicate()
		outline.append(cone[0])
		draw_polyline(outline, Color(col, 0.7), 1.5)
		var susp := clampf(float(data[3]) / 100.0, 0.0, 1.0)
		if susp > 0.0:
			draw_arc(gp, _cell * 0.62, -PI * 0.5, -PI * 0.5 + TAU * susp, 36, col, 3.0)
		draw_circle(gp + Vector2(1, 2), _cell * 0.4, Color(0, 0, 0, 0.35))
		draw_circle(gp, _cell * 0.4, Color(0.12, 0.12, 0.16))
		draw_arc(gp, _cell * 0.4, 0, TAU, 24, col, 2.0)
		draw_circle(gp, _cell * 0.2, col)
		var label: String = _state_label(st)
		var fs := maxi(9, int(_cell * 0.36))
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_rect(Rect2(gp + Vector2(-sz.x * 0.5 - 3, _cell * 0.5), Vector2(sz.x + 6, fs + 4)), Color(0.05, 0.05, 0.08, 0.8))
		draw_string(font, gp + Vector2(-sz.x * 0.5, _cell * 0.5 + fs + 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Personen: Sichtlinie, wenn gesehen; Farbring bei Entdeckung
	for i in range(team.size()):
		var c: Dictionary = team[i]
		var cdata: Array = _frame.crew.get(c.id, [])
		if cdata.is_empty():
			continue
		var cp := _pos_of(cdata[0], cdata[1])
		var seen: bool = cdata[2]
		for g in target.guards:
			var gd: Array = _frame.guards.get(g.id, [])
			if gd.is_empty() or not gd[4] or gd[2] == "IDLE" or intel < 1:
				continue
			_dashed(_pos_of(gd[0], gd[1]), cp, Color(1.0, 0.85, 0.2, 0.9), 1.5)
		var col2: Color = COLORS.get(c.id, Color.WHITE)
		if c.id == selected_id:
			draw_arc(cp, _cell * 0.6, 0, TAU, 24, Color(0.98, 0.85, 0.35), 3.0)
		if seen:
			draw_arc(cp, _cell * 0.66, 0, TAU, 24, Color(1.0, 0.3, 0.3), 2.5)
		_draw_walker(cp, col2, String(c.name).substr(0, 1), cdata, "crew_%s" % c.id)
		_number_badge(cp, i + 1, col2)
		var carried: int = cdata[3]
		if carried > 0:
			draw_circle(cp + Vector2(_cell * 0.35, -_cell * 0.35), _cell * 0.2, GOLD)
			_text_center(cp + Vector2(_cell * 0.35, -_cell * 0.35), str(carried), Color(0.1, 0.08, 0.05), _cell * 0.26)
	_draw_floors()
	_draw_dim_floors()
	# Alarmzustand: roter Rahmen und Countdown
	if _frame.get("alarm", false):
		var frame := Rect2(_origin, Vector2(String(target.map[0]).length() * _cw, target.map.size() * _ch))
		draw_rect(frame, Color(1.0, 0.25, 0.25, 0.7), false, 3.0)
		var cd: float = _frame.get("cd", -1.0)
		if cd >= 0.0:
			var txt := "Polizei in %d s" % int(ceil(cd))
			draw_rect(Rect2(frame.position + Vector2(6, 6), Vector2(150, 22)), Color(0.35, 0.05, 0.05, 0.9))
			draw_string(font, frame.position + Vector2(12, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.8))


func _get_tooltip(at_position: Vector2) -> String:
	## Beim Darüberfahren: zuerst ein Haltepunkt oder eine Objekt-Aktion im Plan, sonst die Zelle.
	if target.is_empty():
		return ""
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
					ps.append("%s %d €" % [pt[0], int(pt[1])])
				parts_txt = " (%s)" % ", ".join(ps)
			var state := str(_frame.get("loot", {}).get(l.id, "ROOM")) if not _frame.is_empty() else "ROOM"
			var status := "" if state == "ROOM" else " – genommen"
			var loot_txt := "Beute: %s – %d €%s, Gewicht %.1f kg%s" % [Texte.d(l.name), int(l.value), parts_txt, float(l.weight), status]
			return loot_txt if wp_txt == "" else loot_txt + "\n" + wp_txt
	if wp_txt != "":
		return wp_txt
	if intel >= 1:
		for g in target.guards:
			if Sim._v2i(g.start) == cell:
				return Texte.t("gridv.sicht") % [g.name, int(g.vision), int(g.hearing)]
	for d in target.doors:
		if Sim._v2i(d.pos) == cell:
			return "%s – verschlossen (Dietrich, Brecheisen oder Bypass)" % Texte.d(d.name)
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
					return Texte.d(room.name).capitalize()
			return Texte.t("gridv.raum")


func _blocks(c: Vector2i) -> bool:
	## Was den Blick stoppt: Wand, Fenster, geschlossene Tür, Kartenrand.
	var rows: Array = target.map
	if c.y < 0 or c.y >= rows.size():
		return true
	var row: String = rows[c.y]
	if c.x < 0 or c.x >= row.length():
		return true
	var t := row.substr(c.x, 1)
	if t == "W":
		return true
	if t == "D" or t == "F":
		return not _is_open(c.x, c.y)
	return false


func _cone(origin: Vector2, facing: Vector2, vis: float) -> PackedVector2Array:
	## Sichtkegel in Blickrichtung. Jeder Strahl endet an der ersten Sperre,
	## so zeigt die Zeichnung denselben Bereich wie die Simulation.
	var pts := PackedVector2Array()
	pts.append(_pos_of(origin.x, origin.y))
	var dir0 := facing if facing.length() > 0.001 else Vector2(1, 0)
	var base := dir0.angle()
	var half := deg_to_rad(55.0)
	var n := 48
	for i in range(n + 1):
		var a := base - half + (2.0 * half) * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var end := origin
		var d := 0.0
		while d <= vis:
			var p := origin + dir * d
			if _blocks(Vector2i(roundi(p.x), roundi(p.y))):
				break
			end = p
			d += 0.08
		pts.append(_pos_of(end.x, end.y))
	return pts

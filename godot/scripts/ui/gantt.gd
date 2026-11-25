class_name Gantt
extends Control
## Zeitleiste des Einbruchs: je Person eine Zeile mit abgerundeten Balken.
## Zeigt Abspielmarke, Alarmzeitpunkt und die Polizei-Phase. Klick setzt die Zeit.

signal seek(t: float)
signal dropped(crew_id: String, kind: String)
signal bar_clicked(crew_id: String, index: int)

const ROW_H := 18.0
const LOUD_STD := 5.0  # Grundlautstärke einer Person (dB): darüber zeigt der Balken den Lärm
var text_size := 11  # Schriftgröße der Zeitleiste (vom Planer über A−/A+ gesteuert)
const LABEL_W_BASE := 132.0  # Breite der Namensspalte bei Standardschrift


## Breite der Namensspalte: wächst mit der Schrift, damit die Namen nicht abgeschnitten werden.
func _label_w() -> float:
	return LABEL_W_BASE * maxf(1.0, float(text_size) / 11.0)
const RULER_H := 20.0
const PAD := 8.0
const COL := {
	"MOVE": Color(0.96, 0.78, 0.38),
	"TOOL": Color(0.4, 0.68, 1.0),
	"TAKE": Color(1.0, 0.62, 0.32),
	"WAIT": Color(0.6, 0.66, 0.78),
	"CALL_CAR": Color(0.74, 0.56, 1.0),
	"FLAG_SET": Color(0.36, 0.9, 0.56),
	"FLAG_WAIT": Color(0.36, 0.9, 0.56),
}
const ALARM := Color(1.0, 0.35, 0.3)

var segments: Dictionary = {}   # crew id -> Array of {i, t, start, end}
var labels: Dictionary = {}     # crew id -> Array of Strings (Beschriftung je Aktion)
var crew: Array = []            # [{id, name, color}]
var max_time := 900.0
var alarm_time := -1.0
var playhead := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(560, RULER_H + ROW_H * 3 + PAD)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(p_segments: Dictionary, p_labels: Dictionary, p_crew: Array, p_max: float, p_alarm: float) -> void:
	segments = p_segments
	labels = p_labels
	crew = p_crew
	max_time = maxf(p_max, 60.0)
	alarm_time = p_alarm
	custom_minimum_size = Vector2(560, RULER_H + ROW_H * maxi(crew.size(), 4) + PAD)  # Platz für mindestens 4 Personen
	queue_redraw()



## Zeilenhöhe: füllt die verfügbare Höhe, mindestens ROW_H (Platz für 4 Personen ist immer da).
func _rh() -> float:
	return clampf((size.y - RULER_H - PAD) / float(maxi(crew.size(), 4)), ROW_H, 44.0)


func set_playhead(t: float) -> void:
	playhead = clampf(t, 0.0, max_time)
	queue_redraw()


func _track_w() -> float:
	return maxf(size.x - _label_w() - PAD, 10.0)


func _x(t: float) -> float:
	return _label_w() + clampf(t / max_time, 0.0, 1.0) * _track_w()


func _row_at(p: Vector2) -> int:
	var i := int((p.y - RULER_H) / _rh())
	if i < 0 or i >= crew.size():
		return -1
	return i


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x < _label_w():
			return
		# Auf einem Balken: Aktion bearbeiten
		var i := _row_at(event.position)
		var tt: float = (event.position.x - _label_w()) / _track_w() * max_time
		if i >= 0:
			var c: Dictionary = crew[i]
			for sg in segments.get(c.id, []):
				if tt >= float(sg.start) and tt <= float(sg.end):
					bar_clicked.emit(c.id, int(sg.i))
					return
		seek.emit(clampf(tt, 0.0, max_time))


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "aktion" and _row_at(at_position) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var i := _row_at(at_position)
	if i >= 0:
		dropped.emit(crew[i].id, data.kind)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var top := RULER_H
	var bottom := top + _rh() * maxi(crew.size(), 1)
	# Hintergrund der Spur
	draw_rect(Rect2(_label_w(), top, _track_w(), bottom - top), Color(0.05, 0.08, 0.14, 0.9))

	# Polizei-Phase nach dem Alarm
	if alarm_time >= 0.0:
		var x0 := _x(alarm_time)
		draw_rect(Rect2(x0, top, size.x - x0, bottom - top), Color(ALARM, 0.07))
		var pattern := Color(ALARM, 0.25)
		var x := x0
		while x < size.x:
			draw_line(Vector2(x, top), Vector2(x + 6, bottom), pattern, 1.0)
			x += 10.0

	# Zeitlineal: Sekundenstriche, Minutenbeschriftung
	var t: float = 0.0
	while t <= max_time + 0.1:
		var x2 := _x(t)
		var major := int(t) % 120 == 0
		var h := 8.0 if major else 4.0
		draw_line(Vector2(x2, top - h), Vector2(x2, top), Color(0.6, 0.66, 0.78, 0.8 if major else 0.4), 1.0)
		if major:
			draw_line(Vector2(x2, top), Vector2(x2, bottom), Color(1, 1, 1, 0.06), 1.0)
			draw_string(font, Vector2(x2 + 3, top - 9), Sim.clock(t), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(0.7, 0.75, 0.84))
		t += 30.0

	# Zeilen
	for i in range(crew.size()):
		var c: Dictionary = crew[i]
		var y := top + i * _rh()
		if i > 0:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.05), 1.0)
		draw_circle(Vector2(14, y + _rh() * 0.5), 6.0, c.color)
		draw_circle(Vector2(14, y + _rh() * 0.5), 6.0, Color(0, 0, 0, 0.3), false, 1.5)
		draw_string(font, Vector2(28, y + _rh() * 0.5 + 4), c.name, HORIZONTAL_ALIGNMENT_LEFT, _label_w() - 34, text_size + 1, Color(0.94, 0.92, 0.88))
		# Grundlinie für Leerlauf
		draw_line(Vector2(_label_w(), y + _rh() * 0.5), Vector2(size.x - PAD, y + _rh() * 0.5), Color(1, 1, 1, 0.07), 1.0)
		var segs: Array = segments.get(c.id, [])
		var labs: Array = labels.get(c.id, [])
		for s in segs:
			var x1 := _x(float(s.start))
			var x2b := _x(float(s.end))
			var w := maxf(x2b - x1, 3.0)
			var col: Color = COL.get(s.t, Color.GRAY)
			var r := Rect2(x1 + 0.5, y + 5, w - 1.0, _rh() - 10)
			_bar(r, col)
			# Lautstärke des Schrittes: kleines Schild oben links am Balken (auch bei kurzen Balken sichtbar)
			var db_b := float(s.get("loud", 0.0))
			if db_b > LOUD_STD + 0.5:
				var tag := "%d dB" % int(db_b)
				var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				draw_rect(Rect2(x1 + 3, y + 1, tw + 8, 12), Color(0.85, 0.2, 0.15, 0.95))
				draw_string(font, Vector2(x1 + 7, y + 10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))
			var label: String = labs[int(s.i)] if int(s.i) < labs.size() else ""
			if w > 46.0 and label != "":
				var txt := label
				var maxw := w - 12.0
				while txt.length() > 3 and font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > maxw:
					txt = txt.substr(0, txt.length() - 2) + "…"
				draw_string(font, Vector2(x1 + 6, y + _rh() * 0.5 + 4), txt, HORIZONTAL_ALIGNMENT_LEFT, maxw, text_size, Color(0.08, 0.07, 0.1))

	# Alarmmarke
	if alarm_time >= 0.0:
		var ax := _x(alarm_time)
		draw_line(Vector2(ax, top - 2), Vector2(ax, bottom + 2), ALARM, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(ax, bottom + 2), Vector2(ax - 5, bottom + 9), Vector2(ax + 5, bottom + 9)]), ALARM)
		draw_string(font, Vector2(ax + 4, bottom + 9), "Alarm %s" % Sim.clock(alarm_time), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ALARM)

	# Abspielmarke
	var px := _x(playhead)
	draw_line(Vector2(px, 2), Vector2(px, bottom + 2), Color(1, 1, 1, 0.9), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(px - 6, 0), Vector2(px + 6, 0), Vector2(px, 8)]), Color(1, 1, 1, 0.95))
	var tl := Sim.clock(playhead)
	var tw := font.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_rect(Rect2(px - tw * 0.5 - 4, bottom + 10, tw + 8, 15), Color(0.95, 0.95, 0.97))
	draw_string(font, Vector2(px - tw * 0.5, bottom + 22), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(0.05, 0.06, 0.1))


func _bar(r: Rect2, col: Color) -> void:
	## Abgerundeter Balken mit Glanzkante.
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = col.lightened(0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 1)
	draw_style_box(sb, r)
	draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(maxf(r.size.x - 6, 0), 3)), Color(1, 1, 1, 0.22))


func _get_tooltip(at_position: Vector2) -> String:
	## Beim Darüberfahren: Person, Aktion und Zeitraum.
	var i := int((at_position.y - RULER_H) / _rh())
	if i < 0 or i >= crew.size() or at_position.x < _label_w():
		return ""
	var c: Dictionary = crew[i]
	var t := (at_position.x - _label_w()) / _track_w() * max_time
	var labs: Array = labels.get(c.id, [])
	for s in segments.get(c.id, []):
		if t >= float(s.start) and t <= float(s.end):
			var lab: String = labs[int(s.i)] if int(s.i) < labs.size() else String(s.t)
			var db := float(s.get("loud", 0.0))
			var extra := "\n" + Texte.t("gantt.laerm") % int(db) if db > LOUD_STD + 0.5 else ""
			return "%s: %s\n%s – %s%s" % [c.name, lab, Sim.clock(float(s.start)), Sim.clock(float(s.end)), extra]
	return ""

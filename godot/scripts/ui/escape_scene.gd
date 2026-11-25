class_name EscapeScene
extends Control
## 2D-Szene nach dem Einbruch: Der Fluchtwagen fährt davon, die Polizei folgt mit Blaulicht.
## Bei Festnahme holt die Polizei den Wagen ein. Eigene Zeichnung, keine Vorlage.

signal done

const DUR := 4.5
var status := "ENTKOMMEN"
var alarm := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DUR:
		set_process(false)
		done.emit()


func _car_x(w: float) -> float:
	var k := clampf(_t / DUR, 0.0, 1.0)
	if status == "GEFASST":
		# Der Wagen bremst und wird in der Mitte gestellt
		return lerpf(w * 0.2, w * 0.5, k)
	return lerpf(w * 0.2, w * 1.2, k)


func _police_x(w: float, car_x: float) -> float:
	if status == "GEFASST":
		return car_x - 6.0 + 18.0 * clampf(_t / DUR, 0.0, 1.0)
	return car_x - 260.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Nachtstraße
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.04, 0.07, 0.92))
	draw_rect(Rect2(0, h * 0.55, w, h * 0.3), Color(0.2, 0.21, 0.25))
	draw_rect(Rect2(0, h * 0.55, w, 3), Color(0.5, 0.45, 0.3, 0.5))
	for i in range(14):
		var x := fmod(float(i) * 110.0 - _t * 260.0, w + 110.0) - 55.0
		draw_rect(Rect2(x, h * 0.7, 56, 4), Color(0.9, 0.85, 0.5, 0.6))
	var cx := _car_x(w)
	var y := h * 0.66
	# Fluchtwagen
	draw_rect(Rect2(cx - 46, y - 22, 92, 26), Color(0.62, 0.16, 0.14))
	draw_rect(Rect2(cx - 24, y - 36, 48, 16), Color(0.5, 0.12, 0.1))
	draw_rect(Rect2(cx - 18, y - 32, 36, 12), Color(0.35, 0.5, 0.62))
	draw_circle(Vector2(cx + 46, y - 12), 3.5, Color(1, 1, 0.8))
	draw_circle(Vector2(cx - 40, y + 6), 8, Color(0.02, 0.02, 0.02))
	draw_circle(Vector2(cx + 30, y + 6), 8, Color(0.02, 0.02, 0.02))
	# Polizei mit Blaulicht
	if alarm or status == "GEFASST":
		var px := _police_x(w, cx)
		draw_rect(Rect2(px - 44, y - 20, 88, 24), Color(0.92, 0.92, 0.95))
		draw_rect(Rect2(px - 40, y - 12, 80, 6), Color(0.15, 0.3, 0.8))
		var flash := 0.5 + 0.5 * sin(_t * 18.0)
		draw_circle(Vector2(px - 8, y - 26), 6, Color(1.0, 0.2, 0.2, 0.4 + 0.6 * flash))
		draw_circle(Vector2(px + 8, y - 26), 6, Color(0.3, 0.5, 1.0, 0.4 + 0.6 * (1.0 - flash)))
		draw_circle(Vector2(px - 30, y + 6), 8, Color(0.02, 0.02, 0.02))
		draw_circle(Vector2(px + 26, y + 6), 8, Color(0.02, 0.02, 0.02))
	var txt := "Flucht gelungen" if status != "GEFASST" else "Die Polizei holt den Wagen ein"
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	draw_string(font, Vector2(w * 0.5 - sz.x * 0.5, h * 0.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.97, 0.85, 0.5))

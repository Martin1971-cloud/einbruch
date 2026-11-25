class_name BuildingArt
extends Control
## Fassadenbild des Gebäudes. Liest Fenster (F) und Tür (D) direkt aus der
## Westwand des Grundrisses, damit Bild und Planung immer übereinstimmen.

var map: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(0, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Westwand (Spalte links neben dem Gebäude) auslesen: Zeile -> Zeichen.
func _west_wall() -> Array:
	var out: Array = []
	if map.is_empty():
		return out
	for y in range(map.size()):
		var row: String = map[y]
		var t := row.substr(2, 1)
		if t == "F" or t == "D":
			out.append({"y": y, "t": t})
	return out


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Nachthimmel mit Verlauf
	for i in range(12):
		var t := float(i) / 12.0
		draw_rect(Rect2(0, h * t, w, h / 12.0 + 1), Color(0.05 + 0.08 * (1 - t), 0.08 + 0.1 * (1 - t), 0.18 + 0.14 * (1 - t)))
	draw_circle(Vector2(w * 0.84, h * 0.2), 12.0, Color(0.95, 0.95, 0.85, 0.9))
	draw_circle(Vector2(w * 0.84, h * 0.2), 22.0, Color(0.95, 0.95, 0.85, 0.12))
	# Fassade
	var base_y := h * 0.82
	var x0 := w * 0.12
	var x1 := w * 0.88
	draw_rect(Rect2(x0, h * 0.42, x1 - x0, base_y - h * 0.42), Color(0.9, 0.84, 0.7))
	draw_colored_polygon(PackedVector2Array([Vector2(x0 - 6, h * 0.42), Vector2((x0 + x1) * 0.5, h * 0.2), Vector2(x1 + 6, h * 0.42)]), Color(0.82, 0.76, 0.62))
	draw_rect(Rect2(x0 - 6, base_y, x1 - x0 + 12, 6), Color(0.7, 0.64, 0.52))
	for i in range(5):
		var cx := x0 + (x1 - x0) * (0.12 + i * 0.19)
		draw_rect(Rect2(cx - 3, h * 0.45, 6, base_y - h * 0.45), Color(0.97, 0.93, 0.84))

	# Fenster und Tür aus dem Grundriss. Die Tür liegt in der Mitte der Fassade,
	# Fenster oberhalb der Tür links der Mitte, unterhalb rechts (gleiche Reihenfolge wie im Grundriss).
	var wall := _west_wall()
	var door_y := -1
	for e in wall:
		if e.t == "D":
			door_y = int(e.y)
	var windows: Array = []
	for e in wall:
		if e.t == "F":
			windows.append(int(e.y))
	var left: Array = []
	var right: Array = []
	for wy in windows:
		if door_y >= 0 and wy > door_y:
			right.append(wy)
		else:
			left.append(wy)
	var mid := w * 0.5
	var span := (mid - x0) * 0.82
	for i in range(left.size()):
		var fx := mid - span * (0.25 + 0.75 * float(i) / maxf(left.size() - 1, 1))
		_window(fx, h)
	for i in range(right.size()):
		var fx2 := mid + span * (0.25 + 0.75 * float(i) / maxf(right.size() - 1, 1))
		_window(fx2, h)
	# Tür
	draw_rect(Rect2(mid - 9, base_y - 20, 18, 20), Color(0.42, 0.28, 0.16))
	draw_rect(Rect2(mid - 11, base_y - 24, 22, 4), Color(0.98, 0.8, 0.35))
	# Bodenlicht
	draw_rect(Rect2(0, base_y + 6, w, h - base_y - 6), Color(0.07, 0.14, 0.12))


func _window(fx: float, h: float) -> void:
	var fy := h * 0.5
	draw_rect(Rect2(fx - 7, fy, 14, 22), Color(1.0, 0.82, 0.45))
	draw_rect(Rect2(fx - 7, fy, 14, 22), Color(0.3, 0.25, 0.2, 0.6), false, 1.0)
	draw_line(Vector2(fx, fy), Vector2(fx, fy + 22), Color(0.3, 0.25, 0.2, 0.6), 1.0)

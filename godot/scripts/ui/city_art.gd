class_name CityArt
extends Control
## Nächtliche Stadtsilhouette für den Titelbildschirm. Eigene Zeichnung.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Himmel mit Verlauf und Mond
	for i in range(24):
		var t := float(i) / 24.0
		draw_rect(Rect2(0, h * t, w, h / 24.0 + 1), Color(0.03 + 0.08 * (1 - t), 0.05 + 0.1 * (1 - t), 0.12 + 0.16 * (1 - t)))
	draw_circle(Vector2(w * 0.78, h * 0.22), 46.0, Color(0.95, 0.94, 0.85, 0.12))
	draw_circle(Vector2(w * 0.78, h * 0.22), 26.0, Color(0.96, 0.95, 0.88))
	# Ferne Stadt: Türme und Kuppeln, hinten dunkler
	var base_y := h * 0.78
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for layer in range(2):
		var col := Color(0.06 + 0.04 * layer, 0.08 + 0.05 * layer, 0.14 + 0.05 * layer)
		var x := 0.0
		while x < w:
			var bw := rng.randf_range(w * 0.03, w * 0.07)
			var bh := rng.randf_range(h * 0.1, h * 0.25) * (1.0 - 0.3 * layer)
			draw_rect(Rect2(x, base_y - bh, bw, bh + h * 0.3), col)
			if rng.randf() < 0.3:
				draw_circle(Vector2(x + bw * 0.5, base_y - bh), bw * 0.4, col)
			x += bw * 0.9
		base_y += h * 0.04
	# Erleuchtete Fenster
	rng.seed = 11
	for i in range(int(w * 0.25)):
		var fx := rng.randf() * w
		var fy := h * (0.55 + rng.randf() * 0.25)
		draw_rect(Rect2(fx, fy, 2, 3), Color(1.0, 0.82, 0.45, 0.5 + 0.4 * rng.randf()))
	# Vordergrund: Straße und Gegenlicht
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), Color(0.04, 0.05, 0.07))
	draw_rect(Rect2(0, h * 0.88, w, 2), Color(0.9, 0.7, 0.35, 0.25))

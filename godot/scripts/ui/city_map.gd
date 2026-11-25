class_name CityMap
extends Control
## Stadtplan Königsbrück: das Stadtbild als Hintergrund, Ortsmarken mit den Namen aus dem Spiel.
## Die Positionen der Marken (0..1) beziehen sich auf das Bild, nicht auf das Fenster.

signal picked(id: String)

const MAP_PATH := "res://assets/map/koenigsbrueck.webp"
const IMG_RATIO := 1672.0 / 941.0

static var _tex: Texture2D

var pins: Array = []   # [{id, name, pos: Vector2 (0..1 des Bildes), active}]
var selected := ""
var _hover := ""   # id der Ortsmarke unter dem Mauszeiger
var _zoom := 1.0           # 1.0 = eingepasst, bis MAX_ZOOM
var _off := Vector2.ZERO   # Verschiebung des Bildes gegenüber dem eingepassten Bereich
var _drag_from := Vector2.ZERO
var _dragging := false
const MAX_ZOOM := 4.0


func _init() -> void:
	custom_minimum_size = Vector2(300, 240)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_pins(p: Array, sel: String) -> void:
	pins = p
	selected = sel
	queue_redraw()


## Bildbereich im Fenster: Seitenverhältnis bleibt, das Bild wird zentriert eingepasst.
func _fit_rect() -> Rect2:
	var w := size.x
	var h := size.x / IMG_RATIO
	if h > size.y:
		h = size.y
		w = size.y * IMG_RATIO
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


## Bildbereich im Fenster mit Zoom und Verschiebung.
func _img_rect() -> Rect2:
	var f := _fit_rect()
	return Rect2(f.position + _off, f.size * _zoom)


## Hält das Bild im Fenster: kleiner als das Fenster wird es zentriert, größer bleibt es am Rand.
func _clamp_off() -> void:
	var f := _fit_rect()
	var w := f.size.x * _zoom
	var h := f.size.y * _zoom
	var x: float = (size.x - w) * 0.5 - f.position.x if w <= size.x else clampf(f.position.x + _off.x, size.x - w, 0.0) - f.position.x
	var y: float = (size.y - h) * 0.5 - f.position.y if h <= size.y else clampf(f.position.y + _off.y, size.y - h, 0.0) - f.position.y
	_off = Vector2(x, y)


## Zoomt um den Punkt „at“, damit der Ort unter dem Mauszeiger stehen bleibt.
func _zoom_at(at: Vector2, factor: float) -> void:
	var old := _img_rect()
	var new_zoom := clampf(_zoom * factor, 1.0, MAX_ZOOM)
	if is_equal_approx(new_zoom, _zoom):
		return
	var u := (at - old.position) / old.size
	_zoom = new_zoom
	var f := _fit_rect()
	var new_size := f.size * _zoom
	_off = (at - u * new_size) - f.position
	_clamp_off()
	queue_redraw()


func _reset_view() -> void:
	_zoom = 1.0
	_off = Vector2.ZERO
	queue_redraw()


func _px(v: Vector2) -> Vector2:
	var r := _img_rect()
	return r.position + Vector2(v.x * r.size.x, v.y * r.size.y)


func _texture() -> Texture2D:
	if _tex == null:
		# Über den Import laden (funktioniert auch im Export); Datei-Laden nur als Rückfall
		if ResourceLoader.exists(MAP_PATH):
			_tex = load(MAP_PATH)
		else:
			var img := Image.load_from_file(MAP_PATH)
			if img != null:
				_tex = ImageTexture.create_from_image(img)
	return _tex


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09))
	var r := _img_rect()
	var tex := _texture()
	if tex != null:
		draw_texture_rect(tex, r, false)
	# Ortsmarken
	for p in pins:
		var c := _px(p.pos)
		var is_sel: bool = p.id == selected
		var col := Color(0.97, 0.8, 0.35) if p.active else Color(0.6, 0.6, 0.65)
		if is_sel:
			draw_circle(c, 14, Color(1, 0.9, 0.5, 0.35))
		draw_circle(c, 7, col)
		draw_circle(c, 7, Color(0.1, 0.08, 0.05), false, 1.5)
		var sz := font.get_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_rect(Rect2(c + Vector2(-sz.x * 0.5 - 4, 10), Vector2(sz.x + 8, 17)), Color(0.05, 0.06, 0.09, 0.85))
		draw_string(font, c + Vector2(-sz.x * 0.5, 23), p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	# Hinweis beim Darüberfahren: Name, und ob der Ort auswählbar ist
	for p in pins:
		if p.id != _hover:
			continue
		var c := _px(p.pos)
		var lines: Array = [p.name, "" if p.active else Texte.t("stadt.nicht_waehlbar")]
		var fs := 13
		var w := 0.0
		for ln in lines:
			w = maxf(w, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var box := Rect2(c + Vector2(-w * 0.5 - 8, -62), Vector2(w + 16, 44))
		box.position.x = clampf(box.position.x, 4, size.x - box.size.x - 4)
		box.position.y = maxf(4, box.position.y)
		draw_rect(box, Color(0.05, 0.06, 0.09, 0.93))
		draw_rect(box, Color(0.89, 0.71, 0.35), false, 1.0)
		draw_string(font, box.position + Vector2(8, 18), p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.85, 0.55))
		if not p.active:
			draw_string(font, box.position + Vector2(8, 36), Texte.t("stadt.nicht_waehlbar"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.6, 0.5))
		break


func _get_tooltip(at_position: Vector2) -> String:
	for p in pins:
		if _px(p.pos).distance_to(at_position) < 18:
			var info: String = p.get("info", "")
			return p.name + ("" if p.active else Texte.t("stadt.nicht_spielbar")) + ("\n" + info if info != "" else "")
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hover = ""
		queue_redraw()


func _pin_at(pos: Vector2) -> String:
	for p in pins:
		if _px(p.pos).distance_to(pos) < 18:
			return p.id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.25)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 0.8)
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_reset_view()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			_reset_view()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_drag_from = event.position
			_dragging = false
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _dragging:
				_dragging = false
				return
			for p in pins:
				if _px(p.pos).distance_to(event.position) < 18:
					if p.active:
						picked.emit(p.id)
					return
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and _zoom > 1.0:
			if _dragging or event.position.distance_to(_drag_from) > 4.0:
				_dragging = true
				_off += event.relative
				_clamp_off()
				queue_redraw()
			return
		var hid := _pin_at(event.position)
		if hid != _hover:
			_hover = hid
			queue_redraw()
		return

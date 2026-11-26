class_name EscapeScene
extends Control
## 2D-Szene nach dem Einbruch: Der Fluchtwagen fährt davon, die Polizei folgt mit Blaulicht.
## Bei Festnahme holt die Polizei den Wagen ein. Seitenansicht je Fahrzeug (GameData.SEITE_BILD);
## fehlt eine Datei, wird die einfache Zeichnung benutzt. Die Polizei wird zufällig gewählt.

signal done

const DUR := 4.5
## Höhe aller Fahrzeuge in der Szene, als Anteil an der Szenenhöhe. Die Seitenbilder sind auf gleiche Karosseriehöhe normiert.
const FAHRZEUG_HOEHE := 0.26
## Vollflächiger Hintergrund: Straße mit Häusern. Fehlt die Datei, bleibt die gezeichnete Nachtstraße.
const BG_BILD := "res://assets/art/escape_strasse.webp"
var status := "ENTKOMMEN"
var alarm := false
## Verfolgungsergebnis aus der Simulation: "KNAPP" zeigt eine kurze Verfolgung mit dicht folgender Polizei.
var chase := ""
## Gewähltes Fluchtfahrzeug (Schlüssel aus GameData.CARS).
var car_id := "limo"
var _t := 0.0
var _car_tex: Texture2D
var _police_tex: Texture2D
var _bg_tex: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_car_tex = _lade(str(GameData.SEITE_BILD.get(car_id, "")))
	_police_tex = _lade(GameData.POLIZEI_SEITE[randi() % GameData.POLIZEI_SEITE.size()])
	_bg_tex = _lade(BG_BILD)


func _lade(pfad: String) -> Texture2D:
	if pfad == "" or not ResourceLoader.exists(pfad):
		return null
	return load(pfad) as Texture2D


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
	# Abstände in Vielfachen der Szenenhöhe, damit sie zur Fahrzeuggröße passen (ein Fahrzeug ist knapp 0,75 h lang)
	var h := size.y
	if status == "GEFASST":
		return car_x - 0.02 * h + 0.2 * h * clampf(_t / DUR, 0.0, 1.0)
	if chase == "KNAPP":
		# Knapp: die Polizei holt auf, bleibt aber hinter dem Wagen (fast Stoßstange an Stoßstange)
		return car_x - lerpf(1.1 * h, 0.78 * h, clampf(_t / DUR, 0.0, 1.0))
	return car_x - 1.1 * h


## Fahrzeugbild mit Mitte x und Unterkante y; alle Fahrzeuge haben die gleiche Höhe, die Breite ergibt sich daraus.
func _bild(tex: Texture2D, x: float, y: float, hoehe: float) -> void:
	var breite := hoehe * float(tex.get_width()) / float(tex.get_height())
	draw_texture_rect(tex, Rect2(x - breite * 0.5, y - hoehe, breite, hoehe), false)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := _car_x(w)
	var y := h * 0.66
	if _bg_tex != null:
		# Bild füllt die ganze Fläche (Mitte ausgeschnitten), Fahrzeuge fahren auf der Straße im Bild
		var skal := maxf(w / float(_bg_tex.get_width()), h / float(_bg_tex.get_height()))
		var bw := _bg_tex.get_width() * skal
		var bh := _bg_tex.get_height() * skal
		draw_texture_rect(_bg_tex, Rect2((w - bw) * 0.5, (h - bh) * 0.5, bw, bh), false)
		y = h * 0.86
	else:
		# Nachtstraße
		draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.04, 0.07, 0.92))
		draw_rect(Rect2(0, h * 0.55, w, h * 0.3), Color(0.2, 0.21, 0.25))
		draw_rect(Rect2(0, h * 0.55, w, 3), Color(0.5, 0.45, 0.3, 0.5))
		for i in range(14):
			var x := fmod(float(i) * 110.0 - _t * 260.0, w + 110.0) - 55.0
			draw_rect(Rect2(x, h * 0.7, 56, 4), Color(0.9, 0.85, 0.5, 0.6))
	# Fluchtwagen
	if _car_tex != null:
		_bild(_car_tex, cx, y + 10.0, h * FAHRZEUG_HOEHE)
	else:
		draw_rect(Rect2(cx - 46, y - 22, 92, 26), Color(0.62, 0.16, 0.14))
		draw_rect(Rect2(cx - 24, y - 36, 48, 16), Color(0.5, 0.12, 0.1))
		draw_rect(Rect2(cx - 18, y - 32, 36, 12), Color(0.35, 0.5, 0.62))
		draw_circle(Vector2(cx + 46, y - 12), 3.5, Color(1, 1, 0.8))
		draw_circle(Vector2(cx - 40, y + 6), 8, Color(0.02, 0.02, 0.02))
		draw_circle(Vector2(cx + 30, y + 6), 8, Color(0.02, 0.02, 0.02))
	# Polizei mit Blaulicht
	if alarm or status == "GEFASST" or chase == "KNAPP":
		var px := _police_x(w, cx)
		var flash := 0.5 + 0.5 * sin(_t * 18.0)
		if _police_tex != null:
			_bild(_police_tex, px, y + 10.0, h * FAHRZEUG_HOEHE)
		else:
			draw_rect(Rect2(px - 44, y - 20, 88, 24), Color(0.92, 0.92, 0.95))
			draw_rect(Rect2(px - 40, y - 12, 80, 6), Color(0.15, 0.3, 0.8))
			draw_circle(Vector2(px - 30, y + 6), 8, Color(0.02, 0.02, 0.02))
			draw_circle(Vector2(px + 26, y + 6), 8, Color(0.02, 0.02, 0.02))
		# Blaulicht blinkt auf dem Dach (bei Bildern: oberhalb des Fahrzeugbilds)
		var dach := y - h * FAHRZEUG_HOEHE + 14.0 if _police_tex != null else y - 26
		draw_circle(Vector2(px - 8, dach), 6, Color(1.0, 0.2, 0.2, 0.4 + 0.6 * flash))
		draw_circle(Vector2(px + 8, dach), 6, Color(0.3, 0.5, 1.0, 0.4 + 0.6 * (1.0 - flash)))
	var txt := Texte.t("escape.flucht_gelungen")
	if status == "GEFASST":
		txt = Texte.t("escape.polizei_holt")
	elif chase == "KNAPP":
		txt = Texte.t("escape.knapp")
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	# Dunkle Fläche hinter dem Text, damit er über dem Bild lesbar bleibt
	draw_rect(Rect2(w * 0.5 - sz.x * 0.5 - 14, h * 0.2 - sz.y, sz.x + 28, sz.y + 14), Color(0.02, 0.03, 0.05, 0.7))
	draw_string(font, Vector2(w * 0.5 - sz.x * 0.5, h * 0.2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.97, 0.85, 0.5))

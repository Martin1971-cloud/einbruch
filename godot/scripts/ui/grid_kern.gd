class_name GridKern
extends Control

signal cell_clicked(cell: Vector2i)
signal point_clicked(fine: Vector2i)   # genaue Stelle in Unterfeldern (vor cell_clicked)
signal person_clicked(id: String)  # Klick auf eine Person im Grundriss (wählt sie aus)

## Rasteransicht, Grundlage: Koordinaten, Ansicht und Zoom, Kacheln, Hilfen für Text und Symbole, Sicht.

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

const FLOOR_A := Color(0.88, 0.8, 0.66)

const PLANK := Color(0.72, 0.6, 0.45, 0.35)

const WALL_TOP := Color(0.46, 0.5, 0.62)

const WALL_SHADOW := Color(0.08, 0.09, 0.14)

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
	if target.points.has("fluchtwagen"):
		var ex := Sim._v2i(target.points["fluchtwagen"])
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

## Fluchtwagen als Limousine (4,6 × 1,8 m) außerhalb des Gebäudes, Front zum Haus (wie in 3D).
## Richtung vom Gebäude weg, in der der Wagen steht (wie in der 3D-Ansicht).
func _car_out(ex: Vector2i) -> Vector2:
	var w: float = float(target.map[0].length())
	var h: float = float(target.map.size())
	var out := Vector2(signf(float(ex.x) - w * 0.5), signf(float(ex.y) - h * 0.5))
	if absf(out.x) >= absf(out.y):
		return Vector2(out.x, 0.0)
	return Vector2(0.0, out.y)

## Mitte eines Unterfeldes auf dem Bildschirm.
func _fpos(f: Vector2i) -> Vector2:
	var sb := float(Sim.SUB)
	return _origin + Vector2((f.x + 0.5) * _cw / sb, (f.y + 0.5) * _ch / sb)

var _icons := {}

## Beuteicon aus der Tabelle (GameData.ITEMS), oder null.
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
	var name: String = String(GameData.ITEMS.get(lid, {}).get("icon", ""))
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

## Kachel in die Zelle legen. Ein Ausschnitt je Zelle, damit nicht alles gleich aussieht.
## Grundriss-Stil B (modern, flach): reine Flächen, dünne Linien, kühle Palette.
const FLAT := true

const FLAT_COL := {
	"parkett": Color(0.80, 0.84, 0.90),
	"mauer": Color(0.16, 0.20, 0.28),
	"rasen": Color(0.12, 0.17, 0.22),
	"fenster": Color(0.55, 0.78, 0.95),
}

## Etage der ausgewählten Person (Index) oder -1. Position aus der Vorschau, sonst vom Start.
var view_floor := -1  # Etage, die der Etagen-Knopf zeigt (-1 = Etage der ausgewählten Person)

func _active_floor_idx() -> int:
	if not target.has("floors"):
		return -1
	if view_floor >= 0:
		return view_floor
	if selected_id == "":
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

## Alarmanlage im Plan abgeschaltet? (Umgehen des Panels mit dem Elektroset)
func alarm_aus() -> bool:
	if not target.has("panel"):
		return false
	for pid in plans:
		for a in plans[pid]:
			if a.t == "TOOL" and a.get("tool", "") == "bypass" and a.get("on", "") == target.panel.id:
				return true
	return false

## Gesicherte Objekte als Zellen: Türen über den Namen, Vitrinen über die Beute-ID.
func _gesicherte_zellen() -> Array:
	var out: Array = []
	for g in target.get("gesichert", []):
		var name := str(g)
		var gefunden := false
		for d in target.get("doors", []):
			if str(d.id) == name:
				out.append({"name": d.name, "pos": _c(d.pos)})
				gefunden = true
		if not gefunden:
			for l in target.loot:
				if str(l.get("id", "")) == name:
					out.append({"name": name, "pos": _c(l.pos)})
	return out

## Figur als Bild aus assets/sprites: Blickrichtung (Vorn, Rücken, Seite), Gehzyklus bei Bewegung.
var _sprite_cache := {}

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

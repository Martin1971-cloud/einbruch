class_name SimKarte
extends RefCounted
## Grundlage der Simulation: Zustand, Karte, Wege, Sicht, Protokoll und Ergebnis.
## Keine Regeln für Wachen oder Aktionen; die stehen in den Unterklassen.

const DT := 0.1

const SNAP := 0.1            # Abstand der Momentaufnahmen für die Wiedergabe (Sekunden)

const TIMEOUT := 900.0

const WALK := 1.0            # Feld pro Sekunde

const SUB := 16              # Unterfelder je Feld und Richtung (Bewegung und Sicht in Unterfeldern)

const LOOT_TIME := 3.0

## Öffnen von Hand (Tür oder Vitrine, die schon entriegelt ist). Im Original: Tabelle "opens", Werkzeug Hand.
const OPEN_TIME := 3.0
const CLOSE_TIME := 1.5  # Tür wieder schließen (Dietrich oder Schlosstecher, nicht aufgebrochen)

const DECAY := 2.0

const SEE_RATE := 40.0

const WALL_DAMPING := 15.0

const DIST_DAMPING := 1.5

const PATROL_ALARM_BASE := 12.0

const INVESTIGATE_SEC := 8.0

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var map: Array = []

var fine_rows: Array = []   # Grundriss in Unterfeldern: Zeilen als Bytes (Zeichen je Unterfeld)

var fine_w := 0

var fine_h := 0

var use_fine := false

var w := 0

var h := 0

var time := 0.0

var status := "RUNNING"

var ended_reason := ""

var points := {}

var doors := {}        # Vector2i -> Dictionary

var open_cells := {}   # Vector2i -> true
var open_since := {}    # Vector2i -> Spielzeit, zu der die Tür geöffnet wurde (für die Schonfrist der Streife)

var panel := {}

var gesichert: Array = []  # Namen der Türen und IDs der Vitrinen, die die Anlage sichert

var stairs := {}   # Treppe: Feld (grob) -> Feld auf der anderen Etage

const STAIRS_TIME := 8.0  # Original: PLANING_TIME_USE_STAIRS

var sensors := []

var loot := {}         # id -> Dictionary

var loot_order := []

var guards := []

var crew := []

var car := {"called": false, "arrive_at": -1.0, "present": false, "eta": 20.0}

var departed := false

var countdown := -1.0

var chase := ""  # Ergebnis der Verfolgung: "" = keine Polizei unterwegs, sonst KNAPP, ENTKOMMEN oder GEFASST

var car_v := 100.0      # Fahrleistung des Wagens (km/h, mit Fahrer)

var karte := false              # Eintrittskarte vom Informanten vorhanden
var karte_tuer := ""             # gesicherte Tür, die die Karte ruhig öffnet (aus dem Ziel)
var patrol_mittel := 180.0       # mittlerer Abstand der Streife (Sekunden)
var hauptweg: Array = []         # Türen des Hauptwegs (Haupteingang, Schwachstelle)
var car_laderaum := "mittel"  # größte Beute, die in den Fluchtwagen passt: klein, mittel, gross

var police_v := 140.0   # Polizeitempo (km/h), abhängig von der Wachrate des Ziels

var escape_km := 10.0   # Fluchtstrecke in km

var alarm_active := false

var flags := {}

var log_lines: Array = []

## Strukturierte Ereignisse für die Auswertung: je Aktion einer Person und Alarm (Zeit, Person, Art, Objekt, Ergebnis).
var events: Array = []

var evidence := 0.0

var seen_sec := 0.0

var escape_cell := Vector2i.ZERO

var payout := 0

var target_name := ""

var frames: Array = []        # Momentaufnahme jede Sekunde (für die 2D-Wiedergabe)

var noise_log: Array = []     # Geräusche: {t, x, y, db}

var alarm_time := -1.0

# Lärm und Streifgänge (Original: player.c, PD.currLoudness / tcAlarmByLoudness / tcAlarmByPatrol)
const LOUD_STD := 5.0          # PLANING_LOUDNESS_STD: Grundlautstärke einer Person

const LOUD_CHECK := 5.0        # Original: alle 15 Ticks (5 s) prüfen



var police_base := 60.0        # Polizeizeit nach Alarm (Original: PoliceTime des Gebäudes)

var police_reaktion := 60.0    # Reaktionszeit der Polizei (Sekunden), gilt für stillen und lauten Alarm

var police_fahrt := 0.0        # Fahrzeit vom Revier (Sekunden), schwankt beim stillen Alarm innerhalb der Spanne

var max_volume := 30.0         # Original: Gebäude-Grenzwert MaxVolume (Wert hier gesetzt, im Quellcode nicht ausgelesen)

var patrol_count := 0
var _next_patrol := -1.0      # Spielzeit der nächsten Streife (negativ: noch nicht geplant)

var _loud_timer := 0.0

var peak_loud := 0.0            # lauteste Lautstärke während des Einbruchs (dB)


var rng := RandomNumberGenerator.new()
var hehler := "allround"  # gewählter Hehler für den Verkauf der Beute (siehe GameData.HEHLER)

var _last_snap := -1.0

## Kleidung kann als Liste (mehrere Stücke) oder als einzelner Name übergeben werden.
static func _gear_list(v) -> Array:
	if v is Array:
		var out: Array = []
		for g in v:
			if String(g) != "none" and String(g) != "":
				out.append(String(g))
		return out
	var s := String(v)
	if s == "" or s == "none":
		return []
	return [s]

## Mehrere Kleidungsstücke wirken zusammen: Spuren und Lärm werden multipliziert,
## die Sichtbarkeit nimmt den kleinsten Wert (am besten sichtbare Einschränkung).
func _combine_gear(ids: Array) -> Dictionary:
	var ev := 1.0
	var noise := 1.0
	var vis := 1.0
	for gid in ids:
		var g: Dictionary = GameData.GEAR.get(gid, {})
		if g.is_empty():
			continue
		ev *= float(g.ev)
		noise *= float(g.noise)
		vis = minf(vis, float(g.vis))
	return {"ev": ev, "noise": noise, "vis": vis}

static func _v2i(a) -> Vector2i:
	if a is Vector2i:
		return a
	return Vector2i(int(a[0]), int(a[1]))

static func cell_of(v: Vector2) -> Vector2i:
	## Feld, in dem eine Position liegt (Positionen sind in Unterfeldern angegeben).
	return Vector2i(floori(v.x / SUB), floori(v.y / SUB))

## Mittelpunkt eines Feldes in Unterfeldern.
static func center(c: Vector2i) -> Vector2:
	return Vector2(c.x * SUB + SUB * 0.5, c.y * SUB + SUB * 0.5)

static func center_i(c: Vector2i) -> Vector2i:
	return Vector2i(c.x * SUB + SUB / 2, c.y * SUB + SUB / 2)

## Position in Feldkoordinaten für Grafik und Planung (Feldmitte bei ganzen Zahlen, wie bisher).
static func cu(v: Vector2) -> Vector2:
	return v / float(SUB) - Vector2(0.5, 0.5)

static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func clock(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]

## Zeichen eines Unterfeldes. Außerhalb der Karte ist Wand.
func ftile(f: Vector2i) -> String:
	if f.x < 0 or f.y < 0 or f.x >= fine_w or f.y >= fine_h:
		return "W"
	var row: PackedByteArray = fine_rows[f.y]
	return char(int(row[f.x]))

## Unterfeld-Karte aus Rechtecken malen (Reihenfolge wie in den Daten).
func _paint_fine(spec: Dictionary) -> void:
	fine_w = int(spec.w)
	fine_h = int(spec.h)
	fine_rows = paint_rows(spec)

static func paint_rows(spec: Dictionary) -> Array:
	var fw := int(spec.w)
	var fh := int(spec.h)
	var bg := int(String(spec.get("bg", "o")).unicode_at(0))
	var rows: Array = []
	for y in range(fh):
		var row := PackedByteArray()
		row.resize(fw)
		row.fill(bg)
		rows.append(row)
	for r in spec.paint:
		var code := int(String(r[4]).unicode_at(0))
		for y in range(int(r[1]), int(r[3])):
			for x in range(int(r[0]), int(r[2])):
				if x >= 0 and y >= 0 and x < fw and y < fh:
					var row: PackedByteArray = rows[y]
					row[x] = code
					rows[y] = row
	return rows

static var _plan_cache := {}

static var _route_cache := {}

## Weg für die Planung (Anzeige): Unterfelder von a nach b. Türen gelten als passierbar, Wände,
## Fenster, Vitrinen und Tresen nicht. Leer, wenn es keinen Weg gibt.
static func plan_route(target: Dictionary, a: Vector2i, b: Vector2i) -> Array:
	var key := "%s|%d,%d|%d,%d" % [str(target.get("id", "?")), a.x, a.y, b.x, b.y]
	if _route_cache.has(key):
		return _route_cache[key]
	var prev := {a: a}
	var q: Array = [a]
	var head := 0
	var found := false
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if cur == b:
			found = true
			break
		for d in DIRS:
			var n: Vector2i = cur + d
			if prev.has(n):
				continue
			var t := plan_tile(target, n)
			if not (t == "o" or t == "." or t == "D"):
				continue
			prev[n] = cur
			q.append(n)
	var out: Array = []
	if found:
		var c: Vector2i = b
		while c != a:
			out.push_front(c)
			c = prev[c]
	_route_cache[key] = out
	return out

static var _fine_cache := {}

## Welches Werkzeug an einer Tür: Glas = Glasschneider, Stahltür = Tresor-Werkzeug (Schneidbrenner, Stethoskop), sonst Schloss.
static func door_tool(d: Dictionary) -> String:
	match str(d.get("kind", "")):
		"glas":
			return "glas"
		"stahl":
			return "tresor"
	return "schloss"

## Feiner Grundriss auf die aktuelle Auflösung (SUB) umgerechnet. Die Daten geben "sub" an, in dem
## ihre Koordinaten gemeint sind. So bleibt ein Grundriss gültig, wenn SUB geändert wird.
static func fine_spec(target: Dictionary) -> Dictionary:
	var key: String = str(target.get("id", "?"))
	if _fine_cache.has(key):
		return _fine_cache[key]
	var spec: Dictionary = target.fine
	var s := float(SUB) / float(spec.get("sub", SUB))
	var paint: Array = []
	for r in spec.paint:
		paint.append([int(round(float(r[0]) * s)), int(round(float(r[1]) * s)), int(round(float(r[2]) * s)), int(round(float(r[3]) * s)), r[4]])
	var out := {"w": int(round(float(spec.w) * s)), "h": int(round(float(spec.h) * s)), "bg": spec.get("bg", "o"), "paint": paint}
	_fine_cache[key] = out
	return out

## Zeichen eines Unterfeldes für die Planung (ohne laufende Simulation, Türen zu).
static func plan_tile(target: Dictionary, f: Vector2i) -> String:
	if not target.has("fine"):
		var c := anchor_of(f)
		var rows: Array = target.map
		if c.x < 0 or c.y < 0 or c.y >= rows.size() or c.x >= String(rows[0]).length():
			return "W"
		return String(rows[c.y]).substr(c.x, 1)
	var key: String = str(target.get("id", "?"))
	if not _plan_cache.has(key):
		_plan_cache[key] = paint_rows(fine_spec(target))
	var grid: Array = _plan_cache[key]
	if f.x < 0 or f.y < 0 or f.y >= grid.size() or f.x >= (grid[0] as PackedByteArray).size():
		return "W"
	var row: PackedByteArray = grid[f.y]
	return char(int(row[f.x]))

## Ohne eigenen Grundriss: jedes Feld wird SUB × SUB Unterfelder mit demselben Zeichen.
func _upscale_map() -> void:
	fine_w = w * SUB
	fine_h = h * SUB
	fine_rows = []
	for y in range(fine_h):
		var src := String(map[y / SUB])
		var row := PackedByteArray()
		row.resize(fine_w)
		for x in range(fine_w):
			row[x] = src.unicode_at(x / SUB)
		fine_rows.append(row)

## Tür-Kennung eines Unterfeldes: die nächstgelegene Tür (eine Tür kann über mehrere Felder reichen).
var _door_tile := {}

func door_key(f: Vector2i) -> Vector2i:
	if _door_tile.has(f):
		return _door_tile[f]
	return anchor_of(f)

func _build_door_tiles() -> void:
	_door_tile = {}
	if not use_fine or doors.is_empty():
		return
	for y in range(fine_h):
		for x in range(fine_w):
			var f := Vector2i(x, y)
			if ftile(f) != "D" and ftile(f) != "F":
				continue
			var best := Vector2i(-1, -1)
			var bd := INF
			for k in doors:
				var dd := center(k).distance_squared_to(Vector2(f))
				if dd < bd:
					bd = dd
					best = k
			_door_tile[f] = best

## Feld, zu dem ein Unterfeld gehört (Türen und Vitrinen werden über ihr Feld angesprochen).
static func anchor_of(f: Vector2i) -> Vector2i:
	return Vector2i(floori(float(f.x) / SUB), floori(float(f.y) / SUB))

var _case_cells := {}  # Vitrinen mit Kollision (Original: lsTurnObject ... LS_COLLISION)

func passable_f(f: Vector2i) -> bool:
	## Begehbarkeit eines Unterfeldes (Original: lsIsCollision). Wand, Fenster und Vitrine blockieren,
	## eine Tür nur, solange sie zu ist.
	var t := ftile(f)
	if t == "W" or t == "C" or t == "H" or t == "S" or t == "K" or t == "R" or t == "Z" or t == "P":
		return false
	if t == "D" or t == "F":  # Tür oder Schaufenster: begehbar, sobald offen
		return open_cells.has(door_key(f))
	return not _case_cells.has(anchor_of(f))

## Weg von einer Position (Unterfelder) zur Mitte eines Feldes. Leer, wenn schon dort oder kein Weg.
func path_to(pos: Vector2, cell: Vector2i) -> Array:
	return bfs(Vector2i(floori(pos.x), floori(pos.y)), center_i(cell))

func bfs(a: Vector2i, b: Vector2i) -> Array:
	## Weg für den Körper: jeder Punkt des Weges muss so frei sein, dass der Körperkreis hindurchpasst.
	if a == b:
		return []
	if not body_clear(Vector2(b)):
		return []
	var prev := {a: a}
	var q: Array = [a]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if cur == b:
			break
		for d in DIRS:
			var n: Vector2i = cur + d
			if prev.has(n) or not body_clear(Vector2(n)):
				continue
			prev[n] = cur
			q.append(n)
	if not prev.has(b):
		return []
	var path: Array = []
	var c: Vector2i = b
	while c != a:
		path.push_front(c)
		c = prev[c]
	return path

func blockers_between(a: Vector2, b: Vector2) -> float:
	## Zählt, wie viele Wände und geschlossene Türen die Linie zwischen zwei Positionen kreuzt
	## (Bresenham auf Unterfeldern). Eine Wand zählt einmal, egal wie dick sie ist.
	var p0 := Vector2i(floori(a.x), floori(a.y))
	var p1 := Vector2i(floori(b.x), floori(b.y))
	var n := 0
	var dx := absi(p1.x - p0.x)
	var dy := -absi(p1.y - p0.y)
	var sx := 1 if p0.x < p1.x else -1
	var sy := 1 if p0.y < p1.y else -1
	var err := dx + dy
	var x := p0.x
	var y := p0.y
	var was_blocked := false
	var guard := 0
	while guard < 800:
		guard += 1
		if x == p1.x and y == p1.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		var c := Vector2i(x, y)
		if c == p1:
			break
		var blocked := blocks_sight_f(c)
		if blocked and not was_blocked:
			n += 1
		was_blocked = blocked
	return float(n)

## Bezeichnung eines Behälters mit Beute: Kasse oder Vitrine.
## Name des Ziels einer Bewegung: Ort, Feld mit Koordinaten oder Punkt in Unterfeldern.
func _ziel_name(a: Dictionary) -> String:
	if a.has("to"):
		return _disp(str(a.to))
	if a.has("fine"):
		return Texte.t("sim.punkt") % [int(a.fine[0]), int(a.fine[1])]
	if a.has("cell"):
		return Texte.t("plan.feld_pos") % [int(a.cell[0]), int(a.cell[1])]
	return ""


func _case_word(l: Dictionary) -> String:
	return Texte.t("obj.kasse") if str(l.get("id", "")) == "kasse" else Texte.t("obj.vitrine")

## Zustand aller Türen und Vitrinen, Schlüssel "x,y" (für Grafik und Planung).
func _obj_states() -> Dictionary:
	var out := {}
	for p in doors:
		var d: Dictionary = doors[p]
		out["%d,%d" % [p.x, p.y]] = {"kind": "door", "id": d.id, "name": d.name, "locked": d.locked, "open": open_cells.has(p), "glas": str(d.get("kind", "")) == "glas", "needs": door_tool(d), "destroyed": bool(d.destroyed)}
	for lid in loot_order:
		var l: Dictionary = loot[lid]
		out["%d,%d" % [l.pos.x, l.pos.y]] = {"kind": "case", "id": lid, "name": l.name, "word": _case_word(l), "locked": l.locked, "open": l.opened}
	return out

func _snapshot() -> void:
	_last_snap = time
	var f := {"t": time, "crew": {}, "guards": {}, "open": [], "obj": _obj_states(), "alarm": alarm_active, "cd": countdown}
	for c in crew:
		# moving/dx/dy: läuft die Person gerade, und in welche Richtung (für die Laufanimation)
		var mv: bool = not c.path.is_empty()
		var dir: Vector2 = (Vector2(c.path[0]) - c.pos).normalized() if mv else Vector2(c.get("facing", Vector2(0, 1)))
		var cp := cu(c.pos)
		# Laufende Aktion (für Animationen): TOOL, OPEN, TAKE oder "" (gehen, warten)
		var act := ""
		if c.get("started", false) and c.idx < c.plan.size():
			act = str(c.plan[c.idx].t)
		f.crew[c.id] = [cp.x, cp.y, c.seen_now, c.carried.size(), mv, dir.x, dir.y, act]
	for g in guards:
		var gc: Vector2 = cu(g.pos)
		f.guards[g.id] = [gc.x, gc.y, g.state, g.suspicion, g.seen, g.facing.x, g.facing.y]
	for oc in open_cells:
		f.open.append([oc.x, oc.y])
	# Zustand jeder Beute (für die Anzeige: noch im Objekt oder schon genommen)
	f["loot"] = {}
	for lid in loot_order:
		f.loot[lid] = loot[lid].state
	frames.append(f)

## Zielzelle einer Aktion: direkt (cell), über Ortsnamen oder über den Namen einer Vitrine.
func _cell_of(a: Dictionary, key: String) -> Vector2i:
	if a.has("cell"):
		return Vector2i(int(a.cell[0]), int(a.cell[1]))
	var nm: String = a.get(key, "")
	if points.has(nm):
		return points[nm]
	if loot.has(nm):
		return loot[nm].pos
	# Türen und Fenster (Schaufenster) über ihre ID
	for k in doors:
		if str(doors[k].id) == nm:
			return k
	return Vector2i(-1, -1)

## Vitrine (Beute) an dieser Zelle, oder "".
func _case_at(cell: Vector2i) -> String:
	for lid in loot_order:
		if loot[lid].pos == cell:
			return lid
	return ""

## Anzeigename zu einer Objekt-ID (für Meldungen und das Ereignisprotokoll).
func _disp(id: String) -> String:
	return Texte.t(GameData.name_von(id))

## Bezeichnung des Ziels einer Aktion (für das Ereignisprotokoll).
func _ev_obj(a: Dictionary) -> String:
	match str(a.t):
		"TOOL", "OPEN", "CLOSE":
			return _disp(str(a.get("on", "")))
		"TAKE":
			return _disp(str(a.get("loot", "")))
		"MOVE":
			return _ziel_name(a)
		"CALL_CAR":
			return _disp("fluchtwagen")
	return ""

func _log(text: String) -> void:
	log_lines.append("[%s] %s" % [clock(time), text])

var alarm_source := ""  # wer den Alarm ausgelöst hat (Melder, Wache, Lärm), unabhängig von der Sprache

var overlaps := 0      # wie oft eine Person auf ein Objekt warten musste, das schon besetzt war

var overlap_lines: Array = []  # Meldungen dazu (für den Planer, ohne Zeitstempel)

func _end(new_status: String, reason: String) -> void:
	if status != "RUNNING":
		return
	status = new_status
	ended_reason = reason
	_log(reason)

## Objektsperre: an einem Objekt (Tür, Vitrine, Wertschrank, Wache, Beute) arbeitet immer nur eine Person.
## Die zweite wartet, bis die erste fertig ist (Original: ein Schloss, eine Person).
var _busy := {}   # Schlüssel -> Personen-Id

## Körperradius in Unterfeldern (4,5 = 0,28 m, etwa Schulterbreite; Tür 1 m = 16). Ein Punkt gilt nur als frei, wenn der ganze Kreis begehbar ist.
const BODY := 4.5

func body_clear(p: Vector2) -> bool:
	## Prüft Mitte und acht Punkte am Körperkreis. Alle müssen begehbar sein (Wände, Fenster, Vitrinen, Kasse, Tresor).
	if not passable_f(Vector2i(floori(p.x), floori(p.y))):
		return false
	for i in 8:
		var a := TAU * float(i) / 8.0
		var q := p + Vector2(cos(a), sin(a)) * BODY
		if not passable_f(Vector2i(floori(q.x), floori(q.y))):
			return false
	return true

func _walk(obj: Dictionary, dt: float) -> bool:
	## Bewegt ein Objekt entlang seines Pfades in kleinen Schritten, jeder Schritt wird auf den Körper geprüft.
	## Trifft die Person auf ein Hindernis, endet der Weg mit obj.stuck = true.
	## Der Rest der Zeit läuft über die nächsten Unterfelder weiter, damit kein Weg Zeit verliert.
	var budget := WALK * SUB * dt
	while not obj.path.is_empty() and budget > 0.0:
		var goal: Vector2i = obj.path[0]
		var d: Vector2 = Vector2(goal) - obj.pos
		var dist := d.length()
		if dist <= 0.0001:
			obj.path.pop_front()
			continue
		obj["facing"] = d / dist
		var s := minf(dist, budget)
		var dir := d / dist
		var moved := 0.0
		while moved < s - 0.0001:
			var step := minf(0.5, s - moved)
			var nxt: Vector2 = obj.pos + dir * step
			if not body_clear(nxt):
				obj["stuck"] = true
				obj.path.clear()
				return true
			obj.pos = nxt
			moved += step
		budget -= s
		if s >= dist - 0.0001:
			obj.pos = Vector2(goal)
			obj.path.pop_front()
	return obj.path.is_empty()

## Blickrichtung der Person als eine der vier Richtungen (Original: uch_ViewDirection, nur Laufen ändert sie).
static func face4(v: Vector2) -> Vector2i:
	if absf(v.x) >= absf(v.y):
		return Vector2i(signi(int(roundf(v.x))), 0) if absf(v.x) > 0.01 else Vector2i(0, 1)
	return Vector2i(0, signi(int(roundf(v.y))))

## Ein Objekt ist nur erreichbar, wenn es in der Zelle liegt, auf die die Person blickt
## (Original: plGetObjectsList, Bereich vor der Person in Blickrichtung).
## Vereinfachung gegenüber dem Original: Die Person steht orthogonal neben dem Objekt und dreht sich dorthin.
## (Im Original dreht man sich nur durch Gehen; das ist für den Spieler unsichtbar und zu umständlich.)
func _reach(c: Dictionary, p: Vector2) -> bool:
	## Reichweite: höchstens ein Feld Abstand (orthogonal) zur Mitte des Objekts.
	var d: Vector2 = (p - c.pos) / float(SUB)
	if d.length() < 0.01:
		return false
	# Reichweite zur Mitte des Objekts oder zu seinem nächsten Teil (Wertschrank oder Kasse liegen oft an der Wand)
	if absf(d.x) + absf(d.y) > 1.05 and not _touches(c.pos, p):
		return false
	if not _sight_clear(c.pos, p):
		return false
	c["facing"] = d
	return true

func _touches(a: Vector2, p: Vector2) -> bool:
	## Liegt ein Teil des Objekts (Vitrine, Kasse, Tür) innerhalb eines Feldes Abstand zur Person?
	var bf := Vector2i(floori(p.x), floori(p.y))
	var is_door := ftile(bf) == "D"
	var key := door_key(bf) if is_door else Vector2i(-1, -1)
	var pc := anchor_of(bf)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := pc + Vector2i(dx, dy)
			for y in range(SUB):
				for x in range(SUB):
					var f := Vector2i(cell.x * SUB + x, cell.y * SUB + y)
					var t := ftile(f)
					var mine := (t == "D" and is_door and door_key(f) == key) or ((t == "S" or t == "K") and not is_door)
					if not mine:
						continue
					var q := Vector2(f) + Vector2(0.5, 0.5)
					var dd := (q - a) / float(SUB)
					if absf(dd.x) + absf(dd.y) <= 1.05:
						return true
	return false

## Nächster freier Standpunkt im Feld: Steht der Feldmittelpunkt zu nah an einer Wand, nimmt die Person den nächsten freien Punkt.
func _stand_near(f: Vector2i) -> Vector2i:
	var cell := anchor_of(f)
	var best := f
	var best_d := INF
	for y in range(SUB):
		for x in range(SUB):
			var q := Vector2i(cell.x * SUB + x, cell.y * SUB + y)
			if not body_clear(Vector2(q)):
				continue
			var dd := Vector2(q - f).length()
			if dd < best_d:
				best_d = dd
				best = q
	return best

func _sight_clear(a: Vector2, b: Vector2) -> bool:
	## Sichtlinie zum Objekt: Wand, Tresen, Fenster oder geschlossene Tür dazwischen machen die Reichweite ungültig.
	## Das Zielfeld selbst (Tür, Vitrine, Kasse) wird nicht geprüft, dort steht das Objekt.
	var bf := Vector2i(floori(b.x), floori(b.y))
	var tcell := anchor_of(bf)
	# Eine Tür besteht aus mehreren Unterfeld-Zeilen; alle gehören zum Zielobjekt
	var tkey := door_key(bf) if ftile(bf) == "D" else tcell
	var n := maxi(1, int(ceil(a.distance_to(b))))
	for i in range(1, n):
		var q := a.lerp(b, float(i) / float(n))
		var f := Vector2i(floori(q.x), floori(q.y))
		if anchor_of(f) == tcell or anchor_of(f) == anchor_of(a):
			continue
		if ftile(f) == "D" and door_key(f) == tkey:
			continue
		# Vitrine und Kasse reichen oft über ihre Zelle hinaus: eigene Vitrinenteile zählen nicht als Hindernis
		var fa := anchor_of(f)
		if (ftile(f) == "S" or ftile(f) == "K") and absi(fa.x - tcell.x) <= 1 and absi(fa.y - tcell.y) <= 1:
			continue
		# Tresen: man kann darüber greifen (Kasse liegt auf dem Tresen), aber nicht hindurchgehen
		if ftile(f) == "C" or ftile(f) == "H" or ftile(f) == "R" or ftile(f) == "Z" or ftile(f) == "P":
			continue
		if not passable_f(f):
			return false
	return true

## Verfolgungsrechnung: Die Polizei startet nach `countdown` Sekunden am Ausgang. Sie holt den Wagen ein,
## wenn ihr Tempo größer ist und sie ihn vor dem Ende der Fluchtstrecke erreicht. "KNAPP" = erst kurz vorm Ende.
static func chase_result(car_kmh: float, police_kmh: float, countdown: float, km: float) -> String:
	var t_end := km / maxf(car_kmh, 1.0) * 3600.0
	var t_catch := INF
	if police_kmh > car_kmh:
		t_catch = police_kmh * countdown / (police_kmh - car_kmh)
	if t_catch <= t_end:
		return "GEFASST"
	if t_catch <= t_end * 1.5:
		return "KNAPP"
	return "ENTKOMMEN"

# ---------------------------------------------------------------- Ergebnis
func fence_heat() -> float:
	var heat := evidence * 0.8 + seen_sec * 0.1
	if alarm_active:
		heat += 15.0
	if status == "GEFASST":
		heat += 40.0
	return heat

## Festgenommen: Bei einer Festnahme trifft es alle, die die Verfolgung eingeholt hat. Sonst jede Person,
## die nicht am Fluchtwagen steht.
func _gefangene_ids() -> Array:
	var out: Array = []
	if status != "GEFASST":
		return out
	for c in crew:
		if chase == "GEFASST" or cheb(cell_of(c.pos), escape_cell) > 1:
			out.append(c.id)
	return out

func result() -> Dictionary:
	# Endstand jeder Person: Feld und Blickrichtung (für die Planung, damit sie weiß, wo jemand steht)
	var ends := {}
	for c in crew:
		ends[c.id] = {"cell": [cell_of(c.pos).x, cell_of(c.pos).y], "fine": [c.pos.x, c.pos.y], "face": [face4(c.get("facing", Vector2(0, 1))).x, face4(c.get("facing", Vector2(0, 1))).y]}
	return {
		"crew_end": ends,
	"gefangen": _gefangene_ids(),
		"status": status,
		"reason": ended_reason,
		"payout": payout,
		"heat": fence_heat(),
		"time": time,
		"peak_loud": peak_loud,
		"alarm_source": alarm_source,
		"ueberschneidungen": overlaps,
		"ueberschneidung_zeilen": overlap_lines,
		"max_volume": max_volume,
		"alarm": alarm_active,
		"log": log_lines,
		"events": events,
		"loot_taken": _loot_names(true),
		"loot_missed": _loot_names(false),
		"car_laderaum": car_laderaum,
		"chase": chase,
		"segments": _segments(),
		"states": _obj_states(),
		"used": _used_map(),
		"frames": frames,
		"noise": noise_log,
		"alarm_time": alarm_time,
		"crew": _crew_info(),
	}

func _used_map() -> Dictionary:
	var out := {}
	for c in crew:
		out[c.id] = c.used
	return out

func _segments() -> Dictionary:
	var out := {}
	for c in crew:
		out[c.id] = c.segments
	return out

func _crew_info() -> Array:
	var out: Array = []
	for c in crew:
		out.append({"id": c.id, "name": c.name})
	return out

func _loot_names(taken: bool) -> Array:
	var out: Array = []
	for lid in loot_order:
		var l: Dictionary = loot[lid]
		var got: bool = l.state == "DELIVERED" or l.state == "CARRIED"
		if got == taken:
			out.append(l.name)
	return out

func blocks_sight_f(f: Vector2i) -> bool:
	var t := ftile(f)
	if t == "W":
		return true
	if t == "D" or t == "F":
		return not open_cells.has(door_key(f))
	return false

## Sichtkegel einer Wache in Kartenkoordinaten. Jeder Strahl endet an der ersten Sperre.
## Grundriss und 3D-Ansicht nutzen diese Funktion, damit beide dasselbe zeigen.
func view_cone(origin: Vector2, facing: Vector2, vis: float) -> PackedVector2Array:
	## origin in Unterfeldern, vis in Feldern. Ergebnis in Feldkoordinaten (wie cu()).
	var pts := PackedVector2Array()
	pts.append(cu(origin))
	var dir0 := facing if facing.length() > 0.001 else Vector2(1, 0)
	var base := dir0.angle()
	var half := deg_to_rad(55.0)
	var n := 48
	var reach := vis * SUB
	var step := 0.04 * SUB
	for i in range(n + 1):
		var a := base - half + (2.0 * half) * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var end := origin
		var d := 0.0
		while d <= reach:
			var p := origin + dir * d
			if blocks_sight_f(Vector2i(floori(p.x), floori(p.y))):
				break
			end = p
			d += step
		pts.append(cu(end))
	return pts

## Sieht die Wache die Person in diesem Moment? Gleiche Regel wie in der Simulation.
func guard_sees(g: Dictionary, c: Dictionary) -> bool:
	if g.state in ["ALARMED", "IDLE", "OUT"]:
		return false
	if g.pos.distance_to(c.pos) / SUB > float(g.vision):
		return false
	return blockers_between(g.pos, c.pos) == 0

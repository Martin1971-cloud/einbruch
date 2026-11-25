class_name Sim
extends RefCounted
## Ausführungslogik eines Einbruchs. Ohne Darstellung, deterministisch.
## Wird für die Planungsvorschau (schnell durchlaufen) und für die 3D-Ausführung genutzt.

const DT := 0.1
const SNAP := 0.1            # Abstand der Momentaufnahmen für die Wiedergabe (Sekunden)
const TIMEOUT := 900.0
const WALK := 1.0            # Feld pro Sekunde
const SUB := 16              # Unterfelder je Feld und Richtung (Bewegung und Sicht in Unterfeldern)
const LOOT_TIME := 3.0
## Öffnen von Hand (Tür oder Vitrine, die schon entriegelt ist). Im Original: Tabelle "opens", Werkzeug Hand.
const OPEN_TIME := 3.0
const DECAY := 2.0
const SEE_RATE := 40.0
const WALL_DAMPING := 15.0
const DIST_DAMPING := 1.5
const PATROL_ALARM_BASE := 12.0
const POLICE_BASE := 60.0
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
var panel := {}
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
var car_v := 100.0      # Fahrleistung des Wagens (km/h, mit Fahrer)
var police_v := 140.0   # Polizeitempo (km/h), abhängig von der Wachrate des Ziels
var escape_km := 10.0   # Fluchtstrecke in km
var alarm_active := false
var flags := {}
var log_lines: Array = []
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
const PATROL_P := 1.0 / 7230.0 # Original: 1 zu 30*(270 - GRate/2 + 1), GRate 60 angenommen, pro Sekunde
const PATROL_PCT := 5.0        # tcPATROL_ALARM
var police_base := 60.0        # Polizeizeit nach Alarm (Original: PoliceTime des Gebäudes)
var max_volume := 30.0         # Original: Gebäude-Grenzwert MaxVolume (Wert hier gesetzt, im Quellcode nicht ausgelesen)
var patrol_count := 0
var _loud_timer := 0.0
var peak_loud := 0.0            # lauteste Lautstärke während des Einbruchs (dB)
var _patrol_timer := 0.0
var rng := RandomNumberGenerator.new()
var _last_snap := -1.0


static func create(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary) -> Sim:
	var s := Sim.new()
	s._setup(target, team, plans, car_cfg)
	return s


func _setup(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary) -> void:
	target_name = target.name
	max_volume = float(target.get("max_volume", 30.0))
	police_base = float(target.get("police_time", POLICE_BASE))
	rng.seed = 4711  # fester Seed: Vorschau und Ausführung laufen gleich
	map = target.map
	h = map.size()
	w = String(map[0]).length()
	if target.has("fine"):
		use_fine = true
		_paint_fine(fine_spec(target))
	else:
		_upscale_map()
	for k in target.points:
		points[k] = _v2i(target.points[k])
	escape_cell = points.get("Fluchtwagen", Vector2i.ZERO)
	for d in target.doors:
		var p := _v2i(d.pos)
		doors[p] = {"name": d.name, "res": float(d.res), "cplx": float(d.cplx), "destroyed": false, "locked": bool(d.get("locked", true)), "kind": str(d.get("kind", "tuer"))}
	for pair in target.get("treppen", []):
		var sa := Vector2i(int(pair[0]), int(pair[1]))
		var sb := Vector2i(int(pair[2]), int(pair[3]))
		stairs[sa] = sb
		stairs[sb] = sa
	if target.has("panel"):
		panel = {"name": target.panel.name, "pos": _v2i(target.panel.pos), "res": float(target.panel.res), "cplx": float(target.panel.cplx), "bypassed": false}
	for s in target.sensors:
		sensors.append({"name": s.name, "pos": _v2i(s.pos), "threshold": float(s.threshold), "active": true})
	for l in target.loot:
		if not use_fine:
			_case_cells[_v2i(l.pos)] = true   # ohne feinen Grundriss blockiert die Vitrine ihr ganzes Feld
		loot[l.id] = {"id": l.id, "name": l.name, "pos": _v2i(l.pos), "value": int(l.value), "weight": float(l.weight), "state": "ROOM", "carrier": "", "opened": bool(l.get("open", false)), "locked": not bool(l.get("open", false))}
		loot_order.append(l.id)
	for g in target.guards:
		var st := _v2i(g.start)
		var route: Array = []
		for r in g.route:
			route.append(_v2i(r))
		guards.append({
			"id": g.id, "name": g.name, "type": g.type, "kampf": float(g.get("kampf", 0)),
			"pos": center(st), "route": route, "wp": 0, "path": [], "dwell": 0.0,
			"dwell_sec": float(g.dwell), "state": "PATROL", "suspicion": 0.0,
			"vision": float(g.vision), "hearing": float(g.hearing), "reaction": float(g.reaction),
			"facing": Vector2(1, 0), "target": Vector2i(-1, -1), "inv_arrived": false, "inv_timer": 0.0, "seen": false,
		})
	for g2 in guards:
		if g2.type == "STREET":
			g2.state = "IDLE"  # Streife rückt erst nach einem Alarm aus
	for c in team:
		var st2 := _v2i(c.start)
		var gear_ids := _gear_list(c.get("gear", []))
		var gear := _combine_gear(gear_ids)
		crew.append({
			"id": c.id, "name": c.name, "skills": c.skills,
			"gear": gear, "gear_ids": gear_ids,
			# Tragkraft in kg (Original: (Ausdauer + Stärke) × 200 g, dazu ein Volumen; hier nur Gewicht, Kraft = Kampfsport)
			"capacity": 15.0 + float(c.skills.FORCE) * 0.35,
			"pos": center(st2), "facing": Vector2(0, 1), "plan": plans.get(c.id, []), "idx": 0,
			"path": [], "timer": 0.0, "started": false, "done": false,
			"carried": [], "ev": 0.0, "noise": 0.0, "seen_sec": 0.0, "tool_ok": true,
			"act_start": 0.0, "segments": [], "seen_now": false, "used": {},
		})
	car.eta = float(car_cfg.eta)
	car_v = float(car_cfg.get("v", 100.0))
	police_v = 140.0 + float(target.get("guard_rate", 10.0)) * 0.25
	escape_km = float(target.get("escape_km", 10.0))
	# Wie im Original: Alle starten am Fluchtwagen, der Wagen steht dort bereit.
	car.called = true
	car.present = true
	car.arrive_at = 0.0
	for c0 in crew:
		c0.pos = center(escape_cell)
	_build_door_tiles()
	_log("Team im Gebäude. Ablauf beginnt.")


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


func tile(c: Vector2i) -> String:
	## Zeichen eines ganzen Feldes (Karte in Feldern).
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return "W"
	return String(map[c.y]).substr(c.x, 1)


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


## Kollision wie im Original (landscap/scroll.c, lsIsCollision): Wände, geschlossene Türen und
## Gegenstände mit Kollision (Vitrinen) blockieren. Personen blockieren sich nicht (Sprites sind nicht in der Maske).
func passable(c: Vector2i) -> bool:
	return passable_f(center_i(c))

var _case_cells := {}  # Vitrinen mit Kollision (Original: lsTurnObject ... LS_COLLISION)


func passable_f(f: Vector2i) -> bool:
	## Begehbarkeit eines Unterfeldes (Original: lsIsCollision). Wand, Fenster und Vitrine blockieren,
	## eine Tür nur, solange sie zu ist.
	var t := ftile(f)
	if t == "W" or t == "C" or t == "S" or t == "K":
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


## Zustand aller Türen und Vitrinen, Schlüssel "x,y" (für Grafik und Planung).
func _obj_states() -> Dictionary:
	var out := {}
	for p in doors:
		var d: Dictionary = doors[p]
		out["%d,%d" % [p.x, p.y]] = {"kind": "door", "name": d.name, "locked": d.locked, "open": open_cells.has(p), "glas": str(d.get("kind", "")) == "glas", "needs": door_tool(d)}
	for lid in loot_order:
		var l: Dictionary = loot[lid]
		out["%d,%d" % [l.pos.x, l.pos.y]] = {"kind": "case", "name": l.name, "locked": l.locked, "open": l.opened}
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
	for lid in loot_order:
		if loot[lid].name == nm:
			return loot[lid].pos
	# Türen und Fenster (Schaufenster) über ihren Namen
	for k in doors:
		if str(doors[k].name) == nm:
			return k
	return Vector2i(-1, -1)


## Vitrine (Beute) an dieser Zelle, oder "".
func _case_at(cell: Vector2i) -> String:
	for lid in loot_order:
		if loot[lid].pos == cell:
			return lid
	return ""


func _log(text: String) -> void:
	log_lines.append("[%s] %s" % [clock(time), text])


func _alarm(source: String, kind: String, delay: float) -> void:
	if countdown >= 0.0:
		return
	alarm_time = time
	countdown = (PATROL_ALARM_BASE if kind == "PATROL" else police_base) + delay
	alarm_active = true
	_log("ALARM durch %s. Polizei in %.0f s." % [source, countdown])


func _end(new_status: String, reason: String) -> void:
	if status != "RUNNING":
		return
	status = new_status
	ended_reason = reason
	_log(reason)


# ---------------------------------------------------------------- Schritt

func step(dt: float) -> void:
	if status != "RUNNING":
		return
	time += dt
	if alarm_active:
		_dispatch_patrols()
	if time > TIMEOUT:
		_end("ABBRUCH", "Zeitlimit erreicht. Das Team verliert die Geduld.")
		return
	for c in crew:
		_step_crew(c, dt)
	_check_loudness(dt)
	_check_patrols(dt)
	_update_car()
	if time - _last_snap >= SNAP - 0.001:
		_snapshot()
	for g in guards:
		_move_guard(g, dt)
	_vision(dt)
	_guard_checks_objects()
	if status != "RUNNING":
		return
	_check_escape()
	if status != "RUNNING":
		return
	if countdown >= 0.0:
		countdown -= dt
		if countdown <= 0.0:
			countdown = 0.0
			_end("GEFASST", "Die Polizei riegelt das Gebäude ab. Das Team wird festgenommen.")
			return
	var all_done := true
	var at_exit := true
	for c in crew:
		if not c.done:
			all_done = false
		if cheb(cell_of(c.pos), escape_cell) > 1:
			at_exit = false
	# Alle Aktionen fertig: Wenn das Team am Ausgang steht und ein Wagen gerufen ist, wird gewartet.
	if all_done and not (at_exit and car.called):
		_end("ABBRUCH", "Alle Aktionen sind erledigt, aber das Team kommt nicht vom Gelände weg.")


## Lautstärke: Maximum über alle Personen (Original: tcGetTotalLoudness). Über der Grenze = leiser Alarm.
func _check_loudness(dt: float) -> void:
	_loud_timer += dt
	if _loud_timer < LOUD_CHECK:
		return
	_loud_timer = 0.0
	var total := 0.0
	for c in crew:
		total = maxf(total, float(c.get("loud", LOUD_STD)))
	peak_loud = maxf(peak_loud, total)
	if total > max_volume:
		_alarm("Lärm (%.0f dB)" % total, "QUIET", 0.0)


## Streifgänge (Original: player.c, Patrouille pro Sekunde, tcAlarmByPatrol): Ein Streifgang
## löst einen leisen Alarm aus, wenn der Anteil veränderter Objekte zu groß ist.
func _check_patrols(dt: float) -> void:
	_patrol_timer += dt
	if _patrol_timer < 1.0:
		return
	_patrol_timer -= 1.0
	if rng.randf() >= PATROL_P:
		return
	patrol_count += 1
	var total := float(doors.size() + loot_order.size())
	var changed := 0.0
	for p in doors:
		if not doors[p].locked:
			changed += 1.0
	for lid in loot_order:
		var l: Dictionary = loot[lid]
		if not l.locked or l.state != "ROOM":
			changed += 1.0
	if total * PATROL_PCT / (125.0 * float(patrol_count)) < changed:
		_alarm("Streifgang", "QUIET", 0.0)
	else:
		_log("Streifgang kontrolliert: nichts Auffälliges.")


func _dispatch_patrols() -> void:
	## Im Original rückt die Streife erst aus, wenn ein Alarm ausgelöst wurde
	## (Lärm, Wache, Sensor). Sie fährt dann zum Eingang.
	for g in guards:
		if g.type == "STREET" and g.state == "IDLE":
			g.state = "RESPOND"
			g.path = []
			g.target = points.get("Außen vor dem Eingang", Vector2i(1, 5))
			_log("Streifenwagen wird alarmiert und fährt zum Gebäude.")


## Objektsperre: an einem Objekt (Tür, Vitrine, Wertschrank, Wache, Beute) arbeitet immer nur eine Person.
## Die zweite wartet, bis die erste fertig ist (Original: ein Schloss, eine Person).
var _busy := {}   # Schlüssel -> Personen-Id


func _free_for(c: Dictionary, key: String) -> bool:
	if _busy.has(key) and _busy[key] != c.id:
		if not c.get("waiting", false):
			_log("%s wartet, bis %s fertig ist." % [c.name, _busy_name(key)])
		c["waiting"] = true
		c["msg"] = "wartet auf %s" % _busy_name(key)
		return false
	c["waiting"] = false
	return true


func _lock(c: Dictionary, key: String) -> void:
	_busy[key] = c.id


func _busy_name(key: String) -> String:
	for x in crew:
		if x.id == _busy.get(key, ""):
			return x.name.split(" ")[0]
	return "einem Teammitglied"


func _unlock_all(c: Dictionary) -> void:
	for k in _busy.keys():
		if _busy[k] == c.id:
			_busy.erase(k)


func _next(c: Dictionary) -> void:
	_unlock_all(c)
	if c.idx < c.plan.size():
		# "fail": Grund, falls die Aktion nicht ausgeführt werden konnte
		c.segments.append({"i": c.idx, "t": c.plan[c.idx].t, "start": c.act_start, "end": time, "fail": str(c.get("fail", "")), "msg": str(c.get("msg", "")), "loud": float(c.get("loud", LOUD_STD))})
		c["msg"] = ""
	c["fail"] = ""
	c.act_start = time
	c.idx += 1
	c.started = false
	c["loud"] = LOUD_STD
	c.path = []
	c.timer = 0.0


func _fail(c: Dictionary, text: String) -> void:
	_log("%s: %s" % [c.name, text])
	c["fail"] = text
	_next(c)


func _step_crew(c: Dictionary, dt: float) -> void:
	if c.done:
		return
	if c.idx >= c.plan.size():
		c.done = true
		return
	var a: Dictionary = c.plan[c.idx]
	match a.t:
		"MOVE":
			_do_move(c, a, dt)
		"WAIT":
			if not c.started:
				c.timer = float(a.sec)
				c.started = true
			c.timer -= dt
			if c.timer <= 0.0:
				_next(c)
		"TOOL":
			_do_tool(c, a, dt)
		"TAKE":
			_do_take(c, a, dt)
		"NEUTRALIZE":
			_do_neutralize(c, a, dt)
		"CALL_CAR":
			if not car.called:
				car.called = true
				car.arrive_at = time + car.eta
				_log("%s ruft den Fluchtwagen. Ankunft in %.0f s." % [c.name, car.eta])
			_next(c)
		"FLAG_SET":
			flags[a.flag] = true
			_log("%s setzt Signal: %s" % [c.name, GameData.FLAG_NAMES.get(a.flag, a.flag)])
			_next(c)
		"FLAG_WAIT":
			if flags.get(a.flag, false):
				_next(c)
		"OPEN":
			_do_open(c, a, dt)
		"TREPPE":
			_do_stairs(c, a, dt)
		_:
			_next(c)


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


func _do_move(c: Dictionary, a: Dictionary, dt: float) -> void:
	## Ziel: ein freier Punkt in Unterfeldern (a.fine) oder mitte eines Feldes (a.cell / Ortsname).
	var goal: Vector2i
	if a.has("fine"):
		goal = Vector2i(int(a.fine[0]), int(a.fine[1]))
	else:
		goal = center_i(_cell_of(a, "to"))
	if not c.started:
		c.started = true
		var here := Vector2i(floori(c.pos.x), floori(c.pos.y))
		if not body_clear(Vector2(goal)):
			goal = _stand_near(goal)
		if not body_clear(Vector2(goal)):
			_fail(c, "%s kann dort nicht stehen (Wand, Fenster oder Vitrine)." % c.name)
			return
		c.path = bfs(here, goal)
		if c.path.is_empty() and here != goal:
			_fail(c, "Kein Weg nach %s. Eine Tür ist noch zu oder der Weg ist blockiert." % _goal_name(a))
			return
		return
	if _walk(c, dt):
		if c.get("stuck", false):
			c["stuck"] = false
			_fail(c, "%s stößt an eine Wand oder ein Objekt. Der Weg ist versperrt." % c.name)
			return
		_next(c)


func _goal_name(a: Dictionary) -> String:
	if a.has("fine"):
		return "dem Punkt [%d, %d]" % [int(a.fine[0]), int(a.fine[1])]
	return str(a.get("to", "Feld"))


func _do_tool(c: Dictionary, a: Dictionary, dt: float) -> void:
	var tool: Dictionary = GameData.TOOLS[a.tool]
	var cell: Vector2i = _cell_of(a, "on")
	var key := "obj:%d,%d" % [cell.x, cell.y]
	var case_id := _case_at(cell)
	var is_panel: bool = panel.has("pos") and panel.pos == cell and not panel.bypassed
	var door: Variant = doors.get(cell, null)
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(cell)):
			_fail(c, "%s steht nicht vor %s. Erst davor gehen (in Blickrichtung)." % [c.name, a.on])
			return
		# Vorkenntnisse: Werkzeug braucht eine Mindeststufe der Fähigkeit (Original: tcGetNecessaryAbility / plCheckAbilities)
		if float(c.skills.get(tool.type, 0)) < float(tool.get("min", 0)):
			_fail(c, "%s fehlen die Vorkenntnisse für %s (%s ab %d %%)." % [c.name, tool.name, tool.ability, int(tool.min)])
			return
		# Schaufenster brauchen den Glasschneider, Türen und Vitrinen das Schloss-Werkzeug
		var needs := door_tool(door) if door != null else "schloss"
		if (is_panel and tool.obj != "alarm") or ((door != null or case_id != "") and tool.obj != needs):
			_fail(c, "%s ist für %s nicht geeignet." % [tool.name, a.on])
			return
		# Entriegeln geht nur bei verschlossenen Schlössern (Original: LOCK_UNLOCK-Bit)
		if door != null and not door.locked:
			_fail(c, "%s ist schon entriegelt. Jetzt öffnen." % a.on)
			return
		if case_id != "" and not loot[case_id].locked:
			_fail(c, "%s ist schon entriegelt. Jetzt öffnen." % a.on)
			return
		var obj := 0.0
		if is_panel:
			obj = panel.cplx if tool.type in ["TECH", "ELECTRONICS"] else panel.res
		elif door != null:
			obj = door.cplx if tool.type in ["TECH", "ELECTRONICS"] else door.res
		elif case_id != "":
			obj = 40.0 if tool.type in ["TECH", "ELECTRONICS"] else 50.0
		else:
			_fail(c, "An %s ist nichts zu öffnen." % a.on)
			return
		if obj > float(tool.max):
			_fail(c, "%s ist für %s zu stabil bzw. zu komplex." % [a.on, tool.name])
			return
		var skill := float(c.skills.get(tool.type, 1))
		var dur: float = float(tool.time) * (1.0 + obj / 100.0) * (1.0 - skill / 150.0)
		var noise: float = float(tool.noise) * (1.0 + obj / 200.0) * (1.0 - skill / 200.0)
		c.noise = noise * float(c.gear.noise)
		c.ev = float(tool.evidence) * float(c.gear.ev)
		c.timer = maxf(dur, 0.5)
		c["loud"] = c.noise
		c.started = true
		_lock(c, key)
		_log("%s setzt %s an %s an." % [c.name, tool.name, a.on])
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	evidence += c.ev
	if is_panel:
		panel.bypassed = true
		for s in sensors:
			s.active = false
		_log("Alarmpanel überbrückt. Mikrofone sind aus.")
	elif case_id != "":
		# Werkzeug entriegelt. Brecheisen bricht auf: dann ist die Vitrine auch offen.
		loot[case_id].locked = false
		if tool.destroys:
			loot[case_id].opened = true
			c["msg"] = "Vitrine aufgebrochen – jetzt offen"
			_log("%s: die Vitrine von %s ist aufgebrochen und offen." % [c.name, loot[case_id].name])
		else:
			c["msg"] = "Vitrine entriegelt – noch zu"
			_log("%s: die Vitrine von %s ist entriegelt." % [c.name, loot[case_id].name])
	elif door != null:
		door.locked = false
		if tool.destroys:
			door.destroyed = true
			open_cells[cell] = true
			c["msg"] = "Tür aufgebrochen – jetzt offen"
			_log("%s ist aufgebrochen und offen." % a.on)
		else:
			c["msg"] = "Tür entriegelt – noch zu"
			_log("%s ist entriegelt." % a.on)
	_noise(center(cell), c.noise)
	c.used[tool.type] = int(c.used.get(tool.type, 0)) + 1
	_next(c)


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
		if ftile(f) == "C":
			continue
		if not passable_f(f):
			return false
	return true


## Öffnen von Hand: Das Schloss muss offen (entriegelt) sein. Dauert OPEN_TIME.
func _do_open(c: Dictionary, a: Dictionary, dt: float) -> void:
	var cell := _cell_of(a, "on")
	var key := "obj:%d,%d" % [cell.x, cell.y]
	var case_id := _case_at(cell)
	var door: Variant = doors.get(cell, null)
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(cell)):
			_fail(c, "%s steht nicht vor %s. Erst davor gehen (in Blickrichtung)." % [c.name, a.on])
			return
		if door != null:
			if door.locked:
				_fail(c, "%s ist verschlossen. Erst entriegeln oder aufbrechen." % a.on)
				return
			if open_cells.has(cell):
				_fail(c, "%s ist schon offen." % a.on)
				return
		elif case_id != "":
			if loot[case_id].locked:
				_fail(c, "%s ist verschlossen. Erst entriegeln oder aufbrechen." % a.on)
				return
			if loot[case_id].opened:
				_fail(c, "%s ist schon offen." % a.on)
				return
		else:
			_fail(c, "An %s ist nichts zu öffnen." % a.on)
			return
		c.started = true
		_lock(c, key)
		c.timer = OPEN_TIME
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	if door != null:
		open_cells[cell] = true
		c["msg"] = "Tür offen"
		_log("%s öffnet %s." % [c.name, a.on])
	else:
		loot[case_id].opened = true
		c["msg"] = "Vitrine offen"
		_log("%s öffnet die Vitrine von %s." % [c.name, loot[case_id].name])
	_next(c)


## Wache ausschalten: Die Person muss neben der Wache stehen. Dauer hängt von der Kraft ab.
## Gelingt es nur, wenn die Wache noch keinen Alarm ausgelöst hat.
func _do_neutralize(c: Dictionary, a: Dictionary, dt: float) -> void:
	var key := "guard:%s" % a.get("guard", "")
	var g: Dictionary = {}
	for x in guards:
		if x.id == a.guard:
			g = x
	if g.is_empty() or g.state in ["OUT", "IDLE"]:
		_fail(c, "Die Wache ist nicht mehr da.")
		return
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, g.pos):
			_fail(c, "%s steht nicht vor %s." % [c.name, g.name])
			return
		if g.state == "ALARMED":
			_fail(c, "%s hat schon Alarm geschlagen. Zu spät." % g.name)
			return
		# Kampf der Wache gegen Kampf der Person (Original: tcGuyUsesTool, Kampf verkürzt die Zeit)
		var k := float(c.skills.get("FORCE", 1))
		var gk := float(g.get("kampf", 0))
		if gk > k + 25.0:
			_fail(c, "%s wehrt sich zu stark. Mit mehr Kampfsport ginge es." % g.name)
			return
		var stretch := 1.0 + maxf(0.0, gk - k) / 50.0
		c.started = true
		_lock(c, key)
		c["loud"] = 0.0 if a.get("method", "knock") == "chloroform" else 35.0
		if a.get("method", "knock") == "chloroform":
			c.timer = 4.0 * stretch
		else:
			c.timer = maxf(2.0, 6.0 * (1.0 - k / 150.0)) * stretch
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	var chloro: bool = a.get("method", "knock") == "chloroform"
	g.state = "OUT"
	g.path = []
	evidence += (3.0 if chloro else 6.0) * float(c.gear.ev)
	if not chloro:
		_noise(g.pos, 35.0)
	_log("%s schaltet %s aus (%s)." % [c.name, g.name, "Chloroform" if chloro else "Niederschlagen"])
	_next(c)


## Treppe: die Person steht auf dem Treppenfeld, braucht 8 s und ist danach auf der anderen Etage.
func _do_stairs(c: Dictionary, a: Dictionary, dt: float) -> void:
	var here := anchor_of(Vector2i(floori(c.pos.x), floori(c.pos.y)))
	if not stairs.has(here):
		_fail(c, "%s steht nicht an einer Treppe." % c.name)
		return
	if not c.started:
		c.started = true
		c.timer = STAIRS_TIME
		_log("%s steigt die Treppe." % c.name)
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	c.pos = center(stairs[here])
	c.path = []
	_log("%s ist auf der anderen Etage." % c.name)
	_next(c)


func _do_take(c: Dictionary, a: Dictionary, dt: float) -> void:
	var l: Dictionary = loot[a.loot]
	var key := "loot:%s" % a.loot
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(l.pos)):
			_fail(c, "%s steht nicht vor der Beute." % c.name)
			return
		if l.state != "ROOM":
			_fail(c, "%s ist schon weg." % l.name)
			return
		if not l.opened:
			_fail(c, "Die Vitrine von %s ist noch zu." % l.name)
			return
		var carried := 0.0
		for lid in c.carried:
			carried += float(loot[lid].weight)
		if carried + float(l.weight) > float(c.capacity):
			_fail(c, "%s (%d kg) passt nicht: %s trägt noch %d kg, Tragkraft %d kg." % [l.name, int(l.weight), c.name.split(" ")[0], int(float(c.capacity) - carried), int(c.capacity)])
			return
		c.started = true
		_lock(c, key)
		c.timer = LOOT_TIME
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	l.state = "CARRIED"
	l.carrier = c.id
	c.carried.append(l.id)
	c["msg"] = "%s genommen" % l.name
	_log("%s nimmt %s." % [c.name, l.name])
	_next(c)


func _update_car() -> void:
	if car.called and not car.present and time >= float(car.arrive_at):
		car.present = true
		_log("Der Fluchtwagen wartet am Ausgang.")


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


func _check_escape() -> void:
	## Der Wagen fährt erst los, wenn alle Einbrecherinnen am Wagen sitzen.
	if status != "RUNNING" or departed:
		return
	for c in crew:
		# Erst wenn jede Person ihren Plan abgeschlossen hat und am Wagen steht
		if not c.done or cheb(cell_of(c.pos), escape_cell) > 1:
			return
	departed = true
	_log("Alle sind am Wagen. Der Wagen fährt los (%.0f s Fahrt)." % car.eta)
	# Die Polizei darf nicht vor dem Wagen am Ausgang sein
	if countdown >= 0.0 and countdown <= float(car.eta):
		_end("GEFASST", "Die Polizei erreicht die Straße, bevor der Wagen wegkommt.")
		return
	# Verfolgung (wie Original tcCalcCarEscape): Die Polizei fährt los, sobald sie am Ausgang ist.
	# Sie holt den Wagen ein, wenn ihr Tempo reicht und die Strecke vorher noch nicht zu Ende ist.
	if countdown >= 0.0:
		var verdict := chase_result(car_v, police_v, countdown, escape_km)
		if verdict == "GEFASST":
			_end("GEFASST", "Die Polizei holt den Wagen auf der Flucht ein. Fluchtstrecke %.0f km." % escape_km)
			return
		if verdict == "KNAPP":
			_log("Knapp: Die Polizei bleibt dicht hinter dem Wagen.")
	var total := 0
	for c in crew:
		for lid in c.carried:
			loot[lid].state = "DELIVERED"
			total += int(loot[lid].value)
	payout = int(round(total * 0.6))
	if total == 0:
		_end("ABBRUCH", "Ohne Beute ist der Einbruch gescheitert.")
		return
	if alarm_active:
		_end("ENTKOMMEN_HEISS", "Das Team entkommt, aber die Polizei sucht bereits.")
	else:
		_end("ENTKOMMEN", "Das Team entkommt unbemerkt.")


## Abbruch (Funk): alle Einbrecherinnen gehen sofort zurück zum Wagen.
func abort() -> void:
	if status != "RUNNING":
		return
	_log("ABBRUCH per Funk: Alle sofort zurück zum Wagen.")
	for c in crew:
		_unlock_all(c)
		c.plan = [{"t": "MOVE", "to": "Fluchtwagen"}]
		c.idx = 0
		c.started = false
		c.path = []
		c.timer = 0.0
		c.done = false


# ---------------------------------------------------------------- Lärm & Wahrnehmung

func _noise(origin: Vector2, db: float) -> void:
	noise_log.append({"t": time, "x": cell_of(origin).x, "y": cell_of(origin).y, "db": db})
	for s in sensors:
		if not s.active:
			continue
		var sp := center(s.pos)
		var arr := db - origin.distance_to(sp) / SUB * DIST_DAMPING - blockers_between(origin, sp) * WALL_DAMPING
		if arr > s.threshold:
			_alarm(s.name, "GUARD", 0.0)
	for g in guards:
		if g.state in ["ALARMED", "IDLE", "OUT"]:
			continue
		var arr2 := db - origin.distance_to(g.pos) / SUB * DIST_DAMPING - blockers_between(origin, g.pos) * WALL_DAMPING
		if arr2 > g.hearing:
			_log("%s hört ein Geräusch." % g.name)
			_update_suspicion(g, (arr2 - g.hearing) * 2.5, cell_of(origin))


## Original (player.c, ACTION_CONTROL / dataappl.c tcGuardChecksObject): Ein Wächter, der ein Objekt kontrolliert,
## das entriegelt oder bearbeitet ist oder dessen Beute fehlt, schlägt sofort Alarm (lauter Alarm).
## Hier: alle Objekte in der Reichweite des Wächters (Sicht-Entfernung, ohne Wand dazwischen).
func _guard_checks_objects() -> void:
	for g in guards:
		if g.state in ["ALARMED", "IDLE", "OUT"]:
			continue
		var what := ""
		for p in doors:
			if not doors[p].locked and g.pos.distance_to(center(p)) / SUB <= float(g.vision) and blockers_between(g.pos, center(p)) == 0:
				what = doors[p].name
		for lid in loot_order:
			var l: Dictionary = loot[lid]
			if l.state != "ROOM" or not l.locked:
				if g.pos.distance_to(center(l.pos)) / SUB <= float(g.vision) and blockers_between(g.pos, center(l.pos)) == 0:
					what = l.name
		if what != "":
			g.state = "ALARMED"
			g.path = []
			_alarm(g.name, "GUARD", 0.0)
			_log("%s kontrolliert %s: Alarm." % [g.name, what])


func _vision(dt: float) -> void:
	for c0 in crew:
		c0.seen_now = false
	for g in guards:
		g.seen = false
		if g.state in ["ALARMED", "IDLE", "OUT"]:
			continue
		for c in crew:
			var d: float = g.pos.distance_to(c.pos) / SUB
			if d > g.vision:
				continue
			if blockers_between(g.pos, c.pos) > 0:
				continue
			var rate: float = SEE_RATE * (1.0 - d / g.vision) * float(c.gear.vis)
			g.seen = true
			c.seen_now = true
			c.seen_sec += dt
			seen_sec += dt
			_update_suspicion(g, rate * dt, cell_of(c.pos))
		if not g.seen:
			_update_suspicion(g, -DECAY * dt)


func _update_suspicion(g: Dictionary, amount: float, target_cell: Vector2i = Vector2i(-1, -1)) -> void:
	if g.state == "ALARMED" or g.state == "OUT":
		return
	g.suspicion = clampf(g.suspicion + amount, 0.0, 100.0)
	var s: float = g.suspicion
	if s <= 0.0:
		if g.state != "PATROL":
			_log("%s beruhigt sich." % g.name)
		g.state = "PATROL"
		g.inv_arrived = false
		return
	if s < 40.0:
		if g.state != "ALERT":
			_log("%s wird aufmerksam." % g.name)
		g.state = "ALERT"
		g.path = []
		return
	if s < 80.0:
		if g.state != "INVESTIGATE":
			_log("%s geht einer Spur nach." % g.name)
			g.inv_arrived = false
			g.path = []
		g.state = "INVESTIGATE"
		if target_cell.x >= 0:
			g.target = target_cell
		return
	g.state = "ALARMED"
	var kind := "PATROL" if g.type == "STREET" else "GUARD"
	_log("%s schlägt Alarm." % g.name)
	_alarm(g.name, kind, float(g.reaction))


func _move_guard(g: Dictionary, dt: float) -> void:
	var cur := cell_of(g.pos)
	match g.state:
		"PATROL":
			if g.dwell > 0.0:
				g.dwell -= dt
				return
			if g.path.is_empty():
				g.path = path_to(g.pos, g.route[g.wp])
				if g.path.is_empty():
					_next_wp(g)
					return
			if _walk(g, dt):
				_next_wp(g)
		"RESPOND":
			if cur == g.target and g.path.is_empty():
				g.state = "PATROL"
				g.wp = 0
				g.dwell = 0.0
				_log("%s erreicht das Gebäude und sucht es ab." % g.name)
				return
			if g.path.is_empty():
				g.path = path_to(g.pos, g.target)
				if g.path.is_empty():
					g.state = "PATROL"
					return
			_walk(g, dt)
		"INVESTIGATE":
			if not g.inv_arrived:
				if cur == g.target:
					g.inv_arrived = true
					g.inv_timer = INVESTIGATE_SEC
					return
				if g.path.is_empty():
					g.path = path_to(g.pos, g.target)
					if g.path.is_empty():
						g.inv_arrived = true
						g.inv_timer = INVESTIGATE_SEC
						return
				_walk(g, dt)
			else:
				g.inv_timer -= dt
				if g.inv_timer <= 0.0 and g.suspicion < 40.0:
					g.state = "PATROL"
					g.path = []
					g.dwell = 0.0
		_:
			pass


func _next_wp(g: Dictionary) -> void:
	g.wp = (g.wp + 1) % g.route.size()
	g.dwell = g.dwell_sec
	g.path = []


# ---------------------------------------------------------------- Ergebnis

func fence_heat() -> float:
	var heat := evidence * 0.8 + seen_sec * 0.1
	if alarm_active:
		heat += 15.0
	if status == "GEFASST":
		heat += 40.0
	return heat


func result() -> Dictionary:
	# Endstand jeder Person: Feld und Blickrichtung (für die Planung, damit sie weiß, wo jemand steht)
	var ends := {}
	for c in crew:
		ends[c.id] = {"cell": [cell_of(c.pos).x, cell_of(c.pos).y], "face": [face4(c.get("facing", Vector2(0, 1))).x, face4(c.get("facing", Vector2(0, 1))).y]}
	return {
		"crew_end": ends,
		"status": status,
		"reason": ended_reason,
		"payout": payout,
		"heat": fence_heat(),
		"time": time,
		"peak_loud": peak_loud,
		"max_volume": max_volume,
		"alarm": alarm_active,
		"log": log_lines,
		"loot_taken": _loot_names(true),
		"loot_missed": _loot_names(false),
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


## Schnelle Vorschau: läuft die Simulation ohne Anzeige bis zum Ende.
static func preview(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary) -> Dictionary:
	var s := Sim.create(target, team, plans, car_cfg)
	var guard := 0
	while s.status == "RUNNING" and guard < 20000:
		s.step(DT)
		guard += 1
	return s.result()


## Was den Blick stoppt: Wand, Fenster, geschlossene Tür, Kartenrand.
func blocks_sight(c: Vector2i) -> bool:
	return blocks_sight_f(center_i(c))


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


extends Node3D
## Ausführungsphase in 3D. Dieselbe Simulation wie in der Vorschau, nur sichtbar und in Echtzeit.

var main: Node
var args: Dictionary = {}

var sim: Sim
var cfg: Dictionary
var speed := 1.0
var paused := false
var finished := false
var _acc := 0.0

var _door_nodes := {}
var _case_lids := {}          # Vitrinen-Deckel (Zelle -> Scharnier), heben sich beim Öffnen
var _panel_led: MeshInstance3D = null  # Lampe am Alarmpanel
var _panel_on := false
var _floor_pick := "folgen"   # gezeigte Etage (id), "alle" oder "folgen" (Etage der laufenden Person)
var _follow_floor := 0        # zuletzt gefolgte Etage (Index)
var _cam: Camera3D
var _cam_home: Transform3D
var _static_floor := {}        # feste Teile des Gebäudes -> Etage (-1 = außen, immer sichtbar)
var _cam_mid := Vector2.ZERO
var _bx0 := 0.0                # Gebäude-Breite in Feldern (außerhalb: immer sichtbar)
var _bx1 := 0.0
var _paint_nodes := {}        # Gemälde an der Wand (Beute-Id -> Knoten)
var _panel_flap: Node3D = null  # Klappe am Alarmpanel (Steuerkasten): öffnet sich bei Überbrückung
var _spots: Array = []        # Scheinwerfer: leuchten bei Alarm
var _siren: MeshInstance3D = null  # Sirene: dreht sich und blinkt bei Alarm
var _drawer_nodes := {}   # Kassenschubladen (Zelle -> Knoten), fahren beim Öffnen heraus
var _drawer_pos := {}
var _safe_nodes := {}     # Tresortüren (Zelle -> Drehpunkt)
var _window_nodes := {}   # Glasscheiben der Schaufenster (Zelle -> Knoten)
var _broken := {}         # bereits zerbrochene Scheiben
var _shards: Array = []   # fallende Glassplitter {node, vel}
var _crew_nodes := {}
var _guard_nodes := {}
var _loot_nodes := {}
var _car_node: Node3D
var _cone_nodes := {}
var _ring_nodes := {}
var _sight_nodes := {}
var _cone_t := 0.0
var _layer: CanvasLayer
const STATE_COL3D := {
	"PATROL": Color(0.35, 0.85, 0.55),
	"RESPOND": Color(0.45, 0.72, 1.0),
	"ALERT": Color(0.98, 0.85, 0.3),
	"INVESTIGATE": Color(1.0, 0.6, 0.25),
	"ALARMED": Color(1.0, 0.28, 0.28),
}
var _status: Label
var _clock: Label
var _log: RichTextLabel
var _result_btn: Button
var _pause_btn: Button

const WALL_H := 2.6   # 1 Feld = 1 m: Wandhöhe ca. 2,6 m
const LEVEL_H := 3.2  # Höhe einer Etage (Wand plus Decke)
const WALL_T := 0.25  # sichtbare Wandstärke in 3D (die Kollision bleibt beim Originalmaß)
const CREW_COL := {"mira": Color(0.4, 0.8, 1.0), "ilja": Color(0.6, 1.0, 0.5), "teo": Color(1.0, 0.7, 0.3), "rosa": Color(1.0, 0.5, 0.8)}


func _ready() -> void:
	cfg = args.config
	sim = Sim.create(cfg.target, cfg.team, cfg.plans, cfg.car)
	_build_world()
	_build_ui()
	_sync()
	_update_cones()


# ---------------------------------------------------------------- Welt

var _mat_cache := {}


func _mat(col: Color, rough := 0.85, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [col.to_html(), rough, metal, emit]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	# Cel-Shading: klare Lichtstufen statt weicher Verläufe, ohne Glanzlichter
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mat_cache[key] = m
	return m


var _outline_mat: StandardMaterial3D = null


## Dunkler Umriss für den Cel-Look: eine etwas größere Hülle, deren Vorderseiten nicht gezeichnet werden.
func _outline(parent: Node3D, mesh: Mesh, grow: float, pos: Vector3, size: Vector3) -> void:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.albedo_color = Color(0.04, 0.05, 0.08)
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _outline_mat
	mi.scale = Vector3((size.x + grow) / maxf(size.x, 0.001), (size.y + grow) / maxf(size.y, 0.001), (size.z + grow) / maxf(size.z, 0.001))
	mi.position = pos
	parent.add_child(mi)


func _box(size: Vector3, pos: Vector3, col: Color, rough := 0.85, metal := 0.0, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, rough, metal, emit)
	mi.position = pos
	add_child(mi)
	# Flache Bodenplatten ohne Umriss, sonst entsteht ein Liniengitter auf dem Boden
	if size.y > 0.3:
		_outline(self, bm, 0.1, pos, size)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, col: Color, rough := 0.5, metal := 0.0, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _mat(col, rough, metal, emit)
	mi.position = pos
	add_child(mi)
	_outline(self, cm, 0.1, pos, Vector3(radius * 2.0, height, radius * 2.0))
	return mi


var _lamps: Array = []


func _lamp(pos: Vector3, col: Color, energy: float, rng := 6.0) -> void:
	var l := OmniLight3D.new()
	_lamps.append(l)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.position = pos
	add_child(l)


## Liegt die Zelle höchstens eine Zelle neben einem Gebäudeteil?
func _near_building(rows: Array, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if ny < 0 or ny >= rows.size():
				continue
			var r: String = rows[ny]
			if nx < 0 or nx >= r.length():
				continue
			if r.substr(nx, 1) != "o":
				return true
	return false


func _build_world() -> void:
	# Nachtstimmung mit warmem Museumslicht, Bloom und Schatten
	var env := Environment.new()
	# Hintergrundbild hinter der 3D-Szene (CanvasLayer ganz unten), die Szene selbst ist transparent
	env.background_mode = Environment.BG_CANVAS
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg_layer.add_child(UI.backdrop("res://assets/art/bg_ausfuehrung.jpg"))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.44, 0.52)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_white = 2.5
	env.glow_enabled = false
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = false  # Cel-Look: keine weichen Schatten in den Ecken
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Mondlicht von oben-links, kühl und schwach
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, 28, 0)
	moon.light_color = Color(0.7, 0.8, 1.0)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	add_child(moon)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	_cam = cam
	# Kamera auf das Gebäude ausrichten: Mitte und Größe aus dem Grundriss (in Feldern)
	var box := _building_box(cfg.target)
	var ext := box.size
	var aspect := 1.78
	var dz_cam := 0.0
	if cfg.target.get("floors", []).size() > 1:
		dz_cam = float(cfg.target.floors[1].rows[0]) - float(cfg.target.floors[0].rows[0])
	ext.y -= dz_cam
	cam.size = clampf(maxf(ext.y * 1.6, ext.x * 1.6 / aspect), 10.0, 40.0)
	cam.make_current()

	var rows: Array = cfg.target.map
	var fine_on: bool = cfg.target.has("fine")
	var h := rows.size()
	var wdt := String(rows[0]).length()
	for y in range(h):
		var row: String = rows[y]
		for x in range(row.length()):
			var t := row.substr(x, 1)
			# Mit feinem Grundriss kommen Wände, Türen und Vitrinen aus den Rechtecken (unten), hier nur der Außenbereich
			if fine_on and t != "o":
				continue
			var p := Vector3(x + 0.5, 0, y + 0.5)
			var tone := 0.97 + 0.04 * sin(float(x * 7 + y * 13))
			match t:
				"W":
					_box(Vector3(1, WALL_H, 1), p + Vector3(0, WALL_H * 0.5, 0), Color(0.2, 0.24, 0.34) * tone, 0.9)
					_box(Vector3(1.04, 0.12, 1.04), p + Vector3(0, WALL_H + 0.06, 0), Color(0.42, 0.47, 0.6), 0.5)
				"F":
					_box(Vector3(1, WALL_H, 1), p + Vector3(0, WALL_H * 0.5, 0), Color(0.2, 0.24, 0.34), 0.9)
					_box(Vector3(0.82, WALL_H - 0.9, 0.5), p + Vector3(0, 0.45 + (WALL_H - 0.9) * 0.5, 0), Color(0.45, 0.8, 1.0), 0.05, 0.0, 0.5)
					_box(Vector3(0.9, 0.08, 0.6), p + Vector3(0, 0.45, 0), Color(0.5, 0.45, 0.4), 0.6)
					_box(Vector3(0.9, 0.08, 0.6), p + Vector3(0, WALL_H - 0.4, 0), Color(0.5, 0.45, 0.4), 0.6)
				"D":
					_box(Vector3(1, 0.1, 1), p + Vector3(0, 0.05, 0), Color(0.5, 0.42, 0.33) * tone, 0.6)
					_door_nodes[Vector2i(x, y)] = _box(Vector3(0.22, 2.1, 1.0), p + Vector3(0, 1.05, 0), Color(0.42, 0.26, 0.14), 0.5)
					_cyl(0.05, 0.05, p + Vector3(0.14, 1.05, 0.3), Color(0.9, 0.75, 0.35), 0.2, 1.0).rotation_degrees.z = 90
				"o":
					# Außenbereich: nur ein schmaler Streifen direkt am Gebäude, der Rest ist der Hintergrund
					if _near_building(rows, x, y):
						var on_street := x <= 1 or x >= wdt - 2 or y <= 1 or y >= h - 2
						var gcol := Color(0.16, 0.2, 0.27) if on_street else Color(0.13, 0.19, 0.25)
						_box(Vector3(1, 0.1, 1), p + Vector3(0, 0.05, 0), gcol * tone, 0.95)
				_:
					var checker := Color(0.8, 0.84, 0.9) if (x + y) % 2 == 0 else Color(0.72, 0.77, 0.84)
					_box(Vector3(1, 0.1, 1), p + Vector3(0, 0.05, 0), checker * tone, 0.22, 0.0)

	# Straßenlaternen an den Ecken des Gebäudekomplexes
	var lamp_box := _building_box(cfg.target)
	var lamp_corners := [
		Vector3(lamp_box.position.x + 0.5, 0, lamp_box.position.y + 0.5),
		Vector3(lamp_box.end.x - 0.5, 0, lamp_box.position.y + 0.5),
		Vector3(lamp_box.end.x - 0.5, 0, lamp_box.end.y - 0.5),
		Vector3(lamp_box.position.x + 0.5, 0, lamp_box.end.y - 0.5),
	]
	for lp in lamp_corners:
		_cyl(0.07, 3.0, lp + Vector3(0, 1.5, 0), Color(0.1, 0.1, 0.12), 0.5, 0.6)
		_cyl(0.2, 0.2, lp + Vector3(0, 3.1, 0), Color(1.0, 0.85, 0.55), 0.3, 0.0, 3.0)
		_lamp(lp + Vector3(0, 3.0, 0), Color(1.0, 0.82, 0.5), 1.4, 7.0)

	# Warme Deckenlichter über den Räumen
	for room in cfg.target.get("rooms", []):
		_lamp(Vector3(room.pos[0] + 0.5, 2.8, room.pos[1] + 0.5), Color(1.0, 0.86, 0.6), 1.1, 6.0)

	if fine_on:
		_build_fine(Sim.fine_spec(cfg.target))
	_build_extras()
	# Beute: mit feinem Grundriss ist die Vitrine selbst ein Rechteck, sonst ein Sockel mit Absperrung
	for l in cfg.target.loot:
		var lp := Vector3(l.pos[0] + 0.5, 0, l.pos[1] + 0.5)
		if not fine_on:
			_box(Vector3(0.7, 0.9, 0.7), lp + Vector3(0, 0.45, 0), Color(0.93, 0.9, 0.86), 0.25)
		var n := _box(Vector3(0.3, 0.3, 0.3), lp + Vector3(0, 1.05, 0), Color(1.0, 0.82, 0.25), 0.2, 1.0, 1.4)
		n.position = _L(n.position)
		_loot_nodes[l.id] = n
		if not fine_on:
			for off in [Vector3(0.6, 0, 0.6), Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, -0.6), Vector3(-0.6, 0, -0.6)]:
				_cyl(0.04, 0.9, lp + off + Vector3(0, 0.45, 0), Color(0.85, 0.7, 0.3), 0.2, 1.0)

	# Gebäude-Breite (Felder) für die Etagensicht
	_bx0 = 1e9
	_bx1 = -1e9
	var mrows: Array = cfg.target.map
	for my in range(mrows.size()):
		var mrow: String = mrows[my]
		for mx in range(mrow.length()):
			if mrow.substr(mx, 1) != "o":
				_bx0 = minf(_bx0, float(mx))
				_bx1 = maxf(_bx1, float(mx + 1))
	# Feste Teile des Gebäudes der Etage zuordnen und die oberen Etagen anheben (gestapelter Grundriss -> Höhe)
	for ch in get_children():
		if not (ch is Node3D) or ch is Light3D or ch is Camera3D or _loot_nodes.values().has(ch) or _paint_nodes.values().has(ch) or ch == _siren:
			continue
		var fi := -1
		var cp: Vector3 = (ch as Node3D).position
		if cfg.target.get("floors", []).size() > 0 and cp.x >= _bx0 and cp.x <= _bx1 and not (ch is MeshInstance3D and _is_ground(ch)):
			fi = _floor_idx_z(cp.z)
		_static_floor[ch] = fi
		if fi > 0:
			(ch as Node3D).position = cp + _lift_for_floor(fi)
	for l in _lamps:
		var lp3: Vector3 = l.position
		if cfg.target.get("floors", []).size() > 0 and lp3.x >= _bx0 and lp3.x <= _bx1:
			var lf := _floor_idx_z(lp3.z)
			if lf > 0:
				l.position = lp3 + _lift_for_floor(lf)
	_cam_mid = Vector2(_building_box(cfg.target).get_center().x, _building_box(cfg.target).get_center().y)
	var bb := _building_box(cfg.target)
	if cfg.target.get("floors", []).size() > 1:
		var dz := float(cfg.target.floors[1].rows[0]) - float(cfg.target.floors[0].rows[0])
		_cam_mid = Vector2(bb.get_center().x, (bb.position.y + bb.end.y - dz) * 0.5)
	_cam.position = Vector3(_cam_mid.x, 19, _cam_mid.y + 20.0)
	_cam.look_at(Vector3(_cam_mid.x, 0, _cam_mid.y), Vector3.UP)
	_cam_home = _cam.transform

	# Team und Wachen als Pixelfiguren (Sprites), die zur Kamera ausgerichtet sind
	for c in cfg.team:
		var node := _figure("crew_" + c.id)
		add_child(node)
		_crew_nodes[c.id] = node
	for g in sim.guards:
		var key := "guard_street" if g.type == "STREET" else "guard_indoor"
		var gnode := _figure(key)
		gnode.visible = false
		add_child(gnode)
		_guard_nodes[g.id] = gnode
	for g in sim.guards:
		var cm := MeshInstance3D.new()
		cm.material_override = _cone_mat(Color(0.5, 0.5, 0.5))
		add_child(cm)
		_cone_nodes[g.id] = cm
		var ring := MeshInstance3D.new()
		add_child(ring)
		_ring_nodes[g.id] = ring
		for c in cfg.team:
			var line := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 0.06, 1.0)
			line.mesh = bm
			line.material_override = _mat(Color(1.0, 0.88, 0.25), 0.3, 0.0, 2.0)
			line.visible = false
			add_child(line)
			_sight_nodes[g.id + "|" + c.id] = line

	# Fluchtwagen mit Scheinwerfern am Ausgang
	var ex := Sim._v2i(cfg.target.points.Fluchtwagen)
	var car := Node3D.new()
	# Mittelklasse-Limousine, 4,2 m lang, 1,6 m breit (1 Feld = 1 m), Front in +x
	_box_child(car, Vector3(4.2, 0.7, 1.6), Vector3(0, 0.6, 0), Color(0.28, 0.42, 0.56), 0.4, 0.0)
	_box_child(car, Vector3(2.2, 0.6, 1.45), Vector3(-0.3, 1.25, 0), Color(0.2, 0.3, 0.4), 0.35, 0.0)
	for wp in [Vector3(1.35, 0.35, 0.8), Vector3(1.35, 0.35, -0.8), Vector3(-1.35, 0.35, 0.8), Vector3(-1.35, 0.35, -0.8)]:
		var wheel := MeshInstance3D.new()
		var wc := CylinderMesh.new()
		wc.top_radius = 0.35
		wc.bottom_radius = 0.35
		wc.height = 0.18
		wheel.mesh = wc
		wheel.material_override = _mat(Color(0.08, 0.08, 0.09), 0.9)
		wheel.position = wp
		wheel.rotation_degrees.x = 90
		car.add_child(wheel)
	_box_child(car, Vector3(0.12, 0.18, 0.4), Vector3(2.1, 0.7, 0.5), Color(1, 1, 0.9), 0.1, 0.0, 3.0)
	_box_child(car, Vector3(0.12, 0.18, 0.4), Vector3(2.1, 0.7, -0.5), Color(1, 1, 0.9), 0.1, 0.0, 3.0)
	# Der Wagen steht nach außen versetzt, damit die Figuren davor stehen und nicht im Blech verschwinden
	var center := Vector2(float(cfg.target.map[0].length()) * 0.5, float(cfg.target.map.size()) * 0.5)
	var out := Vector2(signf(float(ex.x) - center.x), signf(float(ex.y) - center.y))
	if absf(out.x) >= absf(out.y):
		out = Vector2(out.x, 0.0)
	else:
		out = Vector2(0.0, out.y)
	# Der Wagen steht außerhalb des Gebäudes, Front zum Gebäude
	car.position = Vector3(ex.x + 0.5 + out.x * 2.5, 0, ex.y + 0.5 + out.y * 2.5)
	if absf(out.y) > 0.0:
		car.rotation_degrees.y = 90.0
	if out.x > 0.0:
		car.rotation_degrees.y = 180.0
	add_child(car)
	_car_node = car
	_car_node.visible = false


## Gebäude aus dem feinen Grundriss: jedes Rechteck wird ein Körper (Maße in Feldern).
## Umriss des Gebäudes in Feldkoordinaten: aus dem feinen Grundriss, sonst aus der Karte.
func _building_box(target: Dictionary) -> Rect2:
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	if target.has("fine"):
		var sb := float(Sim.SUB)
		for r in Sim.fine_spec(target).paint:
			if String(r[4]) == ".":
				continue
			mn = Vector2(minf(mn.x, float(r[0]) / sb), minf(mn.y, float(r[1]) / sb))
			mx = Vector2(maxf(mx.x, float(r[2]) / sb), maxf(mx.y, float(r[3]) / sb))
	else:
		var rows: Array = target.map
		for y in range(rows.size()):
			var row: String = rows[y]
			for x in range(row.length()):
				if row.substr(x, 1) != "o":
					mn = Vector2(minf(mn.x, x), minf(mn.y, y))
					mx = Vector2(maxf(mx.x, x + 1.0), maxf(mx.y, y + 1.0))
	if mn.x > mx.x:
		return Rect2(0, 0, 20, 12)
	# Mit Rand um das Gebäude
	return Rect2(mn - Vector2(1.5, 1.5), (mx - mn) + Vector2(3.0, 3.0))


## Stahltüren grau, Alarmpanel mit Lampe an der Wand des Raumes.
func _build_extras() -> void:
	# Gemälde an der Wand: verschwindet, sobald es abgenommen ist (siehe _sync)
	for l in cfg.target.loot:
		if bool(l.get("wall", false)):
			var pp := Vector3(l.pos[0] + 0.5, 0, l.pos[1] + 0.5)
			_paint_nodes[l.id] = _box(Vector3(0.08, 0.8, 0.62), Vector3(pp.x - 0.46, 1.5, pp.z), Color(0.7, 0.55, 0.2), 0.3, 0.6)
			_paint_nodes[l.id].position = _L(_paint_nodes[l.id].position)
	for cell in sim.doors:
		if str(sim.doors[cell].get("kind", "")) == "stahl" and _door_nodes.has(cell):
			var leaf := (_door_nodes[cell] as Node3D).get_child(0) as MeshInstance3D
			leaf.material_override = _mat(Color(0.5, 0.52, 0.56), 0.35, 0.8)
	if sim.panel.has("pos"):
		var pc: Vector2i = sim.panel.pos
		var pp := Vector3(pc.x + 0.5, 0, pc.y + 0.5)
		_box(Vector3(0.5, 0.9, 0.16), pp + Vector3(0, 0.45, 0), Color(0.3, 0.32, 0.36), 0.4, 0.3)
		_panel_led = _box(Vector3(0.12, 0.12, 0.05), pp + Vector3(0, 0.75, -0.1), Color(0.2, 0.9, 0.3), 0.3, 0.0, 0.2)
		# Steuerkasten-Klappe vor dem Panel: an der Unterkante gelenkt
		_panel_flap = Node3D.new()
		_panel_flap.position = Vector3(pp.x, 0.0, pp.z - 0.09)
		add_child(_panel_flap)
		var flap := MeshInstance3D.new()
		var fbm := BoxMesh.new()
		fbm.size = Vector3(0.44, 0.7, 0.03)
		flap.mesh = fbm
		flap.material_override = _mat(Color(0.5, 0.52, 0.56), 0.4, 0.5)
		flap.position = Vector3(0, 0.45, 0)
		_panel_flap.add_child(flap)
	# Scheinwerfer (Testgebäude: am Eingang), leuchten bei Alarm
	for p in cfg.target.get("scheinwerfer", []):
		var sp := SpotLight3D.new()
		sp.position = _L(Vector3(p[0] + 0.5, 3.2, p[1] + 0.5))
		sp.rotation_degrees = Vector3(-80, 0, 0)
		sp.spot_range = 14.0
		sp.spot_angle = 32.0
		sp.light_energy = 0.0
		sp.light_color = Color(1.0, 0.95, 0.8)
		add_child(sp)
		_spots.append(sp)
	# Sirene auf dem Dach (Alarmanlage): blinkt und dreht sich bei Alarm
	if cfg.target.has("sirene"):
		var sr: Array = cfg.target.sirene
		_siren = _box(Vector3(0.4, 0.22, 0.4), Vector3(sr[0] + 0.5, 2.6, sr[1] + 0.5), Color(0.9, 0.2, 0.2), 0.3, 0.0, 0.0)
		_siren.position = _L(_siren.position)


func _build_fine(spec: Dictionary) -> void:
	_build_walls(spec)
	var sb := float(Sim.SUB)
	for r in spec.paint:
		var x0 := float(r[0]) / sb
		var y0 := float(r[1]) / sb
		var x1 := float(r[2]) / sb
		var y1 := float(r[3]) / sb
		var p := Vector3((x0 + x1) * 0.5, 0, (y0 + y1) * 0.5)
		var sz := Vector3(x1 - x0, 0.1, y1 - y0)
		match String(r[4]):
			".":
				_box(Vector3(sz.x, 0.1, sz.z), p + Vector3(0, 0.05, 0), Color(0.8, 0.84, 0.9) * 0.97, 0.22)
			"W":
				pass  # Wände werden unten als durchgehende Stücke gebaut (_build_walls)
			"F":
				var fsz := _wall_size(sz)
				var anc_w := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				_box(Vector3(fsz.x, WALL_H, fsz.z), p + Vector3(0, WALL_H * 0.5, 0), Color(0.2, 0.24, 0.34), 0.9)
				# Glasscheibe: zerbricht beim Öffnen (siehe _sync)
				_window_nodes[anc_w] = _box(Vector3(fsz.x * 0.6, WALL_H - 0.9, fsz.z * 0.6), p + Vector3(0, 0.45 + (WALL_H - 0.9) * 0.5, 0), Color(0.45, 0.8, 1.0), 0.05, 0.0, 0.5)
			"D":
				var anc := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				var dsz := _wall_size(sz)
				# Türblatt 1,0 m breit, in der Öffnung
				if dsz.x > dsz.z:
					dsz.x = 1.0
				else:
					dsz.z = 1.0
				# Türblatt ohne Umriss und etwas dünner als die Öffnung: sonst flimmert es gestrichelt (Z-Fighting mit der Wand)
				var leaf_t := minf(dsz.x, dsz.z) if minf(dsz.x, dsz.z) < 0.5 else 0.12
				var leaf_size := Vector3(dsz.x * 0.98, 2.1, dsz.z * 0.98)
				if dsz.x > dsz.z:
					leaf_size.z = leaf_t
				else:
					leaf_size.x = leaf_t
				# Drehpunkt an der Angel: das Blatt schwingt beim Öffnen um 90° auf (wie im Original)
				var hinge := Node3D.new()
				var along_x: bool = dsz.x > dsz.z
				hinge.position = p + Vector3(-0.5 if along_x else 0.0, 0.0, 0.0 if along_x else -0.5)
				add_child(hinge)
				var leaf := MeshInstance3D.new()
				var lbm := BoxMesh.new()
				lbm.size = leaf_size
				leaf.mesh = lbm
				leaf.material_override = _mat(Color(0.42, 0.26, 0.14), 0.5)
				leaf.position = Vector3((0.5 if along_x else 0.0), 1.05, (0.0 if along_x else 0.5))
				hinge.add_child(leaf)
				_door_nodes[anc] = hinge
			"C":
				_box(Vector3(sz.x, 1.0, sz.z), p + Vector3(0, 0.5, 0), Color(0.93, 0.9, 0.86), 0.25)
				# Glasdeckel: an der Rückkante gelenkt, hebt sich beim Öffnen der Vitrine (siehe _sync)
				var anc_c := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				var hinge_c := Node3D.new()
				hinge_c.position = Vector3(p.x, 1.0, p.z - sz.z * 0.5)
				add_child(hinge_c)
				var lid := MeshInstance3D.new()
				var lbm := BoxMesh.new()
				lbm.size = Vector3(sz.x, 0.05, sz.z)
				lid.mesh = lbm
				lid.material_override = _mat(Color(0.72, 0.86, 0.95), 0.05, 0.0, 0.15)
				lid.position = Vector3(0, 0.025, sz.z * 0.5)
				hinge_c.add_child(lid)
				_case_lids[anc_c] = hinge_c
			"S":
				_box(Vector3(sz.x, 1.6, sz.z), p + Vector3(0, 0.8, 0), Color(0.5, 0.5, 0.56), 0.4, 0.6)
				# Tresortür auf der Vorderseite: Drehpunkt am linken Rand, schwingt beim Öffnen auf
				var anc_s := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				var hinge_s := Node3D.new()
				hinge_s.position = Vector3(p.x - sz.x * 0.5 + 0.02, 0.0, p.z + sz.z * 0.5)
				add_child(hinge_s)
				var door_s := MeshInstance3D.new()
				var dbm := BoxMesh.new()
				dbm.size = Vector3(sz.x * 0.9, 1.4, 0.06)
				door_s.mesh = dbm
				door_s.material_override = _mat(Color(0.36, 0.36, 0.42), 0.4, 0.6)
				door_s.position = Vector3(sz.x * 0.45, 0.75, 0.03)
				hinge_s.add_child(door_s)
				_safe_nodes[anc_s] = hinge_s
			"K":
				# Kassenschublade: fährt beim Öffnen heraus (siehe _sync)
				var anc_k := Vector2i(floori((float(r[0]) + float(r[2])) * 0.5 / Sim.SUB), floori((float(r[1]) + float(r[3])) * 0.5 / Sim.SUB))
				_drawer_nodes[anc_k] = _box(Vector3(0.45, 0.9, 0.45), p + Vector3(0, 0.45 + 0.45, 0), Color(0.85, 0.2, 0.2), 0.4)


## Wände als durchgehende Stücke entlang der Mittellinie. Gleich liegende Rechtecke werden zusammengefasst,
## Türöffnungen bleiben frei. So entstehen keine Blöcke, Pfosten oder Lücken an den Übergängen.
func _build_walls(spec: Dictionary) -> void:
	var sb := float(Sim.SUB)
	var hz := {}
	var vt := {}
	var openings := []
	for r in spec.paint:
		var x0 := float(r[0]) / sb
		var y0 := float(r[1]) / sb
		var x1 := float(r[2]) / sb
		var y1 := float(r[3]) / sb
		var code := String(r[4])
		if code == "W":
			if x1 - x0 >= y1 - y0:
				_add_run(hz, roundi((y0 + y1) * 50.0), x0, x1)
			else:
				_add_run(vt, roundi((x0 + x1) * 50.0), y0, y1)
		elif code == "D":
			openings.append([x0, y0, x1, y1])
	var col := Color(0.2, 0.24, 0.34)
	var cap := Color(0.42, 0.47, 0.6)
	for key in hz:
		var cy: float = key / 100.0
		var runs := _merge_runs(hz[key])
		for o in openings:
			if absf((o[1] + o[3]) * 0.5 - cy) < 0.01 and o[2] - o[0] >= o[3] - o[1]:
				runs = _cut_runs(runs, o[0], o[2])
		for iv in runs:
			var ln: float = iv[1] - iv[0] + WALL_T
			var cx: float = (iv[0] + iv[1]) * 0.5
			_box(Vector3(ln, WALL_H, WALL_T), Vector3(cx, WALL_H * 0.5, cy), col, 0.9)
			_box(Vector3(ln + 0.02, 0.1, WALL_T + 0.02), Vector3(cx, WALL_H + 0.05, cy), cap, 0.5)
	for key in vt:
		var cx2: float = key / 100.0
		var runs2 := _merge_runs(vt[key])
		for o in openings:
			if absf((o[0] + o[2]) * 0.5 - cx2) < 0.01 and o[3] - o[1] > o[2] - o[0]:
				runs2 = _cut_runs(runs2, o[1], o[3])
		for iv in runs2:
			var ln2: float = iv[1] - iv[0] + WALL_T
			var cy2: float = (iv[0] + iv[1]) * 0.5
			_box(Vector3(WALL_T, WALL_H, ln2), Vector3(cx2, WALL_H * 0.5, cy2), col, 0.9)
			_box(Vector3(WALL_T + 0.02, 0.1, ln2 + 0.02), Vector3(cx2, WALL_H + 0.05, cy2), cap, 0.5)


func _add_run(lines: Dictionary, key: int, a: float, b: float) -> void:
	var arr: Array = lines.get(key, [])
	arr.append([a, b])
	lines[key] = arr


func _merge_runs(arr: Array) -> Array:
	arr.sort_custom(func(p, q): return p[0] < q[0])
	var out: Array = []
	for iv in arr:
		if out.size() > 0 and iv[0] <= out[-1][1] + 0.01:
			out[-1][1] = maxf(out[-1][1], iv[1])
		else:
			out.append([iv[0], iv[1]])
	return out


func _cut_runs(arr: Array, a: float, b: float) -> Array:
	var out: Array = []
	for iv in arr:
		if iv[1] <= a or iv[0] >= b:
			out.append(iv)
			continue
		if iv[0] < a:
			out.append([iv[0], a])
		if iv[1] > b:
			out.append([b, iv[1]])
	return out


## Sichtbare Wand: die lange Seite des Rechtecks, WALL_T dick (die Kollisionsbox bleibt das Originalmaß).
func _wall_size(sz: Vector3) -> Vector3:
	if sz.x >= sz.z:
		return Vector3(sz.x, 0.1, WALL_T)
	return Vector3(WALL_T, 0.1, sz.z)


func _box_child(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rough := 0.85, metal := 0.0, emit := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col, rough, metal, emit)
	mi.position = pos
	parent.add_child(mi)
	_outline(parent, bm, 0.1, pos, size)


var _tex := {}
const FIG_H := 1.8   # 1 Feld = 1 m: Person ca. 1,8 m


func _tex_for(key: String, pose: String) -> Texture2D:
	var k := "%s_%s" % [key, pose]
	if not _tex.has(k):
		var path := "res://assets/sprites/%s.png" % k
		if ResourceLoader.exists(path):
			_tex[k] = load(path)
		else:
			# Fehlt ein Sprite, bleibt die Person trotzdem sichtbar (Ersatzfigur statt unsichtbar)
			push_warning("Sprite fehlt: %s" % path)
			_tex[k] = load("res://assets/sprites/guard_indoor_%s.png" % pose)
	return _tex[k]


## Pixelfigur als Sprite. Steht mit den Füßen auf dem Boden und dreht sich zur Kamera.
func _figure(key: String) -> Node3D:
	var root := Node3D.new()
	var spr := Sprite3D.new()
	spr.name = "Sprite"
	spr.texture = _tex_for(key, "idle")
	spr.pixel_size = FIG_H / 96.0
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.position = Vector3(0, FIG_H * 0.5, 0)
	root.add_child(spr)
	root.set_meta("key", key)
	root.set_meta("last", Vector3.ZERO)
	root.set_meta("dir", Vector2(0, 1))
	var lbl := Label3D.new()
	lbl.name = "Name"
	lbl.pixel_size = 0.01
	lbl.font_size = 34
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, FIG_H + 0.35, 0)
	lbl.text = ""
	root.add_child(lbl)
	return root


## Schrittanimation: wechselt die Gehstellung, solange sich die Figur bewegt.
func _animate_figure(node: Node3D, moving: bool) -> void:
	## Ansicht nach Blickrichtung: links/rechts Seite, nach oben Rücken, nach unten Vorderseite.
	## Im Stehen bleibt die zuletzt eingenommene Blickrichtung.
	var spr: Sprite3D = node.get_node("Sprite")
	var key: String = node.get_meta("key")
	var dir: Vector2 = node.get_meta("dir", Vector2(0, 1))
	var pose := "idle"
	var t := Time.get_ticks_msec() / 1000.0
	if moving:
		pose = ["walk1", "walk2", "walk3", "walk4"][int(t * 8.0) % 4]
		# Auf und ab beim Gehen, leichtes Atmen im Stehen
		spr.position.y = FIG_H * 0.5 + 0.05 * absf(sin(t * 11.0))
	else:
		spr.position.y = FIG_H * 0.5 + 0.012 * sin(t * 2.0 + float(node.get_instance_id() % 7))
	if absf(dir.x) >= absf(dir.y):
		spr.texture = _tex_for(key + "_side", pose)
		spr.flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		spr.texture = _tex_for(key + "_back", pose)
		spr.flip_h = false
	else:
		spr.texture = _tex_for(key, pose)
		spr.flip_h = false


func _figure_moved(node: Node3D) -> bool:
	var last: Vector3 = node.get_meta("last")
	var delta := node.position - last
	var moved := delta.length() > 0.001
	if moved:
		node.set_meta("dir", Vector2(delta.x, delta.z).normalized())
	node.set_meta("last", node.position)
	return moved


## Laufende Aktion einer Person (TOOL, OPEN, TAKE) oder "".
func _current_act(c: Dictionary) -> String:
	if c.get("started", false) and c.idx < c.plan.size():
		return str(c.plan[c.idx].t)
	return ""


## Zeigt, was die Person gerade tut: Werkzeug (Zittern am Schloss), Öffnen (Oberkörper), Aufnehmen (Bücken).
func _animate_action(node: Node3D, act: String) -> void:
	var spr: Sprite3D = node.get_node("Sprite")
	var t := Time.get_ticks_msec() / 1000.0
	match act:
		"TOOL":
			spr.rotation.z = sin(t * 18.0) * 0.08
			spr.scale = Vector3.ONE
		"OPEN":
			spr.rotation.z = sin(t * 4.0) * 0.04
			spr.scale = Vector3.ONE
		"TAKE":
			spr.rotation.z = 0.0
			spr.scale = Vector3(1.0, 0.9 + 0.1 * absf(cos(t * 3.0)), 1.0)
		_:
			spr.rotation.z = 0.0
			spr.scale = Vector3.ONE


func _sync() -> void:
	_sync_body()
	_apply_floor_view()


## Etagen: nur die gewählte Etage zeigen. Die Zuordnung kommt aus der Höhe (Zeile der Karte).
func _floor_idx_z(z: float) -> int:
	var fl: Array = cfg.target.get("floors", [])
	for i in range(fl.size()):
		if z >= float(fl[i].rows[0]) and z < float(fl[i].rows[1]):
			return i
	return 0


func _floor_index_by_id(id: String) -> int:
	var fl: Array = cfg.target.get("floors", [])
	for i in range(fl.size()):
		if str(fl[i].id) == id:
			return i
	return -1


func _is_ground(n: MeshInstance3D) -> bool:
	## Große Flächen (Boden, Straße) bleiben immer sichtbar.
	var sz: Vector3 = n.get_aabb().size
	return sz.x > 30.0 or sz.z > 30.0


func _on_floor_pick(id: String) -> void:
	_floor_pick = id
	if id == "alle":
		_cam.transform = _cam_home
		return
	if id == "folgen":
		_move_cam_to_floor(_follow_floor)
		return
	_move_cam_to_floor(_floor_index_by_id(id))


func _move_cam_to_floor(idx: int) -> void:
	var fl: Dictionary = cfg.target.floors[idx]
	var zc := (float(fl.rows[0]) + float(fl.rows[1])) * 0.5 - (float(fl.rows[0]) - float(cfg.target.floors[0].rows[0]))
	var y := float(idx) * LEVEL_H
	_cam.position = Vector3(_cam_mid.x, 19.0 + y, zc + 20.0)
	_cam.look_at(Vector3(_cam_mid.x, y, zc), Vector3.UP)

func _followed_floor() -> int:
	for c in sim.crew:
		if not c.path.is_empty() and not c.done:
			var y := float(c.pos.y) / float(Sim.SUB)
			return _floor_idx_z(y + 0.5)
	return _follow_floor


func _lift_for_floor(i: int) -> Vector3:
	## Versatz einer Etage: nach oben (Höhe) und auf die Grundrissfläche der ersten Etage (gestapelter Grundriss).
	var fl: Array = cfg.target.get("floors", [])
	if i <= 0 or i >= fl.size():
		return Vector3.ZERO
	return Vector3(0.0, float(i) * LEVEL_H, -(float(fl[i].rows[0]) - float(fl[0].rows[0])))


## Position mit Etagenversatz (für Figuren, Beute, Wachen und Sichtlinien). Die Zuordnung kommt aus der Karte.
func _L(v: Vector3) -> Vector3:
	return v + _lift_for_floor(_floor_idx_z(v.z))


func _floor_of_y(y: float) -> int:
	var n: int = cfg.target.get("floors", []).size()
	return clampi(int(floor(y / LEVEL_H)), 0, maxi(n - 1, 0))


func _apply_floor_view() -> void:
	if cfg.target.get("floors", []).is_empty():
		return
	var show := -1
	if _floor_pick == "folgen":
		var f := _followed_floor()
		if f != _follow_floor:
			_follow_floor = f
			_move_cam_to_floor(f)
		show = f
	elif _floor_pick != "alle":
		show = _floor_index_by_id(_floor_pick)
	for n in _static_floor:
		var fi: int = _static_floor[n]
		(n as Node3D).visible = fi < 0 or show < 0 or fi == show
	for n in get_children():
		if not (n is Node3D) or n is Light3D or n is Camera3D or n == _car_node or _static_floor.has(n):
			continue
		var hidden := false
		if show >= 0:
			var p: Vector3 = (n as Node3D).position
			if p.x >= _bx0 and p.x <= _bx1 and _floor_of_y(p.y) != show:
				hidden = true
		if _crew_nodes.values().has(n):
			(n as Node3D).visible = not hidden
		elif hidden:
			(n as Node3D).visible = false

func _sync_body() -> void:
	for c in sim.crew:
		var node: Node3D = _crew_nodes[c.id]
		node.position = _L(Vector3(Sim.cu(c.pos).x + 0.5, 0, Sim.cu(c.pos).y + 0.5))
		var moved := _figure_moved(node)
		# Steht die Person still und arbeitet an einem Objekt, schaut sie zu diesem Objekt (Sim setzt facing bei Reichweite)
		var fac: Vector2 = c.get("facing", Vector2.ZERO)
		if not moved and fac.length() > 0.001:
			node.set_meta("dir", fac.normalized())
		_animate_figure(node, moved)
		_animate_action(node, _current_act(c))
		node.get_node("Name").text = String(c.name).split(" ")[0]
		# Namensschild: liegen zwei Personen auf demselben Feld, steht das eine höher
		var rank := 0
		for other in sim.crew:
			if other.id == c.id:
				break
			if Sim.cu(other.pos).distance_to(Sim.cu(c.pos)) < 1.2:
				rank += 1
		node.get_node("Name").position.y = FIG_H + 0.35 + 0.62 * rank
	for g in sim.guards:
		var node2: Node3D = _guard_nodes[g.id]
		node2.position = _L(Vector3(Sim.cu(g.pos).x + 0.5, 0, Sim.cu(g.pos).y + 0.5))
		node2.visible = g.state != "IDLE" and g.state != "OUT"
		_animate_figure(node2, _figure_moved(node2))
		var s: float = g.suspicion
		node2.scale = Vector3.ONE * (1.0 + s / 400.0)
	# Türen schwingen weich auf und zu (Ziel: 90° offen oder zu)
	for cell in _door_nodes:
		var hinge: Node3D = _door_nodes[cell]
		var target_a := -PI * 0.5 * 0.92 if sim.open_cells.has(cell) else 0.0
		hinge.rotation.y = move_toward(hinge.rotation.y, target_a, 0.08)
	# Alarmpanel: die Lampe blinkt, solange der Alarm läuft und die Anlage nicht überbrückt ist
	if _panel_led != null:
		var blink := int(Time.get_ticks_msec() / 250) % 2 == 0
		var on: bool = sim.alarm_active and not bool(sim.panel.get("bypassed", false)) and blink
		if on != _panel_on:
			_panel_on = on
			_panel_led.material_override = _mat(Color(1.0, 0.2, 0.15) if on else Color(0.2, 0.9, 0.3), 0.3, 0.0, 2.5 if on else 0.2)
	# Wandbilder: nur solange das Bild noch hängt
	for pid in _paint_nodes:
		(_paint_nodes[pid] as MeshInstance3D).visible = sim.loot[pid].state == "ROOM"
	# Steuerkasten-Klappe und Scheinwerfer und Sirene
	if _panel_flap != null:
		_panel_flap.rotation.x = move_toward(_panel_flap.rotation.x, -PI * 0.5 if bool(sim.panel.get("bypassed", false)) else 0.0, 0.05)
	var alarm: bool = sim.alarm_active
	var flash := int(Time.get_ticks_msec() / 300) % 2 == 0
	for sp in _spots:
		(sp as SpotLight3D).light_energy = move_toward((sp as SpotLight3D).light_energy, 3.0 if alarm else 0.0, 0.2)
	if _siren != null:
		_siren.visible = alarm and flash
		_siren.rotation.y += 0.2
	# Vitrinen-Deckel: heben sich, sobald die Vitrine offen ist
	for cell in _case_lids:
		var case_open := false
		for lid_id in sim.loot:
			var ll: Dictionary = sim.loot[lid_id]
			if ll.pos == cell and ll.opened:
				case_open = true
		var hl: Node3D = _case_lids[cell]
		hl.rotation.x = move_toward(hl.rotation.x, -PI * 0.42 if case_open else 0.0, 0.05)
	for lid in sim.loot:
		var l: Dictionary = sim.loot[lid]
		var n: MeshInstance3D = _loot_nodes[lid]
		if l.state == "ROOM":
			# Wie im Original: Beute steckt im Objekt (Kasse, Wertschrank), es schwebt nichts im Raum
			n.visible = false
		elif l.state == "CARRIED":
			# Wie im Original: ein Beutesack auf dem Rücken des Trägers (Original: lsAddLootBag)
			var carrier: Dictionary = {}
			for c in sim.crew:
				if c.id == l.carrier:
					carrier = c
			var cp := Sim.cu(carrier.pos)
			# Sack auf dem Rücken: hinter der Figur (entgegen der Blickrichtung), auf Schulterhöhe
			var face: Vector2 = carrier.get("facing", Vector2(0, 1))
			if face.length() < 0.001:
				face = Vector2(0, 1)
			face = face.normalized()
			var back := -face * 0.28
			n.position = _L(Vector3(cp.x + 0.5 + back.x, 1.1, cp.y + 0.5 + back.y))
			n.scale = Vector3(0.7, 0.8, 0.5)
			n.visible = true
		else:
			n.visible = false
	# Schaufenster geöffnet: die Scheibe zerbricht, Splitter fallen herab
	var dt := get_process_delta_time()
	for wcell in _window_nodes:
		var pane: MeshInstance3D = _window_nodes[wcell]
		if sim.open_cells.has(wcell) and not _broken.has(wcell):
			_broken[wcell] = true
			pane.visible = false
			for i in range(14):
				var sh := MeshInstance3D.new()
				var shm := BoxMesh.new()
				var sz_s := randf_range(0.04, 0.12)
				shm.size = Vector3(sz_s, sz_s, sz_s * 0.5)
				sh.mesh = shm
				sh.material_override = _mat(Color(0.8, 0.92, 1.0, 0.8), 0.1, 0.0, 0.3)
				sh.position = pane.global_position + Vector3(randf_range(-0.2, 0.2), randf_range(-0.5, 0.5), randf_range(-0.1, 0.1))
				add_child(sh)
				_shards.append({"node": sh, "vel": Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 1.2), randf_range(-0.6, 0.6))})
	var alive: Array = []
	for sh_d in _shards:
		var shn: MeshInstance3D = sh_d.node
		sh_d.vel.y -= 9.8 * dt
		shn.position += sh_d.vel * dt
		shn.rotation += Vector3(3.0, 2.0, 1.0) * dt
		if shn.position.y > -0.2:
			alive.append(sh_d)
		else:
			shn.queue_free()
	_shards = alive
	# Wertschrank geöffnet: die Tresortür schwingt auf
	for lid in sim.loot:
		var sl: Dictionary = sim.loot[lid]
		var scell := Sim._v2i(sl.pos)
		if not _safe_nodes.has(scell):
			continue
		var hs: Node3D = _safe_nodes[scell]
		var target_s := -PI * 0.62 if bool(sl.get("opened", false)) else 0.0
		hs.rotation.y = move_toward(hs.rotation.y, target_s, 0.03)
	# Kasse geöffnet: die Schublade gleitet heraus (weich, bis zur Endposition)
	for lid in sim.loot:
		var kl: Dictionary = sim.loot[lid]
		var cell := Sim._v2i(kl.pos)
		if not _drawer_nodes.has(cell):
			continue
		var node_d: MeshInstance3D = _drawer_nodes[cell]
		var base: Vector3 = _drawer_pos.get(cell, node_d.position)
		_drawer_pos[cell] = base
		var goal := base + Vector3(0, 0, 0.35) if bool(kl.get("opened", false)) else base
		node_d.position = node_d.position.move_toward(goal, 0.02)
	# Objekt wird bearbeitet (Dietrich, Brecheisen, Öffnen): das Beutestück am Objekt pulsiert
	var t_now := Time.get_ticks_msec() / 1000.0
	for c in sim.crew:
		var act := _current_act(c)
		if act != "TOOL" and act != "OPEN":
			continue
		var on_name := str(c.plan[c.idx].get("on", ""))
		for lid in sim.loot:
			if str(sim.loot[lid].get("name", "")) == on_name and sim.loot[lid].state == "ROOM":
				_loot_nodes[lid].scale = Vector3.ONE * (1.0 + 0.15 * absf(sin(t_now * 10.0)))
	_car_node.visible = sim.car.present
	_refresh_ui()

func _cone_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Sichtkegel wie im Grundriss: gleiche Berechnung aus der Simulation.
## Im Alarm blinken die Lampen rot.
var _flash_t := 0.0
func _alarm_light(delta: float) -> void:
	if not sim.alarm_active:
		for l in _lamps:
			l.light_color = Color(1.0, 0.86, 0.6) if l.omni_range < 6.5 else Color(1.0, 0.86, 0.6)
		return
	_flash_t += delta
	var on := 0.5 + 0.5 * sin(_flash_t * 7.0)
	for l in _lamps:
		l.light_color = Color(1.0, 0.45 + 0.2 * on, 0.35)
		l.light_energy = 0.9 + 0.5 * on


## Verdachtsring am Boden: füllt sich im Uhrzeigersinn, Farbe nach Zustand.
func _ring_mesh(frac: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := maxi(4, int(48.0 * frac))
	for i in range(n + 1):
		var a := -PI * 0.5 + TAU * frac * float(i) / float(n)
		verts.append(Vector3(cos(a) * 0.42, 0, sin(a) * 0.42))
		verts.append(Vector3(cos(a) * 0.52, 0, sin(a) * 0.52))
	for i in range(n):
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _update_sight_and_rings() -> void:
	for g in sim.guards:
		var ring: MeshInstance3D = _ring_nodes[g.id]
		var gp := Vector3(Sim.cu(g.pos).x + 0.5, 0.16, Sim.cu(g.pos).y + 0.5)
		var frac := clampf(float(g.suspicion) / 100.0, 0.0, 1.0)
		if g.state == "IDLE" or g.state == "OUT" or frac <= 0.0:
			ring.visible = false
		else:
			ring.visible = true
			ring.position = _L(gp)
			ring.mesh = _ring_mesh(frac)
			ring.material_override = _mat(STATE_COL3D.get(g.state, Color.WHITE), 0.4, 0.0, 1.5)
		for c in sim.crew:
			var line: MeshInstance3D = _sight_nodes[g.id + "|" + c.id]
			if not sim.guard_sees(g, c):
				line.visible = false
				continue
			var a := _L(Vector3(Sim.cu(g.pos).x + 0.5, 1.2, Sim.cu(g.pos).y + 0.5))
			var b := _L(Vector3(Sim.cu(c.pos).x + 0.5, 1.2, Sim.cu(c.pos).y + 0.5))
			var L := a.distance_to(b)
			if L < 0.05:
				line.visible = false
				continue
			line.visible = true
			(line.mesh as BoxMesh).size = Vector3(0.06, 0.06, L)
			line.position = (a + b) * 0.5
			line.look_at(b, Vector3.UP)


func _update_cones() -> void:
	_update_sight_and_rings()
	for g in sim.guards:
		var cm: MeshInstance3D = _cone_nodes[g.id]
		if g.state == "IDLE" or g.state == "OUT":
			cm.visible = false
			continue
		var pts := sim.view_cone(g.pos, g.facing, float(g.vision))
		var verts := PackedVector3Array()
		for pt in pts:
			verts.append(_L(Vector3(pt.x + 0.5, 0.14, pt.y + 0.5)))
		var idx := PackedInt32Array()
		for i in range(1, pts.size() - 1):
			idx.append_array([0, i, i + 1])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		cm.mesh = am
		cm.material_override = _cone_mat(STATE_COL3D.get(g.state, Color.WHITE))
		cm.visible = true


# ---------------------------------------------------------------- Oberfläche

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	layer.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	_clock = UI.label("", 20, Color(0.95, 0.8, 0.4))
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_clock)
	_status = UI.label("", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_status)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	# Etagen-Schalter (nur bei Zielen mit Etagen)
	if not cfg.target.get("floors", []).is_empty():
		top.add_child(UI.button("Folgen", _on_floor_pick.bind("folgen"), 80))
	for fl in cfg.target.get("floors", []):
		top.add_child(UI.button(str(fl.name), _on_floor_pick.bind(str(fl.id)), 70))
	if not cfg.target.get("floors", []).is_empty():
		top.add_child(UI.button("Alle", _on_floor_pick.bind("alle"), 70))
	var abort_btn := UI.button("Funk: alle zurück", _on_abort, 250)
	abort_btn.tooltip_text = "Alle Einbrecherinnen gehen sofort zurück zum Wagen."
	top.add_child(abort_btn)
	_pause_btn = UI.button("Pause", _on_pause, 110)
	top.add_child(_pause_btn)
	top.add_child(UI.dropdown(["1x", "4x", "16x"], 0, func(i: int): speed = [1.0, 4.0, 16.0][i]))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 170)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	bottom.add_child(_log)
	_result_btn = UI.button("Auswertung", _on_result, 200)
	_result_btn.visible = false
	bottom.add_child(_result_btn)


func _refresh_ui() -> void:
	_clock.text = "T+ %s" % Sim.clock(sim.time)
	var parts: Array = []
	match sim.status:
		"RUNNING":
			parts.append("Ausführung läuft")
		_:
			parts.append(sim.status)
	if sim.countdown >= 0.0:
		parts.append("Polizei in %.0f s" % sim.countdown)
	if sim.car.called and not sim.car.present:
		parts.append("Wagen unterwegs")
	_status.text = " · ".join(parts)
	var lines: Array = sim.log_lines.slice(max(0, sim.log_lines.size() - 40))
	_log.text = "\n".join(lines)


func _on_abort() -> void:
	sim.abort()
	_sync()


func _on_pause() -> void:
	paused = not paused
	_pause_btn.text = "Weiter" if paused else "Pause"


func _on_speed(s: float) -> void:
	speed = s


func _on_result() -> void:
	main.go("result", {"result": sim.result()})


func _finish() -> void:
	finished = true
	Game.apply_result(sim.result())
	_status.text = "Ende: %s" % sim.status
	# Erst die Fluchtszene, danach die Auswertung
	var sc := EscapeScene.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.status = sim.status
	sc.alarm = sim.alarm_active
	sc.done.connect(func():
		sc.queue_free()
		_result_btn.visible = true)
	_layer.add_child(sc)


# ---------------------------------------------------------------- Schleife

func _process(delta: float) -> void:
	if finished or paused:
		return
	_acc += delta * speed
	_cone_t += delta
	_alarm_light(delta)
	var guard := 0
	while _acc >= Sim.DT and guard < 400:
		sim.step(Sim.DT)
		_acc -= Sim.DT
		guard += 1
		if sim.status != "RUNNING":
			break
	_sync()
	if _cone_t >= 0.1:
		_cone_t = 0.0
		_update_cones()
	if sim.status != "RUNNING":
		_finish()

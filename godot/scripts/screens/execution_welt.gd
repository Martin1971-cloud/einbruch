class_name ExecWelt
extends Node3D
## Ausführung, Grundlage: Materialien und Bauteile, Gebäude und Wände, Deko, Figuren-Vorlagen.

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

## Deko: Möbel und Bilder, rein zur Ansicht. Sie gehören nicht zur Beute und blockieren nichts.
func _build_deko(liste: Array) -> void:
	var sb := float(Sim.SUB)
	var holz := Color(0.42, 0.28, 0.17)
	var holz_hell := Color(0.55, 0.4, 0.26)
	for d in liste:
		var r: Array = d.rect
		var x0 := float(r[0]) / sb
		var y0 := float(r[1]) / sb
		var x1 := float(r[2]) / sb
		var y1 := float(r[3]) / sb
		var w := x1 - x0
		var dp := y1 - y0
		var cx := (x0 + x1) * 0.5
		var cz := (y0 + y1) * 0.5
		match String(d.kind):
			"tisch":
				_box(Vector3(w, 0.08, dp), Vector3(cx, 0.76, cz), holz_hell, 0.6)
				for ex in [-1.0, 1.0]:
					for ez in [-1.0, 1.0]:
						_box(Vector3(0.07, 0.74, 0.07), Vector3(cx + ex * (w * 0.5 - 0.12), 0.37, cz + ez * (dp * 0.5 - 0.12)), holz, 0.7)
			"stuhl":
				_box(Vector3(w, 0.07, dp), Vector3(cx, 0.46, cz), holz, 0.7)
				_box(Vector3(w, 0.5, 0.06), Vector3(cx, 0.72, cz - dp * 0.5 + 0.03), holz, 0.7)
			"regal":
				_box(Vector3(w, 2.0, dp), Vector3(cx, 1.0, cz), holz, 0.8)
				for hy in [0.6, 1.3]:
					_box(Vector3(w + 0.04, 0.05, dp + 0.04), Vector3(cx, hy, cz), holz_hell, 0.7)
			"bild":
				var bw := maxf(w, 0.04)
				var bd := maxf(dp, 0.04)
				_box(Vector3(bw, 0.9, bd), Vector3(cx, 1.5, cz), Color(0.3, 0.22, 0.12), 0.6)
				_box(Vector3(bw * 0.8 + 0.02, 0.7, bd * 0.3 + 0.02), Vector3(cx, 1.5, cz), Color(0.78, 0.7, 0.5), 0.8)
			"pflanze":
				_cyl(0.2, 0.4, Vector3(cx, 0.2, cz), Color(0.5, 0.3, 0.2), 0.8)
				_cyl(0.32, 0.9, Vector3(cx, 0.85, cz), Color(0.2, 0.42, 0.22), 0.9)
			"kiste":
				_box(Vector3(w, 0.6, dp), Vector3(cx, 0.3, cz), holz, 0.8)
	return

## Wandfuß: drei feste, dunklere Streifen auf dem Boden an der Innenseite der Wand (Stufen statt Verlauf, undurchsichtig).
## Ersetzt den berechneten Schatten am Wandfuß, daher kein Schattenwurf und kein Zackenmuster.
func _kontakt(center: Vector3, achse: int, laenge: float, aussen: int) -> void:
	var basis_farbe := Color(0.7, 0.74, 0.82)
	var stufen := [0.4, 0.6, 0.82]
	var breite := 0.25
	for side in [-1, 1]:
		if aussen != 0 and side == aussen:
			continue
		var into := Vector3(0, 0, float(side)) if achse == 2 else Vector3(float(side), 0, 0)
		var size := Vector3(laenge, 0.004, breite) if achse == 2 else Vector3(breite, 0.004, laenge)
		for k in range(stufen.size()):
			var off := WALL_T * 0.5 + breite * (float(k) + 0.5)
			var pos := center + into * off
			pos.y = 0.102
			_box(size, pos, basis_farbe * stufen[k], 0.9)

## Außenerkennung über den Grundriss: von außen (Rand) durch alle freien Felder füllen.
## Wände, Türen und Fenster blockieren. Erreichbare Felder gelten als außen.
func _aussen_gitter(spec: Dictionary) -> PackedByteArray:
	var w := int(spec.w)
	var h := int(spec.h)
	var blockiert := PackedByteArray()
	blockiert.resize(w * h)
	for r in spec.paint:
		var code := String(r[4])
		if code == "W" or code == "D" or code == "F":
			for yy in range(clampi(int(r[1]), 0, h), clampi(int(r[3]), 0, h)):
				for xx in range(clampi(int(r[0]), 0, w), clampi(int(r[2]), 0, w)):
					blockiert[yy * w + xx] = 1
	var aussen := PackedByteArray()
	aussen.resize(w * h)
	var schlange := PackedInt32Array()
	for x in range(w):
		for y: int in [0, h - 1]:
			var i: int = y * w + x
			if blockiert[i] == 0 and aussen[i] == 0:
				aussen[i] = 1
				schlange.append(i)
	for y in range(h):
		for x: int in [0, w - 1]:
			var i: int = y * w + x
			if blockiert[i] == 0 and aussen[i] == 0:
				aussen[i] = 1
				schlange.append(i)
	var k := 0
	while k < schlange.size():
		var i: int = schlange[k]
		k += 1
		var x: int = i % w
		var y: int = i / w
		if x > 0 and blockiert[i - 1] == 0 and aussen[i - 1] == 0:
			aussen[i - 1] = 1
			schlange.append(i - 1)
		if x < w - 1 and blockiert[i + 1] == 0 and aussen[i + 1] == 0:
			aussen[i + 1] = 1
			schlange.append(i + 1)
		if y > 0 and blockiert[i - w] == 0 and aussen[i - w] == 0:
			aussen[i - w] = 1
			schlange.append(i - w)
		if y < h - 1 and blockiert[i + w] == 0 and aussen[i + w] == 0:
			aussen[i + w] = 1
			schlange.append(i + w)
	for i in range(w * h):
		if blockiert[i] == 1:
			aussen[i] = 2
	return aussen

## Vom Wandmittelpunkt aus nach der Richtung suchen, bis die erste freie Fläche kommt. True, wenn sie außen liegt.
func _strahl_aussen(g: PackedByteArray, spec: Dictionary, x_t: float, y_t: float, dx: float, dy: float) -> bool:
	var sbf := float(Sim.SUB)
	var w := int(spec.w)
	var h := int(spec.h)
	var t := 0.0
	while t < 1.5:
		var ix := clampi(floori((x_t + dx * t) * sbf), 0, w - 1)
		var iy := clampi(floori((y_t + dy * t) * sbf), 0, h - 1)
		var zelle: int = g[iy * w + ix]
		if zelle != 2:
			return zelle == 1
		t += 1.0 / sbf
	return false

## Waagerechte Wand bei cy: -1 = Außenseite oben (kleiner y), +1 = unten, 0 = innen oder beidseitig.
func _aussen_h(g: PackedByteArray, spec: Dictionary, iv: Array, cy: float) -> int:
	var xm: float = (float(iv[0]) + float(iv[1])) * 0.5
	var oben := _strahl_aussen(g, spec, xm, cy, 0.0, -1.0)
	var unten := _strahl_aussen(g, spec, xm, cy, 0.0, 1.0)
	if oben and not unten:
		return -1
	if unten and not oben:
		return 1
	return 0

## Senkrechte Wand bei cx: -1 = Außenseite links, +1 = rechts.
func _aussen_v(g: PackedByteArray, spec: Dictionary, iv: Array, cx: float) -> int:
	var ym: float = (float(iv[0]) + float(iv[1])) * 0.5
	var links := _strahl_aussen(g, spec, cx, ym, -1.0, 0.0)
	var rechts := _strahl_aussen(g, spec, cx, ym, 1.0, 0.0)
	if links and not rechts:
		return -1
	if rechts and not links:
		return 1
	return 0

## Wandstück: innen Stein, außen Ziegel. Außenwände werden in zwei Hälften geteilt (keine gemeinsamen Flächen = kein Flimmern).
func _wand_stueck(size: Vector3, pos: Vector3, achse: int, aussen: int) -> void:
	if aussen == 0:
		_box_m(size, pos, _wand_mat("stein"))
		return
	var t: float = size[achse]
	var halb := size
	halb[achse] = t * 0.5
	var off := Vector3.ZERO
	off[achse] = float(aussen) * t * 0.25
	_box_m(halb, pos + off, _wand_mat("ziegel"))
	_box_m(halb, pos - off, _wand_mat("stein"))

func _box_m(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	_outline(self, bm, 0.1, pos, size)
	return mi

var _wand_cache := {}

## Wandmaterial mit prozeduraler Textur. Triplanar: die Muster laufen ohne Kanten über alle Flächen.
func _wand_mat(art: String) -> StandardMaterial3D:
	if _wand_cache.has(art):
		return _wand_cache[art]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _ziegel_bild() if art == "ziegel" else _stein_bild()
	m.albedo_color = Color(1, 1, 1)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.6, 0.6, 0.6)
	m.roughness = 0.92
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_wand_cache[art] = m
	return m

## Ziegelmauer: Reihen mit Versatz, dunkler Mörtel, leicht unterschiedliche Steine.
func _ziegel_bild() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var reihe := 16
	var breite := 32
	for y in range(n):
		var r := int(y / reihe)
		var versatz := (breite / 2) if r % 2 == 1 else 0
		var fy := y % reihe
		for x in range(n):
			var xx := (x + versatz) % n
			var fx := xx % breite
			var mortel := fy == 0 or fx == 0
			var basis := Color(0.58, 0.28, 0.2)
			if mortel:
				img.set_pixel(x, y, Color(0.68, 0.65, 0.6))
			else:
				var ton := 0.9 + rng.randf() * 0.2 if (r * 7 + int(xx / breite)) % 5 != 0 else 0.8
				img.set_pixel(x, y, Color(basis.r * ton, basis.g * ton, basis.b * ton))
	return ImageTexture.create_from_image(img)

## Bruchsteinmauer: unregelmäßige Blöcke mit dunklen Fugen.
func _stein_bild() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var y := 0
	while y < n:
		var h := 18 + rng.randi() % 10
		var x := 0
		while x < n:
			var w := 26 + rng.randi() % 24
			var g := 0.42 + rng.randf() * 0.12
			for yy in range(y, mini(y + h, n)):
				for xx in range(x, mini(x + w, n)):
					var fuge := yy == y or xx == x
					if fuge:
						img.set_pixel(xx, yy, Color(0.22, 0.21, 0.2))
					else:
						img.set_pixel(xx, yy, Color(g, g * 0.97, g * 0.92))
			x += w
		y += h
	return ImageTexture.create_from_image(img)

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
	var bg_pic := UI.backdrop("res://assets/art/bg_hafen_nacht.webp")
	bg_pic.modulate = Color(0.62, 0.64, 0.7)   # dezent: etwas abgedunkelt, damit Gebäude und Figuren im Vordergrund stehen
	bg_layer.add_child(bg_pic)
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
	moon.shadow_enabled = false
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
	# Abstand um das Gebäude knapp: es füllt das Bild besser aus (vorher 1,6)
	cam.size = clampf(maxf(ext.y * 1.15, ext.x * 1.15 / aspect), 8.0, 40.0)
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
		_build_deko(GameData.DEKO.get(str(cfg.target.get("id", "")), []))
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
	var ex := Sim._v2i(cfg.target.points.fluchtwagen)
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
				# 90 % der Öffnung: zu jeder Seite bleibt ein kleiner Spalt, damit die Kanten nicht fast in der Ebene der Wand liegen (Flimmern)
				# 80 % der Öffnung: die Umrisse der Wände ragen 5 cm in die Öffnung, das Blatt darf nicht in deren Ebene liegen
				var leaf_size := Vector3(dsz.x * 0.8, 2.1, dsz.z * 0.8)
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
				# Fester dunkler Türrahmen in den Spalten neben dem Blatt: sonst sieht man dort den Boden und es flimmert (Z-Fighting)
				var jamb_col := Color(0.12, 0.1, 0.09)
				var jamb_h := 2.0
				for sgn in [-1.0, 1.0]:
					if along_x:
						_box(Vector3(0.06, jamb_h, leaf_t + 0.04), p + Vector3(sgn * 0.45, 0.1 + jamb_h * 0.5, 0), jamb_col, 0.8)
					else:
						_box(Vector3(leaf_t + 0.04, jamb_h, 0.06), p + Vector3(0, 0.1 + jamb_h * 0.5, sgn * 0.45), jamb_col, 0.8)
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
	var aussen_g := _aussen_gitter(spec)
	for key in hz:
		var cy: float = key / 100.0
		var runs := _merge_runs(hz[key])
		for o in openings:
			if absf((o[1] + o[3]) * 0.5 - cy) < 0.01 and o[2] - o[0] >= o[3] - o[1]:
				runs = _cut_runs(runs, o[0], o[2])
		var edges_h := []
		for o in openings:
			if absf((o[1] + o[3]) * 0.5 - cy) < 0.01 and o[2] - o[0] >= o[3] - o[1]:
				edges_h.append(o[0])
				edges_h.append(o[2])
		for iv in runs:
			# Wandende an einer Türöffnung nicht verlängern: sonst ragt die Wand ins Türblatt (Z-Fighting)
			var a0: float = iv[0] - (WALL_T * 0.5 if _kein_rand(iv[0], edges_h) else 0.0)
			var a1: float = iv[1] + (WALL_T * 0.5 if _kein_rand(iv[1], edges_h) else 0.0)
			var ln: float = a1 - a0
			var cx: float = (a0 + a1) * 0.5
			var aus_h := _aussen_h(aussen_g, spec, iv, cy)
			_wand_stueck(Vector3(ln, WALL_H, WALL_T), Vector3(cx, WALL_H * 0.5, cy), 2, aus_h)
			_kontakt(Vector3(cx, 0.0, cy), 2, ln, aus_h)
			_box(Vector3(ln + 0.02, 0.1, WALL_T + 0.02), Vector3(cx, WALL_H + 0.05, cy), cap, 0.5)
	for key in vt:
		var cx2: float = key / 100.0
		var runs2 := _merge_runs(vt[key])
		for o in openings:
			if absf((o[0] + o[2]) * 0.5 - cx2) < 0.01 and o[3] - o[1] > o[2] - o[0]:
				runs2 = _cut_runs(runs2, o[1], o[3])
		var edges_v := []
		for o in openings:
			if absf((o[0] + o[2]) * 0.5 - cx2) < 0.01 and o[3] - o[1] > o[2] - o[0]:
				edges_v.append(o[1])
				edges_v.append(o[3])
		for iv in runs2:
			var b0: float = iv[0] - (WALL_T * 0.5 if _kein_rand(iv[0], edges_v) else 0.0)
			var b1: float = iv[1] + (WALL_T * 0.5 if _kein_rand(iv[1], edges_v) else 0.0)
			var ln2: float = b1 - b0
			var cy2: float = (b0 + b1) * 0.5
			var aus_v := _aussen_v(aussen_g, spec, iv, cx2)
			_wand_stueck(Vector3(WALL_T, WALL_H, ln2), Vector3(cx2, WALL_H * 0.5, cy2), 0, aus_v)
			_kontakt(Vector3(cx2, 0.0, cy2), 0, ln2, aus_v)
			_box(Vector3(WALL_T + 0.02, 0.1, ln2 + 0.02), Vector3(cx2, WALL_H + 0.05, cy2), cap, 0.5)

## True, wenn das Wandende nicht an einer Türöffnung liegt (dann darf die Ecke verlängert werden).
func _kein_rand(v: float, kanten: Array) -> bool:
	for k in kanten:
		if absf(float(k) - v) < 0.01:
			return false
	return true

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

## Etagen: nur die gewählte Etage zeigen. Die Zuordnung kommt aus der Höhe (Zeile der Karte).
func _floor_idx_z(z: float) -> int:
	var fl: Array = cfg.target.get("floors", [])
	for i in range(fl.size()):
		if z >= float(fl[i].rows[0]) and z < float(fl[i].rows[1]):
			return i
	return 0

func _is_ground(n: MeshInstance3D) -> bool:
	## Große Flächen (Boden, Straße) bleiben immer sichtbar.
	var sz: Vector3 = n.get_aabb().size
	return sz.x > 30.0 or sz.z > 30.0

func _lift_for_floor(i: int) -> Vector3:
	## Versatz einer Etage: nach oben (Höhe) und auf die Grundrissfläche der ersten Etage (gestapelter Grundriss).
	var fl: Array = cfg.target.get("floors", [])
	if i <= 0 or i >= fl.size():
		return Vector3.ZERO
	return Vector3(0.0, float(i) * LEVEL_H, -(float(fl[i].rows[0]) - float(fl[0].rows[0])))

## Position mit Etagenversatz (für Figuren, Beute, Wachen und Sichtlinien). Die Zuordnung kommt aus der Karte.
func _L(v: Vector3) -> Vector3:
	return v + _lift_for_floor(_floor_idx_z(v.z))

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

var _cone_key := {}  # Wache -> letzter Zustand des Kegels (nur neu bauen, wenn er sich ändert)

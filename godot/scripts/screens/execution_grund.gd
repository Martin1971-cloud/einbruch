class_name ExecGrund
extends Node3D
## Ausführung, Grundbausteine: Materialien, Quader, Lampen, Wandmaterial, Figuren-Vorlagen.

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

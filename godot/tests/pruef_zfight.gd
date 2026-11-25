extends SceneTree
## Sucht Z-Fighting-Kandidaten in der 3D-Ausführung: zwei Körper, deren Flächen in derselben Ebene liegen
## und sich auf einer Fläche überlappen. Solche Stellen flimmern im Spiel.
## Aufruf: xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tests/pruef_zfight.gd -- <Gebäude-ID>
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0
var _ziel := "kiosk"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_ziel = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.target_id = _ziel
		G.unlocked[_ziel] = true
		G.intel[_ziel] = 2
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		return false
	if _frames < 6:
		return false
	var G = root.get_node("/root/Game")
	match _step:
		0:
			_main.current._on_look()
			_main.current._on_look()
			_main.go("organisation")
			_step = 1
		1:
			var org = _main.current
			for c in GameData.CREW:
				org._selected[c.id] = c.id == "otto"
				org._gear_pick[c.id] = []
			G.tools_owned["lockpick"] = true
			org._burgle["otto"] = true
			org._build_people()
			org._build_shop()
			org._refresh_summary()
			org._on_confirm()
			_step = 2
		2:
			var pl = _main.current
			pl.plans["otto"] = [{"t": "MOVE", "to": "Fluchtwagen"}]
			pl._on_changed()
			_step = 3
		3:
			_main.current._on_execute()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null:
				_pruefe(cur)
				quit(0)
			if _wait > 600:
				print("Keine Ausführung gefunden")
				quit(1)
	return false


func _pruefe(cur: Node) -> void:
	var alle: Array = []
	_sammle(cur, alle)
	var boxen: Array = []
	for m in alle:
		var a: AABB = m.global_transform * m.get_aabb()
		boxen.append({"m": m, "a": a})
	var treffer := 0
	print("Ziel %s: %d Körper" % [_ziel, boxen.size()])
	for i in range(boxen.size()):
		for j in range(i + 1, boxen.size()):
			var a: AABB = boxen[i].a
			var b: AABB = boxen[j].a
			var achse := _coplanar(a, b)
			if achse == "":
				continue
			# Dunkle Umrisse (Cel-Hülle) werden nur von innen gezeichnet und zählen nicht als sichtbares Flimmern
			if _dunkel(boxen[i].m) or _dunkel(boxen[j].m):
				continue
			# Gleiche Farbe: die Flächen sehen gleich aus, ein Flimmern fällt nicht auf
			if _gleiche_farbe(boxen[i].m, boxen[j].m):
				continue
			treffer += 1
			if treffer <= 60:
				print("  %s: %s (%s) <-> %s (%s)" % [achse, str(boxen[i].m.global_position), _farbe(boxen[i].m), str(boxen[j].m.global_position), _farbe(boxen[j].m)])
	print("Ziel %s: %d sichtbare Kandidaten für Z-Fighting" % [_ziel, treffer])


## Liefert die Achse, in der sich zwei Körper mit gleicher Flächenlage überlappen, sonst "".
func _coplanar(a: AABB, b: AABB) -> String:
	var eps := 0.002
	var achsen := ["x", "y", "z"]
	for k in range(3):
		var ak: String = achsen[k]
		# Nur gleichgerichtete Flächen zählen (beide Vorder- oder beide Rückseiten). Gegenüberliegende Flächen berühren sich nur.
		var gleich := absf(a.position[k] - b.position[k]) < eps or absf(a.end[k] - b.end[k]) < eps
		if not gleich:
			continue
		# In den anderen beiden Achsen muss die Überlappung echt sein (sonst berühren sich nur Kanten)
		var ok := true
		for l in range(3):
			if l == k:
				continue
			var ov := minf(a.end[l], b.end[l]) - maxf(a.position[l], b.position[l])
			if ov < 0.02:
				ok = false
				break
		if ok:
			return ak
	return ""


func _gleiche_farbe(a: MeshInstance3D, b: MeshInstance3D) -> bool:
	if not (a.material_override is StandardMaterial3D and b.material_override is StandardMaterial3D):
		return false
	var ca: Color = (a.material_override as StandardMaterial3D).albedo_color
	var cb: Color = (b.material_override as StandardMaterial3D).albedo_color
	return absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) < 0.04


func _dunkel(m: MeshInstance3D) -> bool:
	if m.material_override is StandardMaterial3D:
		var c: Color = (m.material_override as StandardMaterial3D).albedo_color
		return c.get_luminance() < 0.09
	return false


func _farbe(m: MeshInstance3D) -> String:
	if m.material_override is StandardMaterial3D:
		var c: Color = (m.material_override as StandardMaterial3D).albedo_color
		return "#%s" % c.to_html(false)
	return "?"


func _sammle(n: Node, ziel: Array) -> void:
	if n is MeshInstance3D:
		ziel.append(n)
	for c in n.get_children():
		_sammle(c, ziel)

extends SceneTree
## Geometrieprüfung Tür: listet alle Körper, die das Türblatt berühren oder überlappen.
## Zeigt, ob etwas auf gleicher Ebene liegt (Ursache für gestrichelt aussehende Flächen).
## Aufruf: xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tests/pruef_tuer_geometrie.gd
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0


func _initialize() -> void:
	pass


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
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
			pl.plans["otto"] = [{"t": "MOVE", "to": "fluchtwagen"}]
			pl._on_changed()
			_step = 3
		3:
			_main.current.ausfuehren()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null and cur.get("_door_nodes") != null:
				_pruefe(cur)
				quit(0)
			if _wait > 600:
				print("Keine Ausführung gefunden")
				quit(1)
	return false


func _pruefe(cur: Node) -> void:
	var alle: Array = []
	_sammle(cur, alle)
	print("Körper insgesamt: %d" % alle.size())
	for key in cur._door_nodes:
		var hinge: Node3D = cur._door_nodes[key]
		if hinge.get_child_count() == 0:
			continue
		var leaf: MeshInstance3D = hinge.get_child(0)
		var la: AABB = (leaf.global_transform * leaf.get_aabb()).grow(0.02)
		print("")
		print("Tür %s: Blatt bei %s, Größe %s" % [str(key), str(leaf.global_position), str(leaf.get_aabb().size)])
		for m in alle:
			if m == leaf:
				continue
			var ma: AABB = m.global_transform * m.get_aabb()
			if ma.intersects(la):
				var farbe := "?"
				if m.material_override is StandardMaterial3D:
					farbe = str((m.material_override as StandardMaterial3D).albedo_color)
				print("  überlappt: Pos %s  Größe %s  Farbe %s  Pfad %s" % [str(m.global_position), str(ma.size), farbe, str(m.get_path())])


func _sammle(n: Node, ziel: Array) -> void:
	if n is MeshInstance3D:
		ziel.append(n)
	for c in n.get_children():
		_sammle(c, ziel)

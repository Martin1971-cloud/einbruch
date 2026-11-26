extends SceneTree
## Prüft die Wandmaterialien (Ziegel außen, Stein innen) in der 3D-Ausführung.
var _frames := 0
var _step := 0
var _main: Node
var _wait := 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
		G.target_id = "testhaus"
		G.unlocked["testhaus"] = true
		G.intel["testhaus"] = 2
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
			_main.current._on_execute()
			_step = 4
		4:
			_wait += 1
			var cur = _main.current
			if cur.get("sim") != null:
				var zaehl := {"ziegel": 0, "stein": 0, "andere": 0}
				var ziegel_mat = cur._wand_cache.get("ziegel")
				var stein_mat = cur._wand_cache.get("stein")
				var stapel: Array = []
				_sammle(cur, stapel)
				for m in stapel:
					var mt = m.material_override
					if ziegel_mat != null and mt == ziegel_mat:
						zaehl["ziegel"] += 1
						print("  Ziegel bei %s Größe %s" % [str(m.global_position), str((m.mesh as BoxMesh).size)])
					elif stein_mat != null and mt == stein_mat:
						zaehl["stein"] += 1
					else:
						zaehl["andere"] += 1
				print("Zählung: %s" % str(zaehl))
				if ziegel_mat != null:
					var img: Image = ziegel_mat.albedo_texture.get_image()
					print("Ziegel-Bild %dx%d, Pixel(5,5)=%s, Pixel(20,8)=%s" % [img.get_width(), img.get_height(), str(img.get_pixel(5, 5)), str(img.get_pixel(20, 8))])
				quit(0)
			if _wait > 600:
				print("Keine Ausführung")
				quit(1)
	return false


func _sammle(n: Node, ziel: Array) -> void:
	if n is MeshInstance3D:
		ziel.append(n)
	for c in n.get_children():
		_sammle(c, ziel)

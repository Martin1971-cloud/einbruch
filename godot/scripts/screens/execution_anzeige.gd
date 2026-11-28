class_name ExecAnzeige
extends ExecWelt
## Ausführung, Anzeige: Figuren bewegen und animieren, Etagen, Sicht- und Wachkegel, Stand der Anzeige.

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
		"OPEN", "CLOSE":
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

func _floor_index_by_id(id: String) -> int:
	var fl: Array = cfg.target.get("floors", [])
	for i in range(fl.size()):
		if str(fl[i].id) == id:
			return i
	return -1

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
	# Dekoobjekte ohne Beute: Klappe am Regal schwingt auf, Zeitungsstapel hebt sich, Schublade gleitet heraus
	for cell in _deko_anim:
		var da: Dictionary = _deko_anim[cell]
		var d_open := false
		for lid in sim.loot:
			var dl: Dictionary = sim.loot[lid]
			if dl.get("leer", false) and Sim._v2i(dl.pos) == cell and dl.opened:
				d_open = true
		var dn: Node3D = da.node
		var rest: Vector3 = da.rest
		match str(da.kind):
			"R":
				dn.rotation.y = move_toward(dn.rotation.y, -PI * 0.45 if d_open else 0.0, 0.03)
			"Z":
				dn.position.y = move_toward(dn.position.y, rest.y + 0.35 if d_open else rest.y, 0.01)
				dn.rotation.x = move_toward(dn.rotation.x, -0.3 if d_open else 0.0, 0.02)
			"P":
				dn.position.z = move_toward(dn.position.z, rest.z + 0.3 if d_open else rest.z, 0.01)
	for lid in sim.loot:
		var l: Dictionary = sim.loot[lid]
		if l.get("leer", false):
			continue  # Dekoobjekt: bleibt als Möbelstück stehen
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
		if act != "TOOL" and act != "OPEN" and act != "CLOSE":
			continue
		var on_id := str(c.plan[c.idx].get("on", ""))
		for lid in sim.loot:
			if str(sim.loot[lid].get("id", "")) == on_id and sim.loot[lid].state == "ROOM" and not sim.loot[lid].get("leer", false):
				_loot_nodes[lid].scale = Vector3.ONE * (1.0 + 0.15 * absf(sin(t_now * 10.0)))
	_car_node.visible = sim.car.present
	_refresh_ui()

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
	# Einfache Darstellung: keine Sichtkegel, Sichtlinien und Ringe (weniger Rechenzeit, übersichtlicher)
	if bool(Game.settings.get("einfach", false)):
		for g in sim.guards:
			_cone_nodes[g.id].visible = false
			_ring_nodes[g.id].visible = false
		for k in _sight_nodes:
			_sight_nodes[k].visible = false
		return
	_update_sight_and_rings()
	for g in sim.guards:
		var cm: MeshInstance3D = _cone_nodes[g.id]
		if g.state == "IDLE" or g.state == "OUT":
			cm.visible = false
			continue
		var key := "%s|%s|%s|%s" % [str(g.pos), str(g.facing), str(g.vision), str(g.state)]
		if _cone_key.get(g.id, "") == key and cm.visible:
			continue
		_cone_key[g.id] = key
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

func _refresh_ui() -> void:
	_clock.text = "T+ %s" % Sim.clock(sim.time)
	var parts: Array = []
	match sim.status:
		"RUNNING":
			parts.append(Texte.t("ausf.laeuft"))
		_:
			parts.append(sim.status)
	if sim.countdown >= 0.0:
		parts.append(Texte.t("ausf.polizei_in") % sim.countdown)
	if sim.car.called and not sim.car.present:
		parts.append(Texte.t("ausf.wagen_unterwegs"))
	_status.text = " · ".join(parts)
	var lines: Array = sim.log_lines.slice(max(0, sim.log_lines.size() - 40))
	_log.text = "\n".join(lines)

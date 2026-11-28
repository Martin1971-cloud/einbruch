class_name Sim
extends SimAktionen
## Ausführungslogik eines Einbruchs: Aufbau, Ablauf (step), Ergebnis und Planungsvorschau.
## Ohne Darstellung, deterministisch. Die Regeln liegen in den Grundklassen (sim_karte, sim_wachen, sim_aktionen).


static func create(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary, karte := false) -> Sim:
	var s := Sim.new()
	s._setup(target, team, plans, car_cfg)
	s.karte = karte
	return s

func _setup(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary) -> void:
	target_name = Texte.t(target.name)
	max_volume = float(target.get("max_volume", 30.0))
	var pol := GameData.polizei(str(target.get("id", "")))
	police_base = float(pol["zeit"])
	police_reaktion = float(pol["reaktion_s"])
	police_fahrt = float(pol["fahrt_s"])
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
	escape_cell = points.get("fluchtwagen", Vector2i.ZERO)
	for d in target.doors:
		var p := _v2i(d.pos)
		doors[p] = {"id": d.id, "name": Texte.t(d.name), "res": float(d.res), "cplx": float(d.cplx), "destroyed": false, "locked": bool(d.get("locked", true)), "kind": str(d.get("kind", "tuer"))}
	for pair in target.get("treppen", []):
		var sa := Vector2i(int(pair[0]), int(pair[1]))
		var sb := Vector2i(int(pair[2]), int(pair[3]))
		stairs[sa] = sb
		stairs[sb] = sa
	gesichert = target.get("gesichert", [])
	karte_tuer = str(target.get("karte_tuer", ""))
	patrol_mittel = GameData.patrol_mittel_s(target)
	hauptweg = target.get("hauptweg", [])
	if target.has("panel"):
		panel = {"id": target.panel.id, "name": Texte.t(target.panel.name), "pos": _v2i(target.panel.pos), "res": float(target.panel.res), "cplx": float(target.panel.cplx), "bypassed": false}
	for s in target.sensors:
		sensors.append({"name": Texte.t(s.name), "pos": _v2i(s.pos), "threshold": float(s.threshold), "active": true})
	for l in target.loot:
		if not use_fine:
			_case_cells[_v2i(l.pos)] = true   # ohne feinen Grundriss blockiert die Vitrine ihr ganzes Feld
		loot[l.id] = {"id": l.id, "name": Texte.t(l.name), "pos": _v2i(l.pos), "value": int(l.value), "weight": float(l.weight), "size": l.size,"state": "ROOM", "carrier": "", "opened": bool(l.get("open", false)), "locked": not bool(l.get("open", false)), "leer": bool(l.get("leer", false))}
		loot_order.append(l.id)
	for g in target.guards:
		var st := _v2i(g.start)
		var route: Array = []
		for r in g.route:
			route.append(_v2i(r))
		guards.append({
			"id": g.id, "name": Texte.t(g.name), "type": g.type, "kampf": float(g.get("kampf", 0)),
			"pos": center(st), "route": route, "wp": 0, "path": [], "dwell": 0.0,
			"dwell_sec": float(g.dwell), "state": "PATROL", "suspicion": 0.0,
			"vision": float(g.vision), "hearing": float(g.hearing), "reaction": float(g.reaction), "effizienz": float(g.effizienz),
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
	car_laderaum = str(car_cfg.get("laderaum", "mittel"))
	police_v = 140.0 + float(target.get("guard_rate", 10.0)) * 0.25
	escape_km = float(target.get("escape_km", 10.0))
	# Wie im Original: Alle starten am Fluchtwagen, der Wagen steht dort bereit.
	car.called = true
	car.present = true
	car.arrive_at = 0.0
	for c0 in crew:
		c0.pos = center(escape_cell)
	_build_door_tiles()
	_log(Texte.t("sim.start"))

# ---------------------------------------------------------------- Schritt
func step(dt: float) -> void:
	if status != "RUNNING":
		return
	time += dt
	if alarm_active:
		_dispatch_patrols()
	if time > TIMEOUT:
		_end("ABBRUCH", Texte.t("end.zeitlimit"))
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
			_end("GEFASST", Texte.t("end.riegelt_ab"))
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
		_end("ABBRUCH", Texte.t("end.nicht_weg"))

## Schnelle Vorschau: läuft die Simulation ohne Anzeige bis zum Ende.
static func preview(target: Dictionary, team: Array, plans: Dictionary, car_cfg: Dictionary, karte := false) -> Dictionary:
	var s := Sim.create(target, team, plans, car_cfg, karte)
	var guard := 0
	while s.status == "RUNNING" and guard < 20000:
		s.step(DT)
		guard += 1
	return s.result()

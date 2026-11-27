class_name SimWachen
extends SimKarte
## Wachen, Alarm, Lärm, Patrouillen und die Sicht der Wachen.

## Eintreffzeit der Polizei je Alarmart. STILL = Alarmkontakt (Anlage meldet an die Zentrale), LAUT = Lärm, Melder, Wache.
func _eintreffzeit(kind: String) -> float:
	if kind == "PATROL":
		return PATROL_ALARM_BASE
	if kind == "STILL":
		return police_reaktion + police_fahrt * (1.0 + rng.randf_range(-GameData.FAHRT_SPANNE, GameData.FAHRT_SPANNE))
	return rng.randf_range(GameData.LAUT_MIN_S, GameData.LAUT_MAX_S)

func _alarm(source: String, kind: String, delay: float) -> void:
	if countdown >= 0.0:
		return
	alarm_source = source
	alarm_time = time
	countdown = _eintreffzeit(kind) + delay
	alarm_active = true
	events.append({"t": time, "end": time, "crew": "", "name": "", "kind": "ALARM", "obj": source, "tool": "", "ok": false, "fail": "", "msg": "", "alarm": true})
	_log(Texte.t("sim.alarm") % [source, countdown])

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
		_alarm(Texte.t("sim.laerm_quelle") % total, "QUIET", 0.0)

## Streife: in zufälligen Abständen fährt sie vorbei. Eine offene Tür oder ein offenes Fenster
## sieht sie und schlägt Alarm; geschlossene Türen fallen nicht auf.
func _check_patrols(_dt: float) -> void:
	if _next_patrol < 0.0:
		_next_patrol = rng.randf_range(GameData.PATROL_MIN_S, GameData.PATROL_MAX_S)
	if time < _next_patrol:
		return
	_next_patrol = time + rng.randf_range(GameData.PATROL_MIN_S, GameData.PATROL_MAX_S)
	patrol_count += 1
	# Eine Tür, die erst kurz offen ist, fällt nicht auf: in dieser Zeit kann der Einbrecher sie schließen
	var offen := false
	for p in open_cells:
		if doors.has(p) and time - float(open_since.get(p, -INF)) > GameData.PATROL_GRACE_S:
			offen = true
	if offen:
		_alarm("Streife", "QUIET", 0.0)
	else:
		_log(Texte.t("sim.streife_ok"))

func _dispatch_patrols() -> void:
	## Im Original rückt die Streife erst aus, wenn ein Alarm ausgelöst wurde
	## (Lärm, Wache, Sensor). Sie fährt dann zum Eingang.
	for g in guards:
		if g.type == "STREET" and g.state == "IDLE":
			g.state = "RESPOND"
			g.path = []
			g.target = points.get("aussen_eingang", Vector2i(1, 5))
			_log(Texte.t("sim.streife_alarm"))

## Öffnen von Hand: Das Schloss muss offen (entriegelt) sein. Dauert OPEN_TIME.
## Alarmkontakt: ein gesichertes Objekt, das bei eingeschalteter Anlage geöffnet wird, löst Alarm aus (wie im Original).
func _pruefe_alarmkontakt(id: String) -> void:
	if panel.is_empty() or panel.bypassed or not gesichert.has(id):
		return
	# Eintrittskarte vom Informanten: diese eine Tür bleibt ruhig
	if karte and id == karte_tuer:
		_log(Texte.t("sim.karte_tuer") % _disp(id))
		return
	_alarm(str(panel.name), "STILL", 0.0)

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
			_log(Texte.t("sim.hoert") % g.name)
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
			_log(Texte.t("sim.kontrolliert_alarm") % [g.name, what])

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
			_log(Texte.t("sim.beruhigt") % g.name)
		g.state = "PATROL"
		g.inv_arrived = false
		return
	if s < 40.0:
		if g.state != "ALERT":
			_log(Texte.t("sim.aufmerksam") % g.name)
		g.state = "ALERT"
		g.path = []
		return
	if s < 80.0:
		if g.state != "INVESTIGATE":
			_log(Texte.t("sim.spur") % g.name)
			g.inv_arrived = false
			g.path = []
		g.state = "INVESTIGATE"
		if target_cell.x >= 0:
			g.target = target_cell
		return
	g.state = "ALARMED"
	var kind := "PATROL" if g.type == "STREET" else "GUARD"
	_log(Texte.t("sim.schlaegt_alarm") % g.name)
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
				_log(Texte.t("sim.sucht_ab") % g.name)
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

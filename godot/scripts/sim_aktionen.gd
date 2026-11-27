class_name SimAktionen
extends SimWachen
## Aktionen der Einbrecherinnen: gehen, Werkzeug, Öffnen, Beute, Ausschalten, Fluchtwagen.

func _free_for(c: Dictionary, key: String) -> bool:
	if _busy.has(key) and _busy[key] != c.id:
		if not c.get("waiting", false):
			overlaps += 1
		var zeile: String = Texte.t("sim.wartet") % [c.name, _busy_name(key)]
		overlap_lines.append(zeile)
		_log(zeile)
		c["waiting"] = true
		c["msg"] = Texte.t("sim.msg_wartet") % _busy_name(key)
		return false
	c["waiting"] = false
	return true

func _lock(c: Dictionary, key: String) -> void:
	_busy[key] = c.id

func _busy_name(key: String) -> String:
	for x in crew:
		if x.id == _busy.get(key, ""):
			return x.name.split(" ")[0]
	return Texte.t("sim.einem_teammitglied")

func _unlock_all(c: Dictionary) -> void:
	for k in _busy.keys():
		if _busy[k] == c.id:
			_busy.erase(k)

func _next(c: Dictionary) -> void:
	_unlock_all(c)
	if c.idx < c.plan.size():
		# "fail": Grund, falls die Aktion nicht ausgeführt werden konnte
		var ev_a: Dictionary = c.plan[c.idx]
		events.append({"t": c.act_start, "end": time, "crew": c.id, "name": c.name, "kind": ev_a.t, "obj": _ev_obj(ev_a), "tool": GameData.TOOLS[ev_a.tool].name if ev_a.t == "TOOL" else "", "ok": str(c.get("fail", "")) == "", "fail": str(c.get("fail", "")), "msg": str(c.get("msg", "")), "alarm": false})
		c.segments.append({"i": c.idx, "t": c.plan[c.idx].t, "start": c.act_start, "end": time, "fail": str(c.get("fail", "")), "msg": str(c.get("msg", "")), "loud": float(c.get("loud", LOUD_STD)), "dur": float(c.get("dur", 0.0)) if c.plan[c.idx].t == "TOOL" else 0.0, "skill": float(c.skills.get(GameData.TOOLS[c.plan[c.idx].tool].type, 0)) if c.plan[c.idx].t == "TOOL" else 0.0})
		c["msg"] = ""
	c["fail"] = ""
	c.act_start = time
	c.idx += 1
	c.started = false
	c["loud"] = LOUD_STD
	c.path = []
	c.timer = 0.0

func _fail(c: Dictionary, text: String) -> void:
	_log(Texte.t("sim.fehler_prefix") % [c.name, text])
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
				_log(Texte.t("sim.wagen_ruf") % [c.name, car.eta])
			_next(c)
		"FLAG_SET":
			flags[a.flag] = true
			_log(Texte.t("sim.signal") % [c.name, Texte.t(GameData.FLAG_NAMES.get(a.flag, a.flag))])
			_next(c)
		"FLAG_WAIT":
			if flags.get(a.flag, false):
				_next(c)
		"OPEN":
			_do_open(c, a, dt)
		"CLOSE":
			_do_close(c, a, dt)
		"TREPPE":
			_do_stairs(c, a, dt)
		_:
			_next(c)

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
			_fail(c, Texte.t("fail.nicht_stehen") % c.name)
			return
		c.path = bfs(here, goal)
		if c.path.is_empty() and here != goal:
			_fail(c, Texte.t("fail.kein_weg") % _goal_name(a))
			return
		return
	if _walk(c, dt):
		if c.get("stuck", false):
			c["stuck"] = false
			_fail(c, Texte.t("fail.anstoss") % c.name)
			return
		_next(c)

func _goal_name(a: Dictionary) -> String:
	return _ziel_name(a)

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
			_fail(c, Texte.t("fail.nicht_vor") % [c.name, _disp(a.on)])
			return
		# Vorkenntnisse: Werkzeug braucht eine Mindeststufe der Fähigkeit (Original: tcGetNecessaryAbility / plCheckAbilities)
		if float(c.skills.get(tool.type, 0)) < float(tool.get("min", 0)):
			_fail(c, Texte.t("fail.vorkenntnisse") % [c.name, tool.name, Texte.t(GameData.TOOL_SKILL_KEY.get(tool.type, "skill.technik")), int(tool.min)])
			return
		# Schaufenster brauchen den Glasschneider, Türen und Vitrinen das Schloss-Werkzeug
		var needs := door_tool(door) if door != null else "schloss"
		if (is_panel and tool.obj != "alarm") or ((door != null or case_id != "") and tool.obj != needs):
			_fail(c, Texte.t("fail.ungeeignet") % [Texte.t(tool.name), _disp(a.on)])
			return
		# Entriegeln geht nur bei verschlossenen Schlössern (Original: LOCK_UNLOCK-Bit)
		if door != null and not door.locked:
			_fail(c, Texte.t("fail.schon_entriegelt") % _disp(a.on))
			return
		if case_id != "" and not loot[case_id].locked:
			_fail(c, Texte.t("fail.schon_entriegelt") % _disp(a.on))
			return
		var obj := 0.0
		if is_panel:
			obj = panel.cplx if tool.type in ["TECH", "ELECTRONICS"] else panel.res
		elif door != null:
			obj = door.cplx if tool.type in ["TECH", "ELECTRONICS"] else door.res
		elif case_id != "":
			obj = 40.0 if tool.type in ["TECH", "ELECTRONICS"] else 50.0
		else:
			_fail(c, Texte.t("fail.nichts_zu_oeffnen") % _disp(a.on))
			return
		if obj > float(tool.max):
			_fail(c, Texte.t("fail.zu_stabil") % [_disp(a.on), Texte.t(tool.name)])
			return
		var skill := float(c.skills.get(tool.type, 1))
		var dur: float = float(tool.time) * (1.0 + obj / 100.0) * (1.0 - skill / 150.0)
		var noise: float = float(tool.noise) * (1.0 + obj / 200.0) * (1.0 - skill / 200.0)
		c.noise = noise * float(c.gear.noise)
		c.ev = float(tool.evidence) * float(c.gear.ev)
		c.timer = maxf(dur, 0.5)
		c["dur"] = c.timer   # Werkzeugdauer dieser Person (für die Vorschau)
		c["loud"] = c.noise
		c.started = true
		_lock(c, key)
		_log(Texte.t("sim.werkzeug_an") % [c.name, Texte.t(tool.name), _disp(a.on)])
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	evidence += c.ev
	if is_panel:
		panel.bypassed = true
		for s in sensors:
			s.active = false
		_log(Texte.t("sim.bypass"))
	elif case_id != "":
		# Werkzeug entriegelt. Brecheisen bricht auf: dann ist die Vitrine auch offen.
		loot[case_id].locked = false
		if tool.destroys:
			loot[case_id].opened = true
			c["msg"] = Texte.t("sim.msg_aufgebrochen") % _case_word(loot[case_id])
			_log(Texte.t("sim.vitrine_aufgebrochen") % [c.name, _case_word(loot[case_id]), loot[case_id].name])
			_pruefe_alarmkontakt(case_id)
		else:
			c["msg"] = Texte.t("sim.msg_entriegelt") % _case_word(loot[case_id])
			if loot[case_id].get("leer", false):
				_log(Texte.t("sim.deko_entriegelt") % [c.name, loot[case_id].name])
			else:
				_log(Texte.t("sim.vitrine_entriegelt") % [c.name, _case_word(loot[case_id]), loot[case_id].name])
	elif door != null:
		door.locked = false
		if tool.destroys:
			door.destroyed = true
			open_cells[cell] = true
			c["msg"] = Texte.t("sim.msg_tuer_aufgebrochen")
			_log(Texte.t("sim.tuer_aufgebrochen") % _disp(a.on))
			_pruefe_alarmkontakt(str(door.id))
		else:
			c["msg"] = Texte.t("sim.msg_tuer_entriegelt")
			_log(Texte.t("sim.tuer_entriegelt") % _disp(a.on))
	_noise(center(cell), c.noise)
	c.used[tool.type] = int(c.used.get(tool.type, 0)) + 1
	_next(c)

## Tür wieder schließen. Nur Türen, die entriegelt (nicht aufgebrochen) und offen sind.
## Eine geschlossene Tür verdeckt wieder die Sicht und senkt so den Verdacht der Wachen.
func _do_close(c: Dictionary, a: Dictionary, dt: float) -> void:
	var cell := _cell_of(a, "on")
	var key := "obj:%d,%d" % [cell.x, cell.y]
	var door: Variant = doors.get(cell, null)
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(cell)):
			_fail(c, Texte.t("fail.nicht_vor") % [c.name, _disp(a.on)])
			return
		if door == null:
			_fail(c, Texte.t("fail.nichts_zu_schliessen") % _disp(a.on))
			return
		if door.destroyed:
			_fail(c, Texte.t("fail.aufgebrochen_zu") % _disp(a.on))
			return
		if not open_cells.has(cell):
			_fail(c, Texte.t("fail.schon_zu") % _disp(a.on))
			return
		c.started = true
		_lock(c, key)
		c.timer = CLOSE_TIME
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	open_cells.erase(cell)
	c["msg"] = Texte.t("sim.msg_tuer_zu")
	_log(Texte.t("sim.tuer_zu") % [c.name, _disp(a.on)])
	_noise(center(cell), 4.0)
	_next(c)

func _do_open(c: Dictionary, a: Dictionary, dt: float) -> void:
	var cell := _cell_of(a, "on")
	var key := "obj:%d,%d" % [cell.x, cell.y]
	var case_id := _case_at(cell)
	var door: Variant = doors.get(cell, null)
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(cell)):
			_fail(c, Texte.t("fail.nicht_vor") % [c.name, _disp(a.on)])
			return
		if door != null:
			if door.locked:
				_fail(c, Texte.t("fail.verschlossen") % _disp(a.on))
				return
			if open_cells.has(cell):
				_fail(c, Texte.t("fail.schon_offen") % _disp(a.on))
				return
		elif case_id != "":
			if loot[case_id].locked:
				_fail(c, Texte.t("fail.verschlossen") % _disp(a.on))
				return
			if loot[case_id].opened:
				_fail(c, Texte.t("fail.schon_offen") % _disp(a.on))
				return
		else:
			_fail(c, Texte.t("fail.nichts_zu_oeffnen") % _disp(a.on))
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
		c["msg"] = Texte.t("sim.msg_tuer_offen")
		_log(Texte.t("sim.oeffnet") % [c.name, _disp(a.on)])
	else:
		loot[case_id].opened = true
		c["msg"] = Texte.t("sim.msg_offen") % _case_word(loot[case_id])
		if loot[case_id].get("leer", false):
			_log(Texte.t("sim.deko_oeffnet") % [c.name, loot[case_id].name])
		else:
			_log(Texte.t("sim.oeffnet_vitrine") % [c.name, _case_word(loot[case_id]), loot[case_id].name])
	_pruefe_alarmkontakt(str(door.id) if door != null else case_id)
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
		_fail(c, Texte.t("fail.wache_weg"))
		return
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, g.pos):
			_fail(c, Texte.t("fail.nicht_vor_wache") % [c.name, g.name])
			return
		if g.state == "ALARMED":
			_fail(c, Texte.t("fail.zu_spaet") % g.name)
			return
		# Kampf der Wache gegen Kampf der Person (Original: tcGuyUsesTool, Kampf verkürzt die Zeit)
		var k := float(c.skills.get("FORCE", 1))
		var gk := float(g.get("kampf", 0))
		var methode := str(a.get("method", "knock"))
		var chance := GameData.wache_chance(methode, k, gk)
		if chance <= 0.0:
			if methode == "chloroform":
				var ch: Dictionary = GameData.TOOLS.chloroform
				_fail(c, Texte.t("fail.vorkenntnisse") % [c.name, ch.name, Texte.t(GameData.TOOL_SKILL_KEY.get("FORCE", "skill.technik")), int(ch.min)])
			else:
				_fail(c, Texte.t("fail.wehrt_sich") % g.name)
			return
		if chance < 1.0 and rng.randf() > chance:
			_fail(c, Texte.t("fail.wache_misslingt") % [c.name, g.name])
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
	_log(Texte.t("sim.ausschalten") % [c.name, g.name, "Chloroform" if chloro else "Niederschlagen"])
	_next(c)

## Treppe: die Person steht auf dem Treppenfeld, braucht 8 s und ist danach auf der anderen Etage.
func _do_stairs(c: Dictionary, a: Dictionary, dt: float) -> void:
	var here := anchor_of(Vector2i(floori(c.pos.x), floori(c.pos.y)))
	if not stairs.has(here):
		_fail(c, Texte.t("fail.keine_treppe") % c.name)
		return
	if not c.started:
		c.started = true
		c.timer = STAIRS_TIME
		_log(Texte.t("sim.treppe_steigt") % c.name)
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	c.pos = center(stairs[here])
	c.path = []
	_log(Texte.t("sim.treppe_fertig") % c.name)
	_next(c)

func _do_take(c: Dictionary, a: Dictionary, dt: float) -> void:
	if not loot.has(a.loot):
		_fail(c, Texte.t("fail.nicht_vor_beute") % c.name)
		return
	var l: Dictionary = loot[a.loot]
	var key := "loot:%s" % a.loot
	if not c.started:
		if not _free_for(c, key):
			return
		if not _reach(c, center(l.pos)):
			_fail(c, Texte.t("fail.nicht_vor_beute") % c.name)
			return
		if l.get("leer", false) and l.get("durchsucht", false):
			_fail(c, Texte.t("fail.schon_durchsucht") % l.name)
			return
		if l.state != "ROOM":
			_fail(c, Texte.t("fail.schon_weg") % l.name)
			return
		if not l.opened:
			_fail(c, Texte.t("fail.vitrine_zu") % [_case_word(l), l.name])
			return
		var carried := 0.0
		for lid in c.carried:
			carried += float(loot[lid].weight)
		if carried + float(l.weight) > float(c.capacity):
			_fail(c, Texte.t("fail.tragkraft") % [l.name, int(l.weight), c.name.split(" ")[0], int(float(c.capacity) - carried), int(c.capacity)])
			return
		# Fluchtwagen: ein Stück passt nur, wenn seine Größe nicht über dem Laderaum liegt
		if GameData.SIZE_RANK[l.size] > GameData.SIZE_RANK[car_laderaum]:
			_fail(c, Texte.t("fail.volumen") % [l.name, Texte.t("size." + l.size), Texte.t("size." + car_laderaum)])
			return
		c.started = true
		_lock(c, key)
		c.timer = LOOT_TIME
		return
	c.timer -= dt
	if c.timer > 0.0:
		return
	if l.get("leer", false):
		# Dekoration: durchsucht, aber nichts drin
		l["durchsucht"] = true
		c["msg"] = Texte.t("sim.msg_leer")
		_log(Texte.t("sim.leer") % [c.name, l.name])
		_next(c)
		return
	l.state = "CARRIED"
	l.carrier = c.id
	c.carried.append(l.id)
	c["msg"] = Texte.t("sim.msg_genommen") % Texte.t(str(l.name))
	_log(Texte.t("sim.nimmt") % [c.name, l.name])
	_next(c)

func _update_car() -> void:
	if car.called and not car.present and time >= float(car.arrive_at):
		car.present = true
		_log(Texte.t("sim.wagen_wartet"))

func _check_escape() -> void:
	## Der Wagen fährt erst los, wenn alle Einbrecherinnen am Wagen sitzen.
	if status != "RUNNING" or departed:
		return
	for c in crew:
		# Erst wenn jede Person ihren Plan abgeschlossen hat und am Wagen steht
		if not c.done or cheb(cell_of(c.pos), escape_cell) > 1:
			return
	departed = true
	_log(Texte.t("sim.wagen_faehrt") % car.eta)
	# Die Polizei darf nicht vor dem Wagen am Ausgang sein
	if countdown >= 0.0 and countdown <= float(car.eta):
		_end("GEFASST", Texte.t("end.erreicht_strasse"))
		return
	# Verfolgung (wie Original tcCalcCarEscape): Die Polizei fährt los, sobald sie am Ausgang ist.
	# Sie holt den Wagen ein, wenn ihr Tempo reicht und die Strecke vorher noch nicht zu Ende ist.
	if countdown >= 0.0:
		var verdict := chase_result(car_v, police_v, countdown, escape_km)
		chase = verdict
		if verdict == "GEFASST":
			_end("GEFASST", Texte.t("end.holt_ein") % escape_km)
			return
		if verdict == "KNAPP":
			_log(Texte.t("sim.knapp"))
	var total := 0
	for c in crew:
		for lid in c.carried:
			loot[lid].state = "DELIVERED"
			total += int(loot[lid].value)
	payout = int(round(total * 0.6))
	if total == 0:
		_end("ABBRUCH", Texte.t("end.ohne_beute"))
		return
	if alarm_active:
		_end("ENTKOMMEN_HEISS", Texte.t("end.entkommt_heiss"))
	else:
		_end("ENTKOMMEN", Texte.t("end.entkommt"))

## Abbruch (Funk): alle Einbrecherinnen gehen sofort zurück zum Wagen.
func abort() -> void:
	if status != "RUNNING":
		return
	_log(Texte.t("sim.funk_abbruch"))
	for c in crew:
		_unlock_all(c)
		c.plan = [{"t": "MOVE", "to": "fluchtwagen"}]
		c.idx = 0
		c.started = false
		c.path = []
		c.timer = 0.0
		c.done = false

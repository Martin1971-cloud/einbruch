class_name PlannerAktion
extends PlannerDaten
## Planer, Ablauf: Aktionen bearbeiten, Speichern, Vorschau und Wiedergabe, Klicks auf den Grundriss.

func _on_floor(fl: Dictionary) -> void:
	var rows: Array = fl.rows
	_grid.view_floor = _floor_list().find(fl)
	_grid.queue_redraw()
	_grid.focus_on(Vector2(10, (float(rows[0]) + float(rows[1])) * 0.5), 1.0, true)  # ganze Etage sichtbar, dann selbst vergrößern
	_preview.text = Texte.t("plan.etage_angezeigt") % Texte.t(str(fl.name))

## Schriftgröße für Ablaufplan und Vorschau, zwischen TEXT_MIN und TEXT_MAX.
func _set_text_size(v: int) -> void:
	_text_size = clampi(v, TEXT_MIN, TEXT_MAX)
	if _text_lbl != null:
		_text_lbl.text = str(_text_size)
	for rt in [_steps_rt, _preview]:
		if rt != null:
			rt.add_theme_font_size_override("normal_font_size", _text_size)
	if _gantt != null:
		_gantt.text_size = _text_size - 2  # Zeitleiste etwas kleiner als die Textfelder
		_gantt.queue_redraw()
	# Team und Knöpfe der Zeitleiste folgen dem Regler
	if _timeline_col != null:
		_shrink_text(_timeline_col, _text_size)
	if _team_box != null:
		_refresh_team()

## Pulldown zum Bearbeiten einer Aktion (öffnet sich beim Klick auf den Balken).
func _open_editor(crew_id: String, idx: int) -> void:
	var plan: Array = plans.get(crew_id, [])
	if idx < 0 or idx >= plan.size():
		return
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UI.card_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(440, 0)
	pop.add_child(v)
	v.add_child(_l(Texte.t("plan.aktion_bearbeiten"), 11, Color(0.89, 0.71, 0.35)))
	var ed := Lane.new(crew_id)
	ed.setup(plan, _options)
	ed.changed.connect(_on_changed)
	ed.changed.connect(func(): pop.queue_free())
	v.add_child(ed._row(idx))
	v.add_child(UI.button(Texte.t("plan.schliessen"), func(): pop.queue_free(), 120))
	add_child(pop)
	pop.popup_centered(Vector2i(460, 150))

func _refresh_all() -> void:
	_refresh_grid()
	_refresh_team()
	_refresh_checklist()

func _refresh_grid() -> void:
	var lvl: int = int(Game.intel.get(target.id, 0))
	_grid.set_state(target, lvl, plans, Game.team)
	_intel_label.text = Texte.t("stadt.ermittlung") % Texte.t(Game.ermittlung_key(target.id))

func _refresh_team() -> void:
	for c in _team_box.get_children():
		c.queue_free()
	_team_btns = {}
	_team_box.add_child(_l(Texte.t("plan.person_waehlen"), 12, Color(0.89, 0.71, 0.35)))
	for i in range(Game.team.size()):
		var c: Dictionary = Game.team[i]
		var role: String = Texte.t(str(c.get("role", "")))
		var b := UI.button("%d   %s%s" % [i + 1, c.name, "  ·  " + role if role != "" else ""], _on_pick.bind(c.id), 0)
		b.set_meta("base", b.text)
		b.add_theme_font_size_override("font_size", _text_size)
		b.custom_minimum_size = Vector2(0, 24)
		b.toggle_mode = true
		b.button_pressed = _active == c.id
		b.custom_minimum_size = Vector2(0, 36)
		var sk: Dictionary = c.skills
		var parts: Array = []
		for k in sk:
			parts.append("%s %d %%" % [{"TECH": Texte.t("skill.technik"), "FORCE": Texte.t("skill.kampf"), "ELECTRONICS": Texte.t("skill.elektronik"), "FAHREN": Texte.t("skill.fahren")}.get(k, k), int(sk[k])])
		b.tooltip_text = Texte.t("plan.faehig_tip") % ", ".join(parts)
		var col: Color = CREW_COL.get(c.id, Color.WHITE)
		b.add_theme_color_override("font_color", col)
		# Gewählte Person: farbiger Rahmen und Hintergrund in der Personenfarbe
		if _active == c.id:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(col, 0.22)
			sb.set_border_width_all(2)
			sb.border_color = col
			sb.set_corner_radius_all(4)
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, sb)
		# Tickbox: angehakt = diese Person ist ausgewählt (auch über die Zahlentasten)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var cb := CheckBox.new()
		cb.button_pressed = _active == c.id
		cb.toggled.connect(_on_check.bind(c.id))
		row.add_child(cb)
		# Farbpunkt: dieselbe Farbe wie die Aktionsmarken im Grundriss
		var dot := ColorRect.new()
		dot.color = col
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_team_box.add_child(row)
		_team_btns[c.id] = b
	if not Game.driver.is_empty():
		_team_box.add_child(_l(Texte.t("plan.fahrer_zeile") % [Game.driver.name, int(Game.driver.skills.FAHREN)], 12, Color(0.85, 0.85, 0.9)))
	# Teamgröße mit Kosten (sofort) und voraussichtlicher Zeit (nach der ersten Vorschau): die Abwägung bewusst treffen
	var kosten_team: int = Game.team_fee_total() + (0 if Game.driver.is_empty() or Game.team.any(func(c): return c.id == Game.driver.get("id", "")) else int(Game.driver.get("fee", 0))) + int(GameData.car_now(Game.car_id, 85.0).get("rent", 0))
	var zeit_txt: String = Sim.clock(float(_res.get("time", 0.0))) if _res.has("time") else Texte.t("plan.zeit_offen")
	_team_box.add_child(_l(Texte.t("plan.team_abwaegung") % [Game.team.size(), _fmt(kosten_team), zeit_txt], 12, Color(0.92, 0.85, 0.55)))
	_team_box.add_child(_l(Texte.t("plan.aktion_anklicken"), 12, Color(0.89, 0.71, 0.35)))
	_shrink_text(_team_box, _text_size)
	_update_team_floors()

## Person auswählen (Team-Schaltfläche, Klick auf die Figur im Grundriss oder Zahlentaste 1 bis 9).
func _on_pick(id: String) -> void:
	_active = id
	_grid.selected_id = id
	_grid.follow = true  # Auswahl stellt das Folgen beim Abspielen wieder her
	# Ansicht gleitet auf die gewählte Person (Startposition), damit man sie sofort findet
	for c in Game.team:
		if c.id == id and c.has("start"):
			_grid.focus_on(Vector2(Sim._v2i(c.start)), GridView.FOCUS_ZOOM, true)
	_refresh_team()
	_preview.text = Texte.t("plan.ausgewaehlt_hinweis") % _crew_name(_active)

## Tickbox neben einer Person: an = auswählen, aus = Auswahl aufheben.
func _on_check(on: bool, id: String) -> void:
	if on:
		_on_pick(id)
	elif _active == id:
		_active = ""
		_grid.selected_id = ""
		_refresh_team()
		_preview.text = Texte.t("plan.keine_person")

func _add(id: String, action: Dictionary) -> void:
	plans[id].append(action)
	_history.append(id)

## Tab: nächste (Shift+Tab: vorige) Person im Team wählen.
func _cycle_pick(d: int) -> void:
	var n := Game.team.size()
	var idx := 0
	for i in range(n):
		if Game.team[i].id == _active:
			idx = i
	_on_pick(Game.team[posmod(idx + d, n)].id)

func _refresh_saved_list() -> void:
	if _saved_opt == null:
		return
	_saved_opt.clear()
	for e in _saved_for_target():
		_saved_opt.add_item(str(e.name))

## Planung speichern: Name aus dem Feld (sonst „Planung N“). Gleicher Name überschreibt.
func _save_plan() -> void:
	var nm := _plan_name.text.strip_edges()
	var list: Array = _saved_for_target().duplicate(true)
	if nm == "":
		nm = Texte.t("plan.planung_nr") % (list.size() + 1)
	var ids: Array = []
	for c in Game.team:
		ids.append(c.id)
	var entry := {"name": nm, "team": ids, "plans": plans.duplicate(true)}
	var replaced := false
	for i in range(list.size()):
		if str(list[i].name) == nm:
			list[i] = entry
			replaced = true
	if not replaced:
		list.append(entry)
	Game.saved_plans[target.id] = list
	Game.save_game()
	_refresh_saved_list()
	_preview.text = Texte.t("plan.gespeichert") % nm

## Gespeicherte Planung laden. Nur Personen, die im Team sind, bekommen ihren Plan.
func _load_plan() -> void:
	var idx := _saved_opt.selected
	var list := _saved_for_target()
	if idx < 0 or idx >= list.size():
		return
	var entry: Dictionary = list[idx]
	for c in Game.team:
		plans[c.id] = entry.plans.get(c.id, []).duplicate(true) if entry.plans.has(c.id) else []
	_on_changed()
	_preview.text = Texte.t("plan.geladen") % entry.name

func _undo() -> void:
	if _history.is_empty():
		_preview.text = Texte.t("plan.nichts_zurueck")
		return
	var id: String = _history.pop_back()
	if plans[id].is_empty():
		_undo()
		return
	var segs: Array = _res.get("segments", {}).get(id, []) if _res != null else []
	var last_idx: int = plans[id].size() - 1
	plans[id].pop_back()
	_on_changed()
	for s in segs:
		if int(s.get("i", -1)) == last_idx:
			_playhead = float(s.start)
	_preview.text = Texte.t("plan.zurueckgenommen") % _crew_name(id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or (event.keycode == KEY_Z and event.ctrl_pressed)):
		_undo()
		return
	# Tastenkürzel: Leertaste spielt ab, Tab wechselt die Person, Entf nimmt die letzte Aktion zurück
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_play()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB and not Game.team.is_empty():
			_cycle_pick(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_DELETE:
			_undo()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.keycode - KEY_0
		if n >= 1 and n <= Game.team.size():
			_on_pick(Game.team[n - 1].id)

func _on_palette(kind: String) -> void:
	if _active == "":
		_preview.text = Texte.t("plan.zuerst_person")
		return
	_on_dropped(_active, kind)

func _refresh_checklist() -> void:
	for c in _checklist.get_children():
		c.queue_free()
	var quelle: Dictionary = Game.quelle_of(target.id)
	var hat_umsehen := int(quelle.get("look", 0)) >= 1
	var hat_informant := bool(quelle.get("inf", false))
	var has_door := false
	var has_car_call := false
	var has_car_move := false
	for c in Game.team:
		for a in plans[c.id]:
			if a.t == "TOOL":
				has_door = true
			if a.t == "CALL_CAR":
				has_car_call = true
			if a.t == "MOVE" and a.get("to", "") == "fluchtwagen":
				has_car_move = true
	var items := [
		[Texte.t("plan.chk_info"), hat_umsehen or hat_informant],
		[Texte.t("plan.chk_grundriss"), true],
		[Texte.t("plan.chk_sicherheit"), hat_informant],
		[Texte.t("plan.chk_zugang"), has_door],
		[Texte.t("plan.chk_flucht"), all_at_car()],
	]
	for it in items:
		var h := HBoxContainer.new()
		var lbl := _l(it[0], 13, Color(0.9, 0.9, 0.92))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lbl)
		h.add_child(_l("✓" if it[1] else "○", 15, Color(0.4, 0.9, 0.5) if it[1] else Color(0.5, 0.55, 0.62)))
		_checklist.add_child(h)

func _on_dropped(crew_id: String, kind: String) -> void:
	var action := _default_action(kind)
	if action.t == "TOOL" and not Game.tools_owned.has(action.tool):
		_preview.text = Texte.t("plan.kein_werkzeug")
		return
	_add(crew_id, action)
	_on_changed()

func _on_changed() -> void:
	_refresh_grid()
	_refresh_checklist()
	_on_preview()

## Knopf Texte.t("plan.vorschau"): berechnet den Plan und spielt den ganzen Einbruch von vorn ab (alle Personen, Aktionen).
func _on_vorschau() -> void:
	_on_preview()
	_playhead = 0.0
	_play_until = -1.0
	_playing = not (_res.get("frames", []) as Array).is_empty()
	_grid.follow = _playing
	_play_btn.text = Texte.t("plan.pause") if _playing else Texte.t("plan.abspielen")
	_show_at(0.0)

func _on_preview() -> void:
	var cfg := _config()
	var res := Sim.preview(cfg.target, cfg.team, cfg.plans, cfg.car)
	_refresh_timeline(res)
	var msgs: Array = []
	if not _problems.is_empty():
		msgs.append(Texte.t("plan.n_aktionen_kaputt") % _problems.size())
		for p in _problems:
			msgs.append("[color=salmon]✗ %s[/color]" % p)
		msgs.append("[color=gray]%s[/color]" % Texte.t("plan.gesperrt_hinweis"))
	for c in Game.team:
		var pl: Array = plans[c.id]
		var ends_at_car: bool = not pl.is_empty() and pl[-1].t == "MOVE" and pl[-1].get("to", "") == "fluchtwagen"
		if not ends_at_car:
			msgs.append("[color=orange]%s[/color]" % (Texte.t("plan.endet_nicht") % c.name.split(" ")[0]))
	# Warnung: zwei Personen wollen gleichzeitig an einem Objekt arbeiten. Die Simulation lässt eine warten.
	# Alarm durch Sensor oder Lärm: der auslösende Melder wird genannt
	if str(res.get("alarm_source", "")) != "":
		msgs.append("[color=salmon]⚠ %s[/color]" % (Texte.t("sim.alarm") % [res.alarm_source, float(res.get("alarm_time", 0.0))]).split(" Police", 1)[0])
	for line in res.get("ueberschneidung_zeilen", []):
		msgs.append("[color=orange]%s[/color]" % (Texte.t("plan.ueberschneidung") % str(line)))
	var color := "salmon"
	match res.status:
		"ENTKOMMEN":
			color = "lightgreen"
		"ENTKOMMEN_HEISS":
			color = "yellow"
	msgs.append("[color=%s][b]%s[/b][/color] – %s" % [color, _status_text(res.status), res.reason])
	msgs.append(Texte.t("plan.beute_zeile") % _loot_text(res.loot_taken))
	msgs.append(Texte.t("plan.wagen_laderaum") % Texte.t("size." + str(res.get("car_laderaum", "mittel"))))
	msgs.append_array(_duration_lines(res))
	# Lautstärke: lauteste Aktion gegen die Grenze des Gebäudes (Original: Lärm löst den Alarm aus)
	var peak: float = float(res.get("peak_loud", 0.0))
	var lim: float = float(res.get("max_volume", 0.0))
	var lcol := "lightgreen" if peak <= lim * 0.7 else ("yellow" if peak <= lim else "salmon")
	if peak > LOUD_HINT_DB:
		_show_hint.call_deferred("laut")
	# Farbe UND Wort: die Bedeutung hängt nicht allein an der Farbe (Barrierefreiheit)
	var lwort := Texte.t("laerm.leise") if peak <= lim * 0.7 else (Texte.t("laerm.hoerbar") if peak <= lim else Texte.t("laerm.alarm"))
	msgs.insert(1, Texte.t("plan.lautstaerke") % [lcol, int(peak), lwort, int(lim)])
	msgs.append(Texte.t("plan.auszahlung_zeile") % [_fmt(int(res.payout)), int(res.heat)])
	# Teamgröße mit Kosten und Dauer: der Spieler wägt Gewinn gegen Zeit ab
	var team_n: int = Game.team.size()
	var fee_sum: int = Game.team_fee_total()
	var drv_fee := 0
	var drv_in_team := false
	for c in Game.team:
		if not Game.driver.is_empty() and c.id == Game.driver.get("id", ""):
			drv_in_team = true
	if not Game.driver.is_empty() and not drv_in_team:
		drv_fee = int(Game.driver.get("fee", 0))
	var rent: int = int(GameData.car_now(Game.car_id, 85.0).get("rent", 0))
	var cost: int = fee_sum + drv_fee + rent
	var net: int = int(res.payout) - cost
	msgs.insert(0, Texte.t("plan.team_zeile") % [team_n, _fmt(cost), _fmt(fee_sum + drv_fee), _fmt(rent), "+" if net >= 0 else "", _fmt(net), Sim.clock(float(res.time))])
	_preview.text = "\n".join(msgs)

func _refresh_timeline(res: Dictionary) -> void:
	var crew_info: Array = []
	for i in range(Game.team.size()):
		var c: Dictionary = Game.team[i]
		crew_info.append({"id": c.id, "name": "%d  %s" % [i + 1, c.name], "color": CREW_COL.get(c.id, Color.WHITE)})
	_res = res
	_labels = {}
	for c in Game.team:
		var labs: Array = []
		for a in plans[c.id]:
			labs.append(_describe(a))
		_labels[c.id] = labs
	var mx := maxf(float(res.time), 10.0)   # Zeitleiste endet beim Plan, nicht bei einer festen Mindestlänge
	_gantt.set_data(res.get("segments", {}), _labels, crew_info, mx, float(res.get("alarm_time", -1.0)))
	_slider.max_value = mx
	_slider.set_value_no_signal(clampf(_playhead, 0.0, mx))
	_show_at(_playhead)
	var entries: Array = []
	_problems = []
	_grid.set_planned_obj(res.get("states", {}))
	for c in Game.team:
		var segs: Array = res.segments.get(c.id, [])
		var plan: Array = plans[c.id]
		for seg in segs:
			var idx := int(seg.i)
			var act: Dictionary = plan[idx] if idx < plan.size() else {"t": seg.t}
			var span := "[color=#f0c060]%s–%s[/color]" % [Sim.clock(float(seg.start)), Sim.clock(float(seg.end))]
			var who: String = c.name.split(" ")[0]
			if str(seg.get("fail", "")) != "":
				_problems.append("%s: %s" % [who, seg.fail])
				entries.append({"start": float(seg.start), "text": "%s  [color=salmon]✗ %s: %s[/color]" % [span, who, _describe(act)]})
				continue
			var res_txt := ""
			if str(seg.get("msg", "")) != "":
				res_txt = "  [color=lightgreen]→ %s[/color]" % seg.msg
			entries.append({"start": float(seg.start), "text": "%s  %s: %s%s" % [span, who, _describe(act), res_txt]})
	entries.sort_custom(func(a, b): return a.start < b.start)
	var lines: Array = []
	for e in entries:
		lines.append(e.text)
	if lines.is_empty():
		lines.append("[color=gray]%s[/color]" % Texte.t("plan.keine_aktionen"))
	_steps_rt.text = "\n".join(lines)

func _on_play() -> void:
	_grid.follow = true  # beim Abspielen der gewählten Person folgen
	if _playhead >= float(_slider.max_value):
		_playhead = 0.0
	_playing = not _playing
	_play_until = -1.0
	_play_btn.text = Texte.t("plan.pause") if _playing else Texte.t("plan.abspielen")

func _on_speed_pick(i: int) -> void:
	_speed = [1.0, 2.0, 4.0, 8.0][i]

func _on_speed() -> void:
	_speed = {1.0: 2.0, 2.0: 4.0, 4.0: 8.0, 8.0: 1.0}.get(_speed, 2.0)
	_speed_btn.text = "%dx" % int(_speed)

func _on_slider(v: float) -> void:
	_playhead = v
	_show_at(v)

func _seek(t: float) -> void:
	_slider.set_value_no_signal(t)
	_on_slider(t)

func _process(delta: float) -> void:
	if not _playing:
		return
	_playhead += delta * _speed
	var mx := float(_slider.max_value)
	if _play_until >= 0.0 and _playhead >= _play_until:
		_playhead = _play_until
		_play_until = -1.0
		_playing = false
		_play_btn.text = Texte.t("plan.abspielen")
	if _playhead >= mx:
		_playhead = mx
		_playing = false
		_play_btn.text = Texte.t("plan.abspielen")
	_slider.set_value_no_signal(_playhead)
	_show_at(_playhead)

func _show_at(t: float) -> void:
	var frames: Array = _res.get("frames", [])
	if frames.is_empty():
		return
	_grid.show_end = not _playing
	_grid.set_frame(_interp_frame(frames, t), _res.get("noise", []))
	_gantt.set_playhead(t)
	_time_lbl.text = Sim.clock(t)   # keine Gesamtzeit: die Dauer richtet sich nach den Personen, nur die Polizei setzt eine Grenze
	_update_team_floors()

## Ausführung: bei mehreren gespeicherten Plänen zuerst fragen, mit welchem Plan der Einbruch laufen soll.
func _on_execute() -> void:
	if _saved_for_target().size() > 1:
		_ask_plan_for_execution()
		return
	_run_execution()

func _ask_plan_for_execution() -> void:
	var pop := PopupPanel.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(340, 0)
	box.add_child(_l(Texte.t("plan.welcher_plan"), 15, Color(0.97, 0.85, 0.55)))
	box.add_child(UI.button(Texte.t("plan.aktuell"), func() -> void:
		pop.hide()
		_run_execution(), 0))
	for e in _saved_for_target():
		box.add_child(UI.button(str(e.name), func() -> void:
			pop.hide()
			_apply_saved(e)
			_run_execution(), 0))
	box.add_child(UI.button(Texte.t("ui.abbrechen"), func() -> void: pop.hide(), 0))
	pop.add_child(box)
	add_child(pop)
	pop.popup_centered()

## Gespeicherte Planung in die aktuelle Planung übernehmen (ohne Vorschau-Text).
func _apply_saved(entry: Dictionary) -> void:
	for c in Game.team:
		plans[c.id] = entry.plans.get(c.id, []).duplicate(true) if entry.plans.has(c.id) else []
	_on_changed()

func _run_execution() -> void:
	_on_preview()
	# Jede Person muss am Ende am Fluchtwagen stehen, sonst kommt das Team nicht vom Gelände
	for c in Game.team:
		var pl: Array = plans[c.id]
		var ends_at_car: bool = not pl.is_empty() and pl[-1].t == "MOVE" and pl[-1].get("to", "") == "fluchtwagen"
		if not ends_at_car:
			_problems.append(Texte.t("plan.endet_nicht_letzte") % c.name.split(" ")[0])
	if not _problems.is_empty():
		_preview.text = Texte.t("plan.gesperrt_kopf") % [_problems.size(), _preview.text]
		return
	main.go("execution", {"config": _config()})

## Testhilfe: Beispielplan mit Lockpick an der Eingangstür, Gemälde, Fluchtwagen.
func _on_example() -> void:
	if Game.target_id == "kiosk":
		var kex := {
			"teo": [
				{"t": "MOVE", "to": "aussen_eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
				{"t": "OPEN", "on": "eingangstuer"},
				{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
				{"t": "TOOL", "tool": "lockpick", "on": "kasse"},
				{"t": "OPEN", "on": "kasse"},
				{"t": "TAKE", "loot": "kasse"},
				{"t": "CALL_CAR"},
				{"t": "MOVE", "to": "fluchtwagen"},
			],
			"ilja": [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "MOVE", "to": "fluchtwagen"}],
			"rosa": [{"t": "MOVE", "to": "fluchtwagen"}],
		}
		for id in plans:
			plans[id] = kex[id].duplicate(true) if kex.has(id) else []
		_on_changed()
		return
	var ex := {
		"teo": [
			{"t": "MOVE", "cell": [0, 5]}, {"t": "MOVE", "cell": [1, 5]},
			{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
			{"t": "OPEN", "on": "eingangstuer"},
			{"t": "MOVE", "cell": [5, 5]}, {"t": "MOVE", "cell": [5, 4]},
			{"t": "TOOL", "tool": "lockpick", "on": "gemaelde"},
			{"t": "OPEN", "on": "gemaelde"},
			{"t": "TAKE", "loot": "gemaelde"},
			{"t": "CALL_CAR"},
			{"t": "MOVE", "to": "fluchtwagen"},
		],
		"ilja": [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "MOVE", "to": "fluchtwagen"}],
		"rosa": [{"t": "MOVE", "to": "fluchtwagen"}],
	}
	for id in plans:
		plans[id] = ex[id].duplicate(true) if ex.has(id) else []
	_on_changed()

func _on_back() -> void:
	main.go("organisation")

## Einmaliger Hinweis (nach dem Klick, damit er das Menü nicht stört).
func _show_hint(id: String) -> void:
	if not Game.hint_once(id):
		return
	var h: Dictionary = GameData.HINTS[id]
	var dlg := AcceptDialog.new()
	dlg.title = Texte.t(str(h.title))
	dlg.dialog_text = Texte.t(str(h.text))
	dlg.ok_button_text = Texte.t("hint.verstanden")
	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(460, 0))

func _on_map_click(cell: Vector2i) -> void:
	if _active == "" and not Game.team.is_empty():
		_on_pick(Game.team[0].id)
	# Hinweise: Schaufenster und Treppe beim ersten Anklicken
	for d in target.get("doors", []):
		if Sim._v2i(d.pos) == cell and str(d.get("kind", "")) == "glas":
			_show_hint.call_deferred("glas")
	for pr in target.get("treppen", []):
		if cell == Vector2i(int(pr[0]), int(pr[1])) or cell == Vector2i(int(pr[2]), int(pr[3])):
			_show_hint.call_deferred("treppe")
	_menu_entries = []
	# Freier Punkt: genau dorthin gehen, wenn er begehbar ist (Wände, Fenster, Vitrinen und Türen sind nicht erlaubt)
	var f := _click_fine
	if f.x >= 0 and Sim.plan_tile(target, f) in ["o", "."]:
		_menu_entries.append([Texte.t("plan.hierher_gehen"), {"t": "MOVE", "fine": [f.x, f.y]}, true])
	elif _walkable(cell):
		_menu_entries.append([Texte.t("plan.hierher_gehen"), {"t": "MOVE", "cell": [cell.x, cell.y]}, true])
	# Am Fluchtwagen: einsteigen = Plan beenden (Original: Rückkehr zum Wagen, plLivingsPosAtCar)
	if cell == Sim._v2i(target.points.fluchtwagen):
		_menu_entries.append([Texte.t("plan.einsteigen"), {"t": "BOARD"}, true])
	# Treppenfeld: die Person steigt auf die andere Etage (8 s)
	for pr in target.get("treppen", []):
		if cell == Vector2i(int(pr[0]), int(pr[1])) or cell == Vector2i(int(pr[2]), int(pr[3])):
			# Zuerst zur Treppe gehen (approach), dann steigen
			_menu_entries.append([Texte.t("plan.treppe_steigen"), {"t": "TREPPE", "approach": [cell.x, cell.y]}, true])
	_menu_entries.append_array(_object_entries(cell))
	if target.has("panel") and Sim._v2i(target.panel.pos) == cell:
		_menu_entries.append([Texte.t("plan.bypass"), {"t": "TOOL", "tool": "bypass", "on": target.panel.id}, Game.tools_owned.has("bypass")])
	for g in target.guards:
		if Sim._v2i(g.start) == cell:
			_menu_entries.append(_wache_eintrag(g, "knock", Texte.t("plan.wache_niederschlagen")))
			_menu_entries.append(_wache_eintrag(g, "chloroform", Texte.t("plan.chloroform"), Game.tools_owned.has("chloroform")))
	if _menu == null:
		_menu = PopupMenu.new()
		add_child(_menu)
		_menu.id_pressed.connect(_on_menu_pick)
	_menu.clear()
	for i in range(_menu_entries.size()):
		var tex := _menu_icon(_menu_entries[i][1])
		if tex != null:
			_menu.add_icon_item(tex, _menu_entries[i][0], i)
		else:
			_menu.add_item(_menu_entries[i][0], i)
		_menu.set_item_disabled(i, not _menu_entries[i][2])
	_menu.position = Vector2i(get_viewport().get_mouse_position())
	_menu.popup()

## Nach einem neuen Schritt: die Zeitleiste spielt genau diesen Schritt ab (die Person läuft dorthin).
func _watch_last(crew_id: String) -> void:
	var segs: Array = _res.get("segments", {}).get(crew_id, [])
	if segs.is_empty():
		return
	var seg: Dictionary = segs[-1]
	if int(seg.get("i", -1)) != plans[crew_id].size() - 1:
		return
	_playhead = float(seg.start)
	_play_until = float(seg.end)
	_playing = true
	_play_btn.text = Texte.t("plan.pause")

## Kampfsport der gewählten Person (Fahrer ohne Kampfsport zählt mit 1, wie in der Simulation).
func _kampf_von(id: String) -> float:
	for c in Game.team:
		if c.id == id:
			return float(c.skills.get("FORCE", 1))
	if not Game.driver.is_empty() and Game.driver.get("id", "") == id:
		return float(Game.driver.get("skills", {}).get("FORCE", 1))
	return 1.0


## Menüeintrag für eine Wache: nicht möglich bei zu geringem Kampfsport, riskant im Grenzbereich.
func _wache_eintrag(g: Dictionary, methode: String, name: String, werkzeug_da: bool = true) -> Array:
	var chance := GameData.wache_chance(methode, _kampf_von(_active), float(g.get("kampf", 0)))
	var label := name
	if not werkzeug_da:
		return [label, {"t": "NEUTRALIZE", "guard": g.id, "method": methode}, false]
	if chance <= 0.0:
		label += Texte.t("plan.wache_zu_schwach")
		return [label, {"t": "NEUTRALIZE", "guard": g.id, "method": methode}, false]
	if chance < 1.0:
		label += Texte.t("plan.wache_riskant")
	return [label, {"t": "NEUTRALIZE", "guard": g.id, "method": methode}, true]


func _on_menu_pick(i: int) -> void:
	var e: Array = _menu_entries[i]
	var act: Dictionary = e[1].duplicate(true)
	if act.t == "BOARD":
		# Einsteigen: den Wagen rufen (falls noch nicht geschehen) und zum Wagen gehen
		if not _has_call_car(_active):
			_add(_active, {"t": "CALL_CAR"})
		_add(_active, {"t": "MOVE", "to": "fluchtwagen"})
		_on_changed()
		_watch_last(_active)
		_preview.text = Texte.t("plan.steigt_ein") % _crew_name(_active)
		return
	if act.has("approach"):
		# Erst von der gegenüberliegenden Seite kommen, dann auf das Ziel zugehen (Blickrichtung)
		_add(_active, {"t": "MOVE", "cell": act.approach})
		act.erase("approach")
	_add(_active, act)
	_on_changed()
	_watch_last(_active)
	_preview.text = "[color=lightgreen]%s: %s[/color]" % [_crew_name(_active), e[0]]

extends PlannerAktion
## Planungsphase: großer Grundriss in der Mitte, Team und Ablauf rechts,
## Vorhaben und Aktionen links, Zeitplan unten. Aktionen per Drag & Drop.
## Der Aufbau der Oberfläche. Die Regeln stehen in planner_daten.gd und planner_aktion.gd.

func _ready() -> void:
	_text_size = clampi(int(Game.settings.text_size), TEXT_MIN, TEXT_MAX)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Neutraler Hintergrund: die Fläche gehört dem Grundriss
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Büro-Bild über die ganze Fläche, nur schwach sichtbar: Menüs stehen davor
	var pic := UI.backdrop("res://assets/art/bg_schreibtisch.webp")
	pic.modulate = Color(1, 1, 1, 0.5)
	add_child(pic)
	target = GameData.target_now(Game.stufe_of(Game.target_id), Game.target_id)
	for c in Game.team:
		plans[c.id] = []
		c["start"] = target.points["fluchtwagen"]
	_build_options()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Vertikal scrollbar, damit die Planung auch auf kleinen Bildschirmen ins Fenster passt
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# Die ganze Fläche ausfüllen: Außenrand, Inhalt und Zeilen wachsen mit dem Fenster
	var mg := UI.margin(root, 12)
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(mg)
	root.add_child(_header())

	var row_a := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 10)
	row_a.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row_a)
	# Layout: Ort, Vorbereitung, Team, Ablauf und Vorschau links; Grundriss rechts davon
	var right := _right_column()
	var left := _left_column()
	var idx := 0
	for c in left.get_children():
		left.remove_child(c)
		right.add_child(c)
		right.move_child(c, idx)
		idx += 1
	left.queue_free()
	row_a.add_child(right)  # Informationen und Team links
	row_a.add_child(_center_column())  # Grundriss in der Mitte
	row_a.add_child(_side_column())  # Ablaufplan und Vorschau rechts neben dem Grundriss

	var row_b := HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 10)
	# Höhe teilen: Grundriss und Zeitleiste bekommen beide Platz (Zeitleiste etwa ein Drittel)
	row_a.size_flags_stretch_ratio = 2.0
	row_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_b.size_flags_stretch_ratio = 1.0
	root.add_child(row_b)
	row_b.add_child(_timeline_card())

	_refresh_all()
	if not Game.team.is_empty():
		_on_pick(Game.team[0].id)
	_on_preview()

# ---------------------------------------------------------------- Aufbau
func _header() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := _l(Texte.t("app.titel"), 24, Color(0.97, 0.82, 0.42))
	row.add_child(title)
	row.add_child(_l(Texte.t("plan.titel"), 15, Color(0.62, 0.7, 0.8)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	# Reihenfolge wie der Ablauf: Vorbereitung (Stadt, Organisation), Planung, Vorschau, Ausführung
	row.add_child(UI.button(Texte.t("nav.stadt"), func(): main.go("town"), 100))
	row.add_child(UI.button(Texte.t("nav.organisation"), func(): main.go("organisation"), 130))
	var tab := UI.primary(Texte.t("plan.titel"), func(): pass, 100)
	tab.disabled = true
	row.add_child(tab)
	if GameData.TESTHILFEN:
		row.add_child(UI.button(Texte.t("plan.beispiel"), _on_example, 170))
	var vor_btn := UI.button(Texte.t("plan.vorschau"), _on_vorschau, 100)
	vor_btn.tooltip_text = Texte.t("plan.vorschau_tip")
	row.add_child(vor_btn)
	row.add_child(UI.primary(Texte.t("plan.ausfuehrung_btn"), _on_execute, 150))
	row.add_child(_l(Texte.t("plan.tag_zeit") % [Game.day, Game.clock_text()], 15, Color(0.85, 0.88, 0.94)))
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", UI.card_style(Color(0.05, 0.07, 0.12, 0.7)))
	wrap.add_child(row)
	return wrap

func _left_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(LEFT_W, 0)
	col.add_theme_constant_override("separation", 10)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	var photo_path := "res://assets/art/location_%s.png" % target.id
	if not ResourceLoader.exists(photo_path):
		photo_path = "res://assets/art/location_%s.jpg" % target.id
	var art: Control
	if ResourceLoader.exists(photo_path):
		var pic := TextureRect.new()
		pic.texture = load(photo_path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Ganzes Foto zeigen: Seitenverhältnis bleibt, nichts wird abgeschnitten
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 150)
		art = pic
	else:
		var building := BuildingArt.new()
		building.map = target.map
		art = building
	info.add_child(art)
	info.add_child(_l(Texte.t("plan.vorhaben"), 11, Color(0.6, 0.66, 0.74)))
	info.add_child(_l(Texte.t(target.name), 17, Color(0.97, 0.85, 0.55)))
	info.add_child(_l(Texte.t("plan.beutewert") % GameData.loot_text(target, int(Game.intel.get(target.id, 0))), 13, Color(0.85, 0.88, 0.94)))
	var polizei := _l(Texte.t("plan.polizei") % GameData.police_text(target, bool(Game.quelle_of(target.id).get("inf", false))), 12, Color(0.85, 0.88, 0.94))
	polizei.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(polizei)
	var laut := _l(Texte.t("plan.polizei_laut") % ["%d" % roundi(GameData.LAUT_MIN_S / 60.0), "%d" % roundi(GameData.LAUT_MAX_S / 60.0)], 12, Color(0.85, 0.88, 0.94))
	info.add_child(laut)
	if target.has("panel"):
		var alarm := _l(Texte.t("plan.alarm_sichert") % _gesichert_namen(target), 12, Color(0.6, 0.85, 1.0))
		alarm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(alarm)
		var status := _l(Texte.t("grid.alarm_aus") if _alarm_aus_im_plan() else Texte.t("grid.alarm_aktiv"), 12, Color(0.95, 0.5, 0.45) if not _alarm_aus_im_plan() else Color(0.6, 0.62, 0.68))
		info.add_child(status)
	col.add_child(_card(info))
	_checklist = VBoxContainer.new()
	_checklist.add_theme_constant_override("separation", 4)
	col.add_child(UI.fold(Texte.t("plan.vorbereitung"), _checklist, false))
	return col

func _center_column() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_child(_l(Texte.t("plan.grundriss") if _floor_list().is_empty() else Texte.t("plan.grundriss_etagen"), 13, Color(0.97, 0.85, 0.55)))
	# Etagen-Reiter: Klick zentriert die Etage (groß)
	for fl in _floor_list():
		head.add_child(UI.button(Texte.t(str(fl.name)), _on_floor.bind(fl), 64))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_intel_label = _l("", 12, Color(0.6, 0.85, 1.0))
	_intel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_intel_label)
	inner.add_child(head)
	_grid = GridView.new()
	_grid.backdrop = load("res://assets/art/bg_schreibtisch.webp")
	_grid.backdrop_alpha = 0.2   # im Grundriss tritt das Bild zurück, das Gebäude steht vorn
	_grid.cell_clicked.connect(_on_map_click)
	_grid.point_clicked.connect(func(f: Vector2i) -> void: _click_fine = f)
	_grid.describe = _describe
	_grid.person_clicked.connect(_on_pick)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_grid)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 16)
	legend.add_theme_constant_override("v_separation", 2)
	for i in range(Game.team.size()):
		var tc: Dictionary = Game.team[i]
		legend.add_child(_legend_row(CREW_COL.get(tc.id, Color.WHITE), "%d = %s" % [i + 1, tc.name]))
	legend.add_child(_legend_row(Color(0.85, 0.85, 0.9), Texte.t("plan.leg_weg")))
	legend.add_child(_legend_row(Color(1.0, 0.32, 0.32), Texte.t("plan.leg_wache")))
	legend.add_child(_legend_row(Color(0.3, 0.9, 1.0), Texte.t("plan.leg_sensor")))
	legend.add_child(_legend_row(Color(0.55, 0.36, 0.2), Texte.t("plan.leg_tuer")))
	legend.add_child(_legend_row(Color(0.98, 0.8, 0.35), Texte.t("plan.leg_beute")))
	legend.add_child(_legend_row(Color(1.0, 0.85, 0.2), Texte.t("plan.leg_sicht")))
	legend.add_child(_legend_row(Color(0.9, 0.9, 1.0), Texte.t("plan.leg_geraeusch")))
	legend.add_child(_legend_row(Color(1.0, 0.6, 0.25), Texte.t("plan.leg_verdacht")))
	legend.visible = false
	inner.add_child(legend)
	head.add_child(UI.button(Texte.t("plan.legende"), func(): legend.visible = not legend.visible, 120))
	var help_btn := UI.button("?", func(): pass, 36)
	help_btn.tooltip_text = Texte.t("plan.hilfe_gesamt")
	head.add_child(help_btn)
	var mid_card := _card(inner)
	mid_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid_card)
	return col

func _right_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(RIGHT_W, 0)
	col.add_theme_constant_override("separation", 10)
	_team_box = VBoxContainer.new()
	_team_box.add_theme_constant_override("separation", 5)
	var team_fold := UI.fold(Texte.t("plan.team"), _team_box, true)
	team_fold.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Team nutzt den restlichen Platz links
	col.add_child(team_fold)
	return col

## Spalte rechts neben dem Grundriss: Ablaufplan und Vorschau, Schriftgröße einstellbar.
func _side_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SIDE_W, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	# Schriftgröße: A− und A+, Mindestwert TEXT_MIN
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	size_row.add_child(_l(Texte.t("plan.schrift"), 12, Color(0.85, 0.85, 0.9)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(sp)
	size_row.add_child(UI.button("A−", func() -> void: _set_text_size(_text_size - 1), 36))
	_text_lbl = _l(str(_text_size), 12, Color(0.85, 0.85, 0.9))
	size_row.add_child(_text_lbl)
	size_row.add_child(UI.button("A+", func() -> void: _set_text_size(_text_size + 1), 36))
	col.add_child(size_row)
	_steps_rt = RichTextLabel.new()
	_steps_rt.bbcode_enabled = true
	_steps_rt.fit_content = false
	_steps_rt.scroll_following = false
	_steps_rt.custom_minimum_size = Vector2(0, 40)
	_steps_rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_steps_rt.size_flags_stretch_ratio = 1.0
	_steps_rt.add_theme_color_override("default_color", Color(0.88, 0.9, 0.94))
	_steps_rt.add_theme_font_size_override("normal_font_size", _text_size)
	# Ablaufplan und Vorschau scrollen im eigenen Bereich, damit der Text die Höhe der Seite nicht vergrößert
	var steps_scroll := ScrollContainer.new()
	steps_scroll.custom_minimum_size = Vector2(0, 30)
	steps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	steps_scroll.add_child(_steps_rt)
	_steps_rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var steps_fold := UI.fold(Texte.t("plan.ablauf"), steps_scroll, true)
	steps_fold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(steps_fold)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.custom_minimum_size = Vector2(0, 40)
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_stretch_ratio = 1.0
	_preview.add_theme_color_override("default_color", Color(0.85, 0.87, 0.9))
	_preview.add_theme_font_size_override("normal_font_size", _text_size)
	var prev_scroll := ScrollContainer.new()
	prev_scroll.custom_minimum_size = Vector2(0, 30)
	prev_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev_scroll.add_child(_preview)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_fold := UI.fold(Texte.t("plan.vorschau"), prev_scroll, true)
	preview_fold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(preview_fold)
	return col

func _timeline_card() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	_play_btn = UI.button(Texte.t("plan.abspielen"), _on_play, 130)
	_play_btn.tooltip_text = Texte.t("plan.play_tip")
	bar.add_child(_play_btn)
	_speed_btn = UI.dropdown(["1x", "2x", "4x", "8x"], 1, _on_speed_pick)
	bar.add_child(_speed_btn)
	# Letzte Aktion zurücknehmen: dort, wo die Aktionen auch bearbeitet werden (Original: Escape = RemLastAction)
	var undo_btn := UI.button(Texte.t("plan.letzte_zurueck"), _undo, 170)
	undo_btn.tooltip_text = Texte.t("plan.undo_tip")
	bar.add_child(undo_btn)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 120.0
	_slider.step = 0.1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(_on_slider)
	bar.add_child(_slider)
	_time_lbl = _l("00:00 / 00:00", 13, Color(0.9, 0.9, 0.95))
	bar.add_child(_time_lbl)
	col.add_child(bar)
	# Speichern und Laden in derselben Zeile wie die Abspielsteuerung: die Zeitleiste bekommt die volle Höhe
	bar.add_child(_vsep())
	_plan_name = LineEdit.new()
	_plan_name.placeholder_text = Texte.t("plan.name")
	_plan_name.custom_minimum_size = Vector2(150, 0)
	bar.add_child(_plan_name)
	var save_btn := UI.button(Texte.t("plan.speichern"), _save_plan, 110)
	save_btn.tooltip_text = Texte.t("plan.save_tip")
	bar.add_child(save_btn)
	_saved_opt = OptionButton.new()
	_saved_opt.custom_minimum_size = Vector2(150, 0)
	bar.add_child(_saved_opt)
	var load_btn := UI.button(Texte.t("plan.laden"), _load_plan, 80)
	load_btn.tooltip_text = Texte.t("plan.load_tip")
	bar.add_child(load_btn)
	_refresh_saved_list()
	_gantt = Gantt.new()
	_gantt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gantt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gantt.seek.connect(_seek)
	_gantt.dropped.connect(_on_dropped)
	_gantt.bar_clicked.connect(_open_editor)
	col.add_child(_gantt)
	_gantt.tooltip_text = Texte.t("plan.gantt_tip")
	# Schriftzüge der Leiste etwas kleiner, damit mehr Platz für die Personen bleibt
	_timeline_col = col
	_shrink_text(col, _text_size)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := _card(col, Texte.t("plan.zeitplan"))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card

func _vsep() -> Control:
	var v := ColorRect.new()
	v.color = Color(0.4, 0.45, 0.55, 0.6)
	v.custom_minimum_size = Vector2(1, 26)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return v

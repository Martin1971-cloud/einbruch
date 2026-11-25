extends Control
## Planungsphase: großer Grundriss in der Mitte, Team und Ablauf rechts,
## Vorhaben und Aktionen links, Zeitplan unten. Aktionen per Drag & Drop.

var main: Node
var args: Dictionary = {}

var target: Dictionary
var plans := {}
var _grid: GridView
var _gantt: Gantt
var _preview: RichTextLabel
var _steps_rt: RichTextLabel
var _options := {}
var _checklist: VBoxContainer
var _team_box: VBoxContainer
var _intel_label: Label
var _res: Dictionary = {}
var _labels := {}
var _playing := false
var _play_until := -1.0  # beim Abspielen einer neuen Aktion: bei dieser Sekunde anhalten
var _speed := 2.0
var _playhead := 0.0
var _play_btn: Button
var _speed_btn: Button
var _slider: HSlider
var _time_lbl: Label
var _active := ""          # ausgewählte Person im Team
var _team_btns := {}

const CREW_COL := GridView.COLORS
const LOUD_HINT_DB := 5.5  # ab diesem Lärm erklärt der Hinweis „Lärm“ (über dem Gehen)
const ROLE_OF := {"mira": "Planerin", "ilja": "Elektronik", "teo": "Einsteiger", "rosa": "Muskel"}
const LEFT_W := 270
const RIGHT_W := 250
const SIDE_W := 200   # Spalte rechts neben dem Grundriss: Ablaufplan und Vorschau
const TEXT_MIN := 10  # kleinste Schriftgröße in Ablaufplan und Vorschau
const TEXT_MAX := 18
var _text_size := 13
var _text_lbl: Label
var _timeline_col: Control


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
		c["start"] = target.points["Fluchtwagen"]
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
	info.add_child(_l(Texte.d(target.name), 17, Color(0.97, 0.85, 0.55)))
	info.add_child(_l(Texte.t("plan.beutewert") % GameData.loot_text(target, int(Game.intel.get(target.id, 0))), 13, Color(0.85, 0.88, 0.94)))
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
		head.add_child(UI.button(str(fl.name), _on_floor.bind(fl), 64))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_intel_label = _l("", 12, Color(0.6, 0.85, 1.0))
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


## Etagen des Ziels (leer = eine Etage).
func _floor_list() -> Array:
	return target.get("floors", [])


func _on_floor(fl: Dictionary) -> void:
	var rows: Array = fl.rows
	_grid.focus_on(Vector2(10, (float(rows[0]) + float(rows[1])) * 0.5), 1.8, true)
	_preview.text = "Etage %s angezeigt." % str(fl.name)


## Etage eines Feldes (Zeile der Karte). "" wenn das Ziel keine Etagen hat.
func _floor_name_at_row(y: float) -> String:
	for fl in _floor_list():
		if y >= float(fl.rows[0]) and y < float(fl.rows[1]):
			return str(fl.name)
	return ""


## Etage einer Person: an ihrer Stelle im Ablauf (Abspielmarke), sonst am Start.
func _crew_floor(id: String) -> String:
	if _floor_list().is_empty():
		return ""
	var y := -1.0
	var frames: Array = _res.get("frames", [])
	if not frames.is_empty():
		var f := _interp_frame(frames, _playhead)
		if f.has("crew") and f.crew.has(id):
			y = float(f.crew[id][1]) / float(Sim.SUB)
	if y < 0.0:
		for c in Game.team:
			if c.id == id and c.has("start"):
				y = float(Sim._v2i(c.start).y)
	return _floor_name_at_row(y)


## Etagenangabe in den Team-Schaltflächen aktualisieren (beim Abspielen mit).
func _update_team_floors() -> void:
	for id in _team_btns:
		var b: Button = _team_btns[id]
		var base: String = str(b.get_meta("base", b.text))
		var fl := _crew_floor(id)
		b.text = base if fl == "" else "%s  ·  %s" % [base, fl]


func _legend_row(col: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var swatch := ColorRect.new()
	swatch.color = col
	swatch.custom_minimum_size = Vector2(14, 10)
	h.add_child(swatch)
	h.add_child(_l(text, 12, Color(0.8, 0.84, 0.9)))
	return h


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


func _palette_card() -> Control:
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	for line in [Texte.t("plan.hilfe_1"), Texte.t("plan.hilfe_2"), Texte.t("plan.hilfe_3"), Texte.t("plan.hilfe_4")]:
		info.add_child(_w(line, 12, Color(0.82, 0.86, 0.92)))
	var card := UI.fold(Texte.t("plan.hilfe_titel"), info, false)  # standardmäßig zu, Platz für den Zeitplan
	card.custom_minimum_size = Vector2(LEFT_W, 0)
	return card


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


## Setzt die Schriftgröße für Schaltflächen, Eingaben und Auswahlfelder unterhalb von node.
func _shrink_text(node: Node, size: int) -> void:
	for c in node.get_children():
		if c is Button or c is LineEdit or c is OptionButton or c is Label or c is CheckBox:
			c.add_theme_font_size_override("font_size", size)
		_shrink_text(c, size)


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


## Karte mit einheitlichem Stil; optional mit Titel.
func _card(content: Control, title := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if title != "":
		v.add_child(_l(title.to_upper(), 11, Color(0.89, 0.71, 0.35)))
	v.add_child(content)
	return p


func _l(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	## Einzeilige Beschriftung ohne Umbruch.
	var lbl := UI.label(t, size, col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl


func _w(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	## Mehrzeilige Beschriftung, darf umbrechen.
	return UI.label(t, size, col)


# ---------------------------------------------------------------- Daten

func _build_options() -> void:
	var points: Array = []
	var names: Array = target.points.keys()
	names.sort()
	for n in names:
		points.append([n, n])
	var tools: Array = []
	for tid in GameData.TOOLS:
		if Game.tools_owned.has(tid):
			tools.append([Texte.d(GameData.TOOLS[tid].name), tid])
	var doors: Array = []
	for d in target.doors:
		doors.append([d.name, d.name])
	if target.has("panel"):
		doors.append([target.panel.name, target.panel.name])
	for l in target.loot:
		doors.append([l.name, l.name])
	var loot: Array = []
	for l in target.loot:
		loot.append([l.name, l.id])
	var flags: Array = []
	for f in GameData.FLAGS:
		flags.append([GameData.FLAG_NAMES[f], f])
	var guards: Array = []
	for g in target.guards:
		guards.append([g.name, g.id])
	_options = {"points": points, "tools": tools, "doors": doors, "loot": loot, "flags": flags, "guards": guards}


func _loot_value() -> int:
	var total := 0
	for l in target.loot:
		total += int(l.value)
	return total


func _refresh_all() -> void:
	_refresh_grid()
	_refresh_team()
	_refresh_checklist()


func _refresh_grid() -> void:
	var lvl: int = int(Game.intel.get(target.id, 0))
	_grid.set_state(target, lvl, plans, Game.team)
	_intel_label.text = Texte.t("stadt.ermittlung") % Texte.t("stadt.ermittlung_%d" % lvl)


func _refresh_team() -> void:
	for c in _team_box.get_children():
		c.queue_free()
	_team_btns = {}
	_team_box.add_child(_l(Texte.t("plan.person_waehlen"), 12, Color(0.89, 0.71, 0.35)))
	for i in range(Game.team.size()):
		var c: Dictionary = Game.team[i]
		var role: String = Texte.d(ROLE_OF.get(c.id, ""))
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


## Jede neue Aktion merken, damit man sie wieder zurücknehmen kann (Original: Escape = RemLastAction).
var _history: Array = []


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


## Letzte Aktion zurücknehmen. Die Zeit springt an den Anfang dieser Aktion zurück.
func _has_call_car(id: String) -> bool:
	for a in plans.get(id, []):
		if a.t == "CALL_CAR":
			return true
	return false


var _plan_name: LineEdit
var _saved_opt: OptionButton


func _saved_for_target() -> Array:
	return Game.saved_plans.get(target.id, [])


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
		nm = "Planung %d" % (list.size() + 1)
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


## Jede Einbrecherin muss den Plan am Fluchtwagen beenden.
func all_at_car() -> bool:
	for c in Game.team:
		var pl: Array = plans[c.id]
		if pl.is_empty() or not (pl[-1].t == "MOVE" and pl[-1].get("to", "") == "Fluchtwagen"):
			return false
	return not Game.team.is_empty()


func _crew_name(id: String) -> String:
	for c in Game.team:
		if c.id == id:
			return c.name
	return id


func _refresh_checklist() -> void:
	for c in _checklist.get_children():
		c.queue_free()
	var intel_lvl: int = int(Game.intel.get(target.id, 0))
	var has_door := false
	var has_car_call := false
	var has_car_move := false
	for c in Game.team:
		for a in plans[c.id]:
			if a.t == "TOOL":
				has_door = true
			if a.t == "CALL_CAR":
				has_car_call = true
			if a.t == "MOVE" and a.get("to", "") == "Fluchtwagen":
				has_car_move = true
	var items := [
		[Texte.t("plan.chk_info"), intel_lvl >= 1],
		[Texte.t("plan.chk_grundriss"), true],
		[Texte.t("plan.chk_sicherheit"), intel_lvl >= 2],
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


func _initials(full_name: String) -> String:
	var s := ""
	for p in full_name.split(" "):
		if p != "":
			s += p.substr(0, 1)
	return s.substr(0, 2)


var _problems: Array = []  # Aktionen, die in der Vorschau nicht ausgeführt werden können


func _describe(a: Dictionary) -> String:
	match a.t:
		"MOVE":
			if a.has("fine"):
				return Texte.t("res.geh_nach") % Texte.d(_point_label(Vector2i(int(a.fine[0]), int(a.fine[1]))))
			if a.has("cell"):
				return Texte.t("res.geh_nach") % Texte.d(_name_at(a.cell))
			return Texte.t("res.geh_nach") % Texte.d(str(a.get("to", "?")))
		"TOOL":
			return "%s an %s" % [Texte.d(GameData.TOOLS[a.tool].name), Texte.d(a.on)]
		"OPEN":
			return Texte.t("plan.oeffnen_obj") % Texte.d(a.on)
		"TAKE":
			return Texte.t("plan.beute_nehmen")
		"WAIT":
			return "Warten %d s" % int(a.sec)
		"TREPPE":
			return Texte.t("plan.treppe")
		"CALL_CAR":
			return Texte.t("plan.wagen_rufen")
		"NEUTRALIZE":
			return "Wache ausschalten: %s" % _guard_name(a.guard)
		"FLAG_SET":
			return "Signal: %s" % GameData.FLAG_NAMES.get(a.flag, a.flag)
		_:
			return Texte.t("plan.warte_signal")


# ---------------------------------------------------------------- Aktionen

func _default_action(kind: String) -> Dictionary:
	match kind:
		"MOVE":
			return {"t": "MOVE", "to": "Halle"}
		"TOOL":
			return {"t": "TOOL", "tool": _first_tool(), "on": "Eingangstür"}
		"TAKE":
			return {"t": "TAKE", "loot": "gemaelde"}
		"OPEN":
			return {"t": "OPEN", "on": "Eingangstür"}
		"WAIT":
			return {"t": "WAIT", "sec": 5.0}
		"NEUTRALIZE":
			return {"t": "NEUTRALIZE", "guard": target.guards[0].id if not target.guards.is_empty() else ""}
		"CALL_CAR":
			return {"t": "CALL_CAR"}
		"FLAG_SET":
			return {"t": "FLAG_SET", "flag": "tuer"}
		_:
			return {"t": "FLAG_WAIT", "flag": "tuer"}


func _first_tool() -> String:
	for tid in GameData.TOOLS:
		if Game.tools_owned.has(tid):
			return tid
	return "lockpick"


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


func _config() -> Dictionary:
	var team: Array = []
	for c in Game.team:
		team.append(c)
	var skill := float(Game.driver.get("skills", {}).get("FAHREN", 85))
	var car: Dictionary = GameData.car_now(Game.car_id, skill)  # gewähltes Fahrzeug (gemietet oder gekauft)
	return {"target": target, "team": team, "plans": plans, "car": car}


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
		var ends_at_car: bool = not pl.is_empty() and pl[-1].t == "MOVE" and pl[-1].get("to", "") == "Fluchtwagen"
		if not ends_at_car:
			msgs.append("[color=orange]%s[/color]" % (Texte.t("plan.endet_nicht") % c.name.split(" ")[0]))
	# Warnung: zwei Personen wollen gleichzeitig an einem Objekt arbeiten. Die Simulation lässt eine warten.
	# Alarm durch Sensor oder Lärm: der auslösende Melder wird genannt
	if str(res.get("alarm_source", "")) != "":
		msgs.append("[color=salmon]⚠ %s[/color]" % (Texte.t("sim.alarm") % [res.alarm_source, float(res.get("alarm_time", 0.0))]).split(" Police", 1)[0])
	for line in res.log:
		if str(line).contains("wartet, bis") or str(line).contains("waits until"):
			msgs.append("[color=orange]%s[/color]" % (Texte.t("plan.ueberschneidung") % str(line).split("] ", 1)[-1]))
	var color := "salmon"
	match res.status:
		"ENTKOMMEN":
			color = "lightgreen"
		"ENTKOMMEN_HEISS":
			color = "yellow"
	msgs.append("[color=%s][b]%s[/b][/color] – %s" % [color, _status_text(res.status), res.reason])
	msgs.append(Texte.t("plan.beute_zeile") % _loot_text(res.loot_taken))
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


## Werkzeugdauer je Person: Dauer und Fähigkeit, die sie dafür mitbringt.
func _duration_lines(res: Dictionary) -> Array:
	var out: Array = []
	var segs: Dictionary = res.get("segments", {})
	for c in Game.team:
		var parts: Array = []
		for seg in segs.get(c.id, []):
			if str(seg.t) != "TOOL" or str(seg.fail) != "" or float(seg.dur) <= 0.0:
				continue
			var a: Dictionary = plans[c.id][int(seg.i)]
			var tool: Dictionary = GameData.TOOLS[a.tool]
			var skill_name := Texte.t(GameData.TOOL_SKILL_KEY.get(tool.type, "skill.technik"))
			parts.append("%s: %s s (%s %d)" % [_describe(a), ("%.1f" % float(seg.dur)).replace(".", ","), skill_name, int(seg.skill)])
		if not parts.is_empty():
			out.append("[color=gray]%s:[/color] %s" % [c.name.split(" ")[0], " · ".join(parts)])
	if out.is_empty():
		return out
	out.insert(0, Texte.t("plan.dauer_je_person"))
	return out


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
		lines.append("[color=gray]Noch keine Aktionen geplant.[/color]")
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


func _status_text(s: String) -> String:
	match s:
		"ENTKOMMEN":
			return Texte.t("status.entkommen")
		"ENTKOMMEN_HEISS":
			return Texte.t("status.entkommen_heiss")
		"GEFASST":
			return Texte.t("status.festgenommen")
		_:
			return Texte.t("status.abbruch")


func _loot_text(list: Array) -> String:
	if list.is_empty():
		return Texte.t("journal.beute_keine")
	return ", ".join(list)


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
	box.add_child(UI.button("Aktuelle Planung (ungespeichert)", func() -> void:
		pop.hide()
		_run_execution(), 0))
	for e in _saved_for_target():
		box.add_child(UI.button(str(e.name), func() -> void:
			pop.hide()
			_apply_saved(e)
			_run_execution(), 0))
	box.add_child(UI.button("Abbrechen", func() -> void: pop.hide(), 0))
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
		var ends_at_car: bool = not pl.is_empty() and pl[-1].t == "MOVE" and pl[-1].get("to", "") == "Fluchtwagen"
		if not ends_at_car:
			_problems.append(Texte.t("plan.endet_nicht_letzte") % c.name.split(" ")[0])
	if not _problems.is_empty():
		_preview.text = Texte.t("plan.gesperrt_kopf") % [_problems.size(), _preview.text]
		return
	main.go("execution", {"config": _config()})


## Möglichkeiten an einer Tür oder Vitrine, abhängig vom Zustand am Ende der Planung
## (Original: verschlossen -> entriegeln oder aufbrechen; entriegelt -> öffnen; offen -> Beute nehmen).
func _object_entries(cell: Vector2i) -> Array:
	var out: Array = []
	var st: Dictionary = _res.get("states", {}).get("%d,%d" % [cell.x, cell.y], {}) if _res != null else {}
	if st.is_empty():
		return out
	var nm: String = st.name
	var what := Texte.t("plan.leg_tuer") if st.kind == "door" else str(st.get("word", Texte.t("obj.vitrine")))
	# Crosscheck wie im Original: Objekt nur in Blickrichtung der Person erreichbar (plGetObjectsList)
	var stand := _stand_after(_active)
	if absi(stand.cell.x - cell.x) + absi(stand.cell.y - cell.y) != 1:
		var nb := _neighbor_of(cell, stand.cell)
		out.append(["%s: zu weit weg" % Texte.d(nm), {}, false])
		if nb != Vector2i(-1, -1):
			out.append([Texte.t("plan.neben_gehen") % Texte.d(nm), {"t": "MOVE", "cell": [nb.x, nb.y]}, true])
		return out
	if st.locked:
		# Alle Werkzeuge für Schlösser, die man besitzt (Original: Werkzeugliste am Objekt)
		var any := false
		for tid in GameData.TOOLS:
			var t: Dictionary = GameData.TOOLS[tid]
			# Schaufenster: nur Glasschneider; Türen und Vitrinen: Schloss-Werkzeuge
			var needs := str(st.get("needs", "schloss"))
			if t.obj != needs or not Game.tools_owned.has(tid):
				continue
			any = true
			var how := "aufbrechen (laut, dann offen)" if t.destroys else "entriegeln"
			out.append(["%s %s: %s" % [what, how, Texte.d(t.name)], {"t": "TOOL", "tool": tid, "on": nm}, true])
		if not any:
			out.append([Texte.t("plan.kein_passendes_werkzeug") % what, {}, false])
	elif not st.open:
		out.append([Texte.t("plan.von_hand") % what, {"t": "OPEN", "on": nm}, true])
	if st.kind == "case":
		var lid := ""
		for l in target.loot:
			if l.name == nm:
				lid = l.id
		var kg := 0
		for l in target.loot:
			if l.name == nm:
				kg = int(l.weight)
		out.append([Texte.t("plan.beute_nehmen_kg") % [Texte.d(nm), kg] if st.open else Texte.t("plan.beute_erst_oeffnen") % Texte.d(nm), {"t": "TAKE", "loot": lid}, bool(st.open)])
	return out


## Symbol zu einer Aktion im Menü.
func _menu_icon(a: Dictionary) -> Texture2D:
	var name := ""
	match a.get("t", ""):
		"MOVE":
			name = "walk"
		"OPEN":
			name = "open"
		"TAKE":
			name = "take"
		"NEUTRALIZE":
			name = "guard"
		"TOOL":
			match a.get("tool", ""):
				"lockpick", "schlosstecher", "bohrmaschine":
					name = "lockpick"
				"crowbar", "hammer", "axt", "glasschneider":
					name = "crowbar"
				"bypass":
					name = "alarm"
				"chloroform":
					name = "guard"
				_:
					name = "unlock"
		"CALL_CAR":
			name = "car"
		"WAIT":
			name = "wait"
	return UI.icon(name) if name != "" else null


## Wo die Person nach ihrem bisherigen Plan steht und wohin sie blickt: aus der Simulation (Endstand).
func _stand_after(id: String) -> Dictionary:
	var ends: Dictionary = _res.get("crew_end", {}) if _res != null else {}
	if ends.has(id):
		var e: Dictionary = ends[id]
		return {"cell": Vector2i(int(e.cell[0]), int(e.cell[1])), "face": Vector2i(int(e.face[0]), int(e.face[1]))}
	return {"cell": Sim._v2i(target.points.Fluchtwagen), "face": Vector2i(0, 1)}


func _walkable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.y >= target.map.size() or c.x >= String(target.map[0]).length():
		return false
	var t := String(target.map[c.y]).substr(c.x, 1)
	if not (t == "o" or t == "."):
		return false
	# Vitrinen blockieren den Weg (Original: Gegenstand mit Kollision)
	for l in target.loot:
		if Sim._v2i(l.pos) == c:
			return false
	return true


## Ein begehbares Feld orthogonal neben dem Objekt, möglichst nahe an der Person.
func _neighbor_of(cell: Vector2i, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = cell + d
		if _walkable(c) and (best == Vector2i(-1, -1) or absi(c.x - from.x) + absi(c.y - from.y) < absi(best.x - from.x) + absi(best.y - from.y)):
			best = c
	return best


## Name eines benannten Ortes an einer Zelle, sonst die Koordinaten.
func _name_at(cell) -> String:
	var v := Sim._v2i(cell)
	for k in target.points:
		if Sim._v2i(target.points[k]) == v:
			return k
	return Texte.t("plan.feld_pos") % [v.x, v.y]


## Testhilfe: Beispielplan mit Lockpick an der Eingangstür, Gemälde, Fluchtwagen.
func _on_example() -> void:
	if Game.target_id == "kiosk":
		var kex := {
			"teo": [
				{"t": "MOVE", "to": "Außen vor dem Eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
				{"t": "OPEN", "on": "Eingangstür"},
				{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]},
				{"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"},
				{"t": "OPEN", "on": "Kassenlade"},
				{"t": "TAKE", "loot": "kasse"},
				{"t": "CALL_CAR"},
				{"t": "MOVE", "to": "Fluchtwagen"},
			],
			"ilja": [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "MOVE", "to": "Fluchtwagen"}],
			"rosa": [{"t": "MOVE", "to": "Fluchtwagen"}],
		}
		for id in plans:
			plans[id] = kex[id].duplicate(true) if kex.has(id) else []
		_on_changed()
		return
	var ex := {
		"teo": [
			{"t": "MOVE", "cell": [0, 5]}, {"t": "MOVE", "cell": [1, 5]},
			{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "OPEN", "on": "Eingangstür"},
			{"t": "MOVE", "cell": [5, 5]}, {"t": "MOVE", "cell": [5, 4]},
			{"t": "TOOL", "tool": "lockpick", "on": "Gemälde „Hafen bei Nacht“"},
			{"t": "OPEN", "on": "Gemälde „Hafen bei Nacht“"},
			{"t": "TAKE", "loot": "gemaelde"},
			{"t": "CALL_CAR"},
			{"t": "MOVE", "to": "Fluchtwagen"},
		],
		"ilja": [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "MOVE", "to": "Fluchtwagen"}],
		"rosa": [{"t": "MOVE", "to": "Fluchtwagen"}],
	}
	for id in plans:
		plans[id] = ex[id].duplicate(true) if ex.has(id) else []
	_on_changed()


func _on_back() -> void:
	main.go("organisation")


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out


func _guard_name(id: String) -> String:
	for g in target.guards:
		if g.id == id:
			return g.name
	return id


## Klick auf den Grundriss: Person geht dorthin oder Menü zum Gegenstand.
var _menu: PopupMenu
var _menu_entries: Array = []


var _click_fine := Vector2i(-1, -1)


## Name eines Ortes in der Nähe eines Unterfeldes, sonst die Position in Feldern.
func _point_label(f: Vector2i) -> String:
	var sb := float(Sim.SUB)
	for k in target.points:
		if Vector2(Sim.center(Sim._v2i(target.points[k]))).distance_to(Vector2(f)) <= sb:
			return k
	return Texte.t("plan.punkt_pos") % [f.x / sb, f.y / sb]


## Einmaliger Hinweis (nach dem Klick, damit er das Menü nicht stört).
func _show_hint(id: String) -> void:
	if not Game.hint_once(id):
		return
	var h: Dictionary = GameData.HINTS[id]
	var dlg := AcceptDialog.new()
	dlg.title = Texte.d(str(h.title))
	dlg.dialog_text = Texte.d(str(h.text))
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
		_menu_entries.append(["Hierher gehen", {"t": "MOVE", "fine": [f.x, f.y]}, true])
	elif _walkable(cell):
		_menu_entries.append(["Hierher gehen", {"t": "MOVE", "cell": [cell.x, cell.y]}, true])
	# Am Fluchtwagen: einsteigen = Plan beenden (Original: Rückkehr zum Wagen, plLivingsPosAtCar)
	if cell == Sim._v2i(target.points.Fluchtwagen):
		_menu_entries.append(["Einsteigen (Plan beenden)", {"t": "BOARD"}, true])
	# Treppenfeld: die Person steigt auf die andere Etage (8 s)
	for pr in target.get("treppen", []):
		if cell == Vector2i(int(pr[0]), int(pr[1])) or cell == Vector2i(int(pr[2]), int(pr[3])):
			_menu_entries.append(["Treppe steigen (8 s)", {"t": "TREPPE"}, true])
	_menu_entries.append_array(_object_entries(cell))
	if target.has("panel") and Sim._v2i(target.panel.pos) == cell:
		_menu_entries.append([Texte.t("plan.bypass"), {"t": "TOOL", "tool": "bypass", "on": target.panel.name}, Game.tools_owned.has("bypass")])
	for g in target.guards:
		if Sim._v2i(g.start) == cell:
			_menu_entries.append(["Wache niederschlagen (Kampfsport, laut)", {"t": "NEUTRALIZE", "guard": g.id, "method": "knock"}, true])
			_menu_entries.append([Texte.t("plan.chloroform"), {"t": "NEUTRALIZE", "guard": g.id, "method": "chloroform"}, Game.tools_owned.has("chloroform")])
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


## Zwischen zwei Sekundenbildern: Positionen gleiten gleichmäßig (Laufbewegung).
func _interp_frame(frames: Array, t: float) -> Dictionary:
	var fidx := t / Sim.SNAP
	var idx := clampi(int(floor(fidx)), 0, frames.size() - 1)
	var nxt := mini(idx + 1, frames.size() - 1)
	# Keine Zwischenpositionen: gezeichnet wird die gespeicherte Position (liegt immer auf begehbarem Boden)
	var frac := 0.0
	var a: Dictionary = frames[idx]
	var b: Dictionary = frames[nxt]
	var out := a.duplicate(false)
	out.crew = {}
	for id in a.crew:
		var ca: Array = a.crew[id]
		var cb: Array = b.crew.get(id, ca)
		var p := Vector2(ca[0], ca[1]).lerp(Vector2(cb[0], cb[1]), frac)
		var c := ca.duplicate()
		c[0] = p.x
		c[1] = p.y
		out.crew[id] = c
	return out


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


func _on_menu_pick(i: int) -> void:
	var e: Array = _menu_entries[i]
	var act: Dictionary = e[1].duplicate(true)
	if act.t == "BOARD":
		# Einsteigen: den Wagen rufen (falls noch nicht geschehen) und zum Wagen gehen
		if not _has_call_car(_active):
			_add(_active, {"t": "CALL_CAR"})
		_add(_active, {"t": "MOVE", "to": "Fluchtwagen"})
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

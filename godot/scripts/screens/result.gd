extends Control
## Auswertung nach einem Coup. Die Effekte (Geld, Fahndung, Zeit) wurden bereits in Game.apply_result angewendet.

var main: Node
var args: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background(Color(0.07, 0.08, 0.11)))
	# Ausgangsbild: unscharfe Fassung füllt den ganzen Bildschirm, das scharfe Bild liegt ganz sichtbar in der Mitte
	var bg_status := str(args.get("result", {}).get("status", ""))
	var bg_path := "res://assets/art/result_erfolg.webp" if bg_status.begins_with("ENTKOMMEN") else ("res://assets/art/result_fehl.webp" if bg_status == "GEFASST" else "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var fill := UI.backdrop(bg_path.replace(".webp", "_blur.webp"))
		fill.modulate = Color(1, 1, 1, 0.55)
		add_child(fill)
		var sharp := TextureRect.new()
		sharp.texture = load(bg_path)
		sharp.set_anchors_preset(Control.PRESET_FULL_RECT)
		sharp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sharp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sharp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sharp)
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.06, 0.09, 0.45)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	var res: Dictionary = args.get("result", {})
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(UI.margin(root, 26))

	var status: String = res.get("status", "ABBRUCH")
	var title_col := Color(0.5, 1.0, 0.6)
	var title_txt := Texte.t("res.entkommen")
	match status:
		"ENTKOMMEN_HEISS":
			title_txt = Texte.t("res.entkommen_heiss")
			title_col = Color(1.0, 0.9, 0.4)
		"GEFASST":
			title_txt = Texte.t("res.festgenommen")
			title_col = Color(1.0, 0.45, 0.4)
		"ABBRUCH":
			title_txt = Texte.t("res.abgebrochen")
			title_col = Color(1.0, 0.6, 0.4)
	root.add_child(UI.label(title_txt, 32, title_col))
	root.add_child(UI.label(str(res.get("reason", "")), 17, Color(0.92, 0.9, 0.85), true))

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_box.add_child(UI.label(Texte.t("res.erbeutet") % _list(res.get("loot_taken", [])), 17))
	card_box.add_child(UI.label(Texte.t("res.zurueck") % _list(res.get("loot_missed", [])), 17))
	card_box.add_child(UI.label(Texte.t("res.auszahlung") % _fmt(int(res.get("payout", 0))), 20, Color(0.95, 0.85, 0.5)))
	card_box.add_child(UI.label(Texte.t("res.fahndung") % [int(Game.heat), int(res.get("heat", 0.0))], 17))
	card_box.add_child(UI.label(Texte.t("res.geld") % [_fmt(Game.money), Game.day, Game.clock_text()], 17))
	root.add_child(UI.card(card_box))

	root.add_child(_ablauf_box(res))

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	if Game.game_over:
		root.add_child(UI.label(Texte.t("res.vorbei"), 20, Color(1, 0.5, 0.4)))
		bottom.add_child(UI.button(Texte.t("res.weiter"), func(): main.go("gameover"), 240))
	else:
		bottom.add_child(UI.button(Texte.t("res.zur_stadt"), _on_town, 240))


## Ablauf: je Person eine Spalte, Zeit links. Alarm über die ganze Breite. Filter nach Person.
var _filter := ""
var _res: Dictionary = {}
var _ablauf: VBoxContainer


func _ablauf_box(res: Dictionary) -> Control:
	_res = res
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UI.label(Texte.t("res.ablauf"), 18, Color(0.97, 0.82, 0.42)))
	var filt := HBoxContainer.new()
	filt.add_theme_constant_override("separation", 6)
	box.add_child(filt)
	filt.add_child(UI.button(Texte.t("res.filter_alle"), _set_filter.bind(""), 110))
	for c in res.get("crew", []):
		filt.add_child(UI.button(str(c.name).split(" ")[0], _set_filter.bind(str(c.id)), 110))
	# Beute je Person steht oberhalb der Zeitleiste, damit sie ohne Scrollen sichtbar ist
	var beute := {}
	for ev in res.get("events", []):
		if str(ev.kind) == "TAKE" and bool(ev.ok):
			beute[str(ev.crew)] = beute.get(str(ev.crew), []) + [Texte.d(str(ev.obj))]
	var teile: Array = []
	for c in res.get("crew", []):
		var liste: Array = beute.get(str(c.id), [])
		if not liste.is_empty():
			teile.append("%s: %s" % [str(c.name).split(" ")[0], ", ".join(liste)])
	if not teile.is_empty():
		box.add_child(UI.label(Texte.t("res.beute_person") % " · ".join(teile), 15, Color(0.95, 0.85, 0.5), true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_ablauf = VBoxContainer.new()
	_ablauf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ablauf.add_theme_constant_override("separation", 3)
	scroll.add_child(_ablauf)
	_fill()
	return box


func _set_filter(id: String) -> void:
	_filter = id
	_fill()


func _fill() -> void:
	for ch in _ablauf.get_children():
		ch.queue_free()
	var crew: Array = _res.get("crew", [])
	var col_of := {}
	for i in range(crew.size()):
		col_of[str(crew[i].id)] = i
	# Kopfzeile mit den Namen
	var head := HBoxContainer.new()
	head.add_child(_cell(Texte.t("res.zeit"), 60, Color(0.6, 0.65, 0.72)))
	for c in crew:
		if _filter == "" or _filter == str(c.id):
			head.add_child(_cell(str(c.name).split(" ")[0], 0, Color(0.85, 0.88, 0.95), true))
	_ablauf.add_child(head)
	for ev in _res.get("events", []):
		var is_alarm: bool = bool(ev.get("alarm", false))
		if _filter != "" and not is_alarm and str(ev.crew) != _filter:
			continue
		var row := HBoxContainer.new()
		row.add_child(_cell(Sim.clock(float(ev.t)), 60, Color(0.6, 0.65, 0.72)))
		if is_alarm:
			row.add_child(_cell(Texte.t("res.alarm_zeile") % Texte.d(str(ev.obj)), 0, Color(1.0, 0.7, 0.4), true))
		else:
			for c in crew:
				if _filter != "" and str(c.id) != _filter:
					continue
				if str(c.id) == str(ev.crew):
					row.add_child(_cell(_ev_text(ev), 0, Color(0.92, 0.94, 0.97) if ev.ok else Color(1.0, 0.6, 0.5), true))
				else:
					row.add_child(_cell("", 0, Color.WHITE, true))
		_ablauf.add_child(row)


## Ein Text je Aktion: Art und Ziel, bei Fehlschlag der Grund, sonst die Meldung der Aktion.
func _ev_text(ev: Dictionary) -> String:
	var txt := ""
	match str(ev.kind):
		"MOVE":
			txt = Texte.t("res.geh_nach") % Texte.d(str(ev.obj))
		"TOOL":
			txt = Texte.t("res.werkzeug_an") % [Texte.d(str(ev.tool)), Texte.d(str(ev.obj))]
		"OPEN":
			txt = Texte.t("res.oeffnet") % Texte.d(str(ev.obj))
		"TAKE":
			txt = Texte.t("res.nimmt") % Texte.d(str(ev.obj))
		"CALL_CAR":
			txt = Texte.t("res.ruft_wagen")
		_:
			txt = str(ev.kind)
	if not bool(ev.ok):
		return "✗ %s: %s" % [txt, str(ev.fail)]
	if str(ev.msg) != "":
		return "%s\n%s" % [txt, str(ev.msg)]
	return txt


func _cell(txt: String, w: float, col: Color, grow := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if w > 0.0:
		l.custom_minimum_size = Vector2(w, 0)
	if grow:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _list(a: Array) -> String:
	if a.is_empty():
		return "nichts"
	var names: Array = []
	for x in a:
		names.append(Texte.d(str(x)))
	return ", ".join(names)


func _on_town() -> void:
	main.go("town")


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

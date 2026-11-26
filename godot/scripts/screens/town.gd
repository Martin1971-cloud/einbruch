extends Control
## Stadtphase im Stil des Referenz-Layouts: Titelleiste, Statusleiste,
## Stadtplan, Ortsbild, Ortskarte, Dialogkarte und Aktionsleiste unten.

var main: Node
var args: Dictionary = {}

var _selected := "kiosk"
var _stats: Label
var _clock: Label
var _map: CityMap
var _heat_bar: ProgressBar
var _loc_box: VBoxContainer
var _image_box: PanelContainer
var _dialog: Label
var _msg: Label
var _event_log: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.backdrop())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 12))

	root.add_child(_title_bar())
	root.add_child(_status_bar())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# Breiten: Stadtplan größer, Ortsbild schmaler (Verhältnis 1,7 : 0,8 : 1)
	var map_card := _map_card()
	map_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_card.size_flags_stretch_ratio = 2.4
	body.add_child(map_card)
	var image_card := _image_card()
	image_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_card.size_flags_stretch_ratio = 0.8
	body.add_child(image_card)
	var info_card := _info_card()
	info_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_card.size_flags_stretch_ratio = 0.7
	body.add_child(info_card)

	_msg = UI.label("", 14, Color(0.85, 0.95, 0.75))
	_msg.autowrap_mode = TextServer.AUTOWRAP_OFF
	root.add_child(_msg)
	root.add_child(_action_bar())
	_refresh()


# ---------------------------------------------------------------- Oberfläche

func _title_bar() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var brand := VBoxContainer.new()
	var t := UI.label(Texte.t("app.titel"), 24, Color(0.97, 0.82, 0.42))
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.add_child(t)
	var s := UI.label(Texte.t("app.untertitel"), 10, Color(0.75, 0.75, 0.8))
	s.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.add_child(s)
	row.add_child(brand)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var _b1 := UI.button(Texte.t("nav.stadt"), func(): pass, 100)
	_b1.disabled = true
	row.add_child(_b1)
	row.add_child(UI.button(Texte.t("nav.organisation"), func(): main.go("organisation"), 130))
	row.add_child(UI.button(Texte.t("nav.planung"), func(): main.go("planner"), 100))
	var _b2 := UI.button(Texte.t("nav.ausfuehrung"), func(): pass, 110)
	_b2.disabled = true
	row.add_child(_b2)
	row.add_child(UI.button(Texte.t("nav.journal"), func(): main.open_journal(), 120))
	row.add_child(UI.button(Texte.t("nav.optionen"), func(): main.open_optionen(), 130))
	row.add_child(UI.button(Texte.t("nav.lexikon"), func(): main.open_lexikon(), 120))
	return _panel(row)


func _status_bar() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_clock = UI.label("", 15, Color(0.95, 0.85, 0.5))
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_clock)
	_stats = UI.label("", 15, Color(0.9, 0.92, 0.96))
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_stats)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(UI.label(Texte.t("stadt.fahndung"), 13, Color(0.75, 0.75, 0.8)))
	_heat_bar = ProgressBar.new()
	_heat_bar.custom_minimum_size = Vector2(200, 16)
	_heat_bar.max_value = 100.0
	_heat_bar.show_percentage = false
	row.add_child(_heat_bar)
	return _panel(row)


func _map_card() -> PanelContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(Texte.t("stadt.stadtplan"), 12, Color(0.89, 0.71, 0.35)))
	_map = CityMap.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.picked.connect(_select)
	col.add_child(_map)
	var pins: Array = [
		{"id": "kiosk", "name": Texte.t(GameData.TARGETS.kiosk.name), "pos": Vector2(0.3, 0.62), "active": true, "info": GameData.TARGETS.kiosk.get("info", "")},
		{"id": "museum", "name": Texte.t(GameData.TARGETS.museum.name), "pos": Vector2(0.153, 0.379), "active": Game.unlocked.museum, "info": GameData.TARGETS.museum.get("info", "")},
		{"id": "curiosity", "name": Texte.t(GameData.TARGETS.curiosity.name), "pos": Vector2(0.45, 0.66), "active": Game.unlocked.get("curiosity", false), "info": GameData.TARGETS.curiosity.get("info", "")},
		{"id": "juwelier", "name": Texte.t(GameData.TARGETS.juwelier.name), "pos": Vector2(0.58, 0.46), "active": Game.unlocked.get("juwelier", false), "info": GameData.TARGETS.juwelier.get("info", "")},
	]
	# Einkaufsorte: anklickbar wie ein Ziel, öffnen den Laden oder das Autohaus
	pins.append({"id": "laden", "name": Texte.t("ort.laden"), "pos": Vector2(0.27, 0.70), "active": true, "info": Texte.t("ort.laden_info")})
	pins.append({"id": "autohaus", "name": Texte.t("ort.autohaus"), "pos": Vector2(0.60, 0.16), "active": true, "info": Texte.t("ort.autohaus_info")})
	pins.append({"id": "revier", "name": Texte.t("ort.revier"), "pos": Vector2(0.33, 0.21), "active": false, "info": Texte.t("ort.revier_info")})
	for o in GameData.OTHER_PLACES:
		pins.append({"id": o.id, "name": Texte.t(o.name), "pos": Vector2(o.pos[0], o.pos[1]), "active": false, "info": Texte.t(o.get("info", ""))})
	for p in pins:
		p["done"] = Game.stufe_of(p.id) > 0
	_map.set_pins(pins, _selected)
	var c := _panel(col)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(340, 0)
	return c


func _image_card() -> PanelContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image_box = PanelContainer.new()
	_image_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image_box.add_theme_stylebox_override("panel", UI.card_style(Color(0.08, 0.11, 0.17)))
	col.add_child(_image_box)
	var dlg := PanelContainer.new()
	dlg.add_theme_stylebox_override("panel", UI.card_style(Color(0.1, 0.13, 0.2)))
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 4)
	dlg.add_child(dv)
	dv.add_child(UI.label(GameData.TARGETS[_selected].speaker.to_upper(), 12, Color(0.97, 0.82, 0.42)))
	# Porträt der Sprecherin (Dialog)
	var sp_id := "mira" if GameData.TARGETS[_selected].speaker == "Mira Calder" else ""
	var sp_path := GameData.portrait_path(sp_id)
	if sp_path != "" and ResourceLoader.exists(sp_path):
		var pt := TextureRect.new()
		pt.texture = load(sp_path)
		pt.custom_minimum_size = Vector2(120, 120)
		pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dv.add_child(pt)
	_dialog = UI.label("", 14, Color(0.92, 0.92, 0.95), true)
	dv.add_child(_dialog)
	col.add_child(dlg)
	var c := _panel(col)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _info_card() -> PanelContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(300, 0)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(UI.label(Texte.t("stadt.ort"), 12, Color(0.89, 0.71, 0.35)))
	_loc_box = VBoxContainer.new()
	_loc_box.add_theme_constant_override("separation", 6)
	col.add_child(_loc_box)
	var c := _panel(col)
	c.custom_minimum_size = Vector2(300, 0)
	return c


func _with_icon(b: Button, icon_name: String) -> Button:
	var tex := UI.icon(icon_name)
	if tex != null:
		b.icon = tex
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return b


func _action_bar() -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_with_icon(UI.button(Texte.t("stadt.umsehen"), _on_look, 0), "look"))
	row.add_child(_with_icon(UI.button(Texte.t("stadt.sprechen"), _on_informant, 0), "talk"))
	row.add_child(_with_icon(UI.button(Texte.t("stadt.nachdenken"), _on_think, 0), "think"))
	row.add_child(_with_icon(UI.button(Texte.t("stadt.gehen"), func(): main.go("organisation"), 0), "walk"))
	row.add_child(UI.button(Texte.t("stadt.warten"), _on_sleep, 0))
	row.add_child(UI.button(Texte.t("stadt.ereignisse"), _on_events, 0))
	var hints := [Texte.t("stadt.hint_umsehen"), Texte.t("stadt.hint_informant"), Texte.t("stadt.hint_nachdenken"), Texte.t("stadt.hint_gehen"), Texte.t("stadt.hint_warten"), Texte.t("stadt.hint_ereignisse")]
	var bi := 0
	for b in row.get_children():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = hints[bi]
		bi += 1
	return _panel(row)


func _panel(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style())
	p.add_child(content)
	return p


# ---------------------------------------------------------------- Inhalt

func _refresh() -> void:
	_clock.text = Texte.t("stadt.tag") % [Game.day, Game.clock_text()]
	_stats.text = Texte.t("stadt.geld") % _fmt(Game.money)
	_heat_bar.value = Game.heat
	var t: Dictionary = GameData.target_now(Game.stufe_of(_selected), _selected)
	_dialog.text = "„%s“" % Texte.t(t.dialog)
	_map.set_pins(_map.pins, _selected)
	for c in _loc_box.get_children():
		c.queue_free()
	var erfolgreich := Game.stufe_of(_selected) > 0
	var name_col := Color(0.55, 0.92, 0.55) if erfolgreich else Color(0.97, 0.85, 0.55)
	_loc_box.add_child(UI.label(Texte.t(t.name), 19, name_col))
	if t.has("info"):
		_loc_box.add_child(UI.label(Texte.t(t.info), 13, Color(0.89, 0.71, 0.35), true))
	_loc_box.add_child(UI.label(Texte.t(t.desc), 13, Color(0.92, 0.92, 0.95), true))
	var lvl: int = int(Game.intel.get(_selected, 0))
	var q: Dictionary = Game.quelle_of(_selected)
	var shown_facts: Array = []
	for f in t.facts:
		if _fakt_sichtbar(str(f[0]), q):
			shown_facts.append(f)
	# Polizeizeit ist immer bekannt (Original: PoliceTime wird immer angezeigt)
	shown_facts.insert(0, [Texte.t("stadt.polizeizeit"), Texte.t("stadt.polizeizeit_wert") % GameData.police_text(t, bool(q.get("inf", false)))])
	for f in shown_facts:
		var h := HBoxContainer.new()
		var k := UI.label(Texte.t(GameData.FAKTEN.get(f[0], f[0])), 13, Color(0.7, 0.75, 0.82))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(UI.label(Texte.t(str(f[1])), 13))
		_loc_box.add_child(h)
	var req := VBoxContainer.new()
	for skill in t.bedarf:
		var nm: String = Texte.t({"TECH": "skill.technik", "FORCE": "skill.kampf", "ELECTRONICS": "skill.elektronik", "FAHREN": "skill.fahren"}.get(skill, skill))
		var wert := int(t.bedarf[skill].wert)
		var txt := ""
		if lvl == 0:
			txt = Texte.t("stadt.skill_unbekannt") % nm
		elif lvl == 1:
			txt = Texte.t("stadt.skill_ca") % [nm, int(round(wert / 5.0)) * 5]
		else:
			txt = Texte.t("stadt.skill_ab") % [nm, wert, Texte.t(t.bedarf[skill].grund)]
		req.add_child(UI.label(txt, 11, Color(0.8, 0.85, 0.9), true))
	_loc_box.add_child(UI.fold(Texte.t("stadt.braucht"), req, true))
	_loc_box.add_child(UI.label(Texte.t("stadt.ermittlung") % _ermittlung_text(lvl), 13, Color(0.6, 0.85, 1.0), true))
	if lvl >= 2:
		_loc_box.add_child(UI.label(Texte.t("plan.beutewert") % GameData.loot_text(t, lvl), 13, Color(0.97, 0.85, 0.55)))
	if erfolgreich:
		_loc_box.add_child(UI.label(Texte.t("stadt.erfolgreich"), 15, Color(0.55, 0.92, 0.55)))
	_refresh_image()


## Ermittlungstext: je nach Aktionen (Umsehen einmal oder zweimal, Informant).
## Welche Fakten sichtbar sind: Lage und Öffnungszeiten ab Umsehen 1x, Wache und Überwachung ab Umsehen 2x, Besonderheit über den Informanten.
func _fakt_sichtbar(name: String, q: Dictionary) -> bool:
	var n := int(q.get("look", 0))
	if name == "besonderheit":
		return bool(q.get("inf", false))  # Insiderwissen gibt es nur über den Informanten
	if name == "wache" or name == "ueberwachung":
		return n >= 2  # erst beim zweiten Umsehen
	return n >= 1  # Lage, Öffnungszeiten: schon beim ersten Umsehen


func _ermittlung_text(_lvl: int) -> String:
	return Texte.t(Game.ermittlung_key(_selected))


func _refresh_image() -> void:
	for c in _image_box.get_children():
		c.queue_free()
	# Ortsbild: Foto, falls vorhanden. Sonst die gezeichnete Fassade aus dem Grundriss.
	var photo_path := "res://assets/art/location_%s.png" % _selected
	if not ResourceLoader.exists(photo_path):
		photo_path = "res://assets/art/location_%s.jpg" % _selected
	if ResourceLoader.exists(photo_path):
		var pic := TextureRect.new()
		pic.texture = load(photo_path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 240)
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_image_box.add_child(pic)
		return
	var art := BuildingArt.new()
	art.map = GameData.TARGETS[_selected].map
	art.custom_minimum_size = Vector2(0, 240)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image_box.add_child(art)


func _select(id: String) -> void:
	# Laden und Autohaus: direkt öffnen, dort wird gekauft
	if id == "laden" or id == "autohaus":
		main.go("shop", {"kind": id})
		return
	if not GameData.TARGETS.has(id) or not Game.unlocked.get(id, false):
		return
	_selected = id
	Game.target_id = id
	_refresh()


func _on_look() -> void:
	var q: Dictionary = Game.quelle_of(_selected)
	q["look"] = mini(int(q.get("look", 0)) + 1, 2)
	Game.ermittlung_quelle[_selected] = q
	Game.intel[_selected] = Game.intel_level(_selected)
	Game.advance_hours(1.0)
	_log(Texte.t("stadt.log_umsehen"))


func _on_informant() -> void:
	if bool(Game.quelle_of(_selected).get("inf", false)):
		_msg.text = Texte.t("stadt.erm_inf_bereits")
		return
	var price: int = int(GameData.TARGETS[_selected].price_intel)
	if Game.money < price:
		_msg.text = Texte.t("stadt.zu_wenig_geld")
		return
	Game.money -= price
	var q: Dictionary = Game.quelle_of(_selected)
	q["inf"] = true
	Game.ermittlung_quelle[_selected] = q
	Game.intel[_selected] = Game.intel_level(_selected)
	Game.advance_hours(0.5)
	_log(Texte.t("stadt.log_informant"))


func _on_think() -> void:
	var lvl: int = int(Game.intel[_selected])
	_msg.text = Texte.t("stadt.denken") % [Texte.t("stadt.denken_0"), Texte.t("stadt.denken_1"), Texte.t("stadt.denken_2")][lvl]


func _on_sleep() -> void:
	Game.sleep_until_morning()
	_log(Texte.t("stadt.log_tag"))


func _on_events() -> void:
	var text := "\n".join(_event_log) if not _event_log.is_empty() else Texte.t("stadt.ereignisse_leer")
	_msg.text = Texte.t("stadt.ereignisse") + text.replace("\n", "  ·  ")


func _log(text: String) -> void:
	_event_log.append(text)
	_msg.text = text
	_refresh()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

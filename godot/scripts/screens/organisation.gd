extends Control
## Organisation: Team zusammenstellen. Links die Personen (nur diese Liste scrollt),
## rechts der Bedarf des Ziels mit Abdeckung durch das Team, darunter der Einkauf.
## Weiter nur mit mindestens einem Einbrecher und einem Fahrer.

const MAX_TEAM := 4
const MAX_BURGLARS := 3
const MAX_DRIVERS := 2
const SKILL_NAMES := {"TECH": "skill.technik", "FORCE": "skill.kampf", "ELECTRONICS": "skill.elektronik", "FAHREN": "skill.fahren"}

var main: Node
var args: Dictionary = {}

var _selected := {}
var _burgle := {}  # Fahrer, die zusätzlich einbrechen (Rolle „Einbrecher“)
var _gear_pick := {}
var _people_box: VBoxContainer
var _shop_box: VBoxContainer
var _shop_hint: Label
var _cover_box: VBoxContainer
var _cost_label: Label
var _summary: Label
var _msg: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color(0.06, 0.08, 0.11)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	# Pinnwand über die ganze Fläche, schwach: die Menüs liegen davor und bleiben lesbar
	var bg := UI.backdrop("res://assets/art/bg_pinnwand.webp")
	bg.modulate = Color(1, 1, 1, 0.3)
	add_child(bg)
	# Auswahl aus dem Spielzustand übernehmen (oder neu anlegen). Die Dictionaries werden geteilt,
	# damit jede Änderung sofort im Spielzustand steht und beim Zurückkehren erhalten bleibt.
	if Game.org_selected.is_empty():
		for c in GameData.CREW:
			Game.org_selected[c.id] = false
			Game.org_burgle[c.id] = false
			Game.org_gear_pick[c.id] = []
	_selected = Game.org_selected
	_burgle = Game.org_burgle
	_gear_pick = Game.org_gear_pick

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 14))

	root.add_child(_l(Texte.t("org.titel"), 24, Color(0.95, 0.8, 0.4)))
	root.add_child(_l(Texte.t("org.ziel_zeile") % [Texte.t(GameData.TARGETS[Game.target_id].name), Game.stufe_of(Game.target_id), _fmt(Game.money)], 14, Color(0.8, 0.85, 0.92)))
	_summary = _l("", 14, Color(0.85, 0.9, 0.95))
	root.add_child(_summary)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Links: Personen. Nur diese Liste scrollt.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_l(Texte.t("org.personen"), 12, Color(0.89, 0.71, 0.35)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_people_box = VBoxContainer.new()
	_people_box.add_theme_constant_override("separation", 8)
	_people_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_people_box)
	cols.add_child(left)

	# Mitte: Bedarf des Ziels und Abdeckung durch das Team. Feste Breite, scrollt nicht.
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(320, 0)
	mid.add_theme_constant_override("separation", 8)
	_cover_box = VBoxContainer.new()
	_cover_box.add_theme_constant_override("separation", 6)
	mid.add_child(_scroll_col(UI.fold(Texte.t("org.bedarf"), _cover_box, true)))
	cols.add_child(mid)
	# Rechts: Einkauf. Feste Breite, scrollt nicht.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 8)
	right.add_child(_l(Texte.t("org.ausruestung"), 12, Color(0.89, 0.71, 0.35)))
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 3)
	_shop_hint = _l("", 12, Color(0.85, 0.88, 0.94))
	_shop_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var shop_col := VBoxContainer.new()
	shop_col.add_theme_constant_override("separation", 6)
	shop_col.add_child(_shop_hint)
	shop_col.add_child(_card(_shop_box))
	right.add_child(_scroll_col(shop_col))
	cols.add_child(right)

	_cost_label = _l("", 14)
	root.add_child(_cost_label)
	_msg = _l("", 14, Color(1, 0.6, 0.5))
	root.add_child(_msg)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	bottom.add_child(UI.button(Texte.t("org.zurueck"), _on_back, 210))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	if GameData.TESTHILFEN:
		bottom.add_child(UI.button(Texte.t("org.beispiel"), _on_example, 230))
	bottom.add_child(UI.primary(Texte.t("org.bestaetigen"), _on_confirm, 270))

	_build_people()
	_build_shop()
	_refresh_summary()


# ---------------------------------------------------------------- Personen

func _build_people() -> void:
	for c in _people_box.get_children():
		c.queue_free()
	var ordered: Array = []
	for c in _people():
		if c.get("driver", false):
			ordered.append(c)
	for c in _people():
		if not c.get("driver", false):
			ordered.append(c)
	var last_group := ""
	for c in ordered:
		var is_driver: bool = c.get("driver", false)
		var group := Texte.t("org.grp_fahrer") if is_driver else Texte.t("org.grp_einbrecher")
		if group != last_group:
			_people_box.add_child(_l(group, 12, Color(0.89, 0.71, 0.35)))
			last_group = group
		_people_box.add_child(_person_card(c, is_driver))


## Alle Personen mit ihren aktuellen Fähigkeiten (wachsen mit Erfolgen).
func _people() -> Array:
	var out: Array = []
	for c in GameData.CREW:
		var d: Dictionary = c.duplicate(true)
		d.skills = Game.skills_of(c.id)
		out.append(d)
	return out


func _person_card(c: Dictionary, is_driver: bool) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	# Links: Name, Rolle, Honorar und Kleidung
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(230, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nb := _choice("%s   %s" % [c.name, Texte.t(c.role)], _selected[c.id], _on_toggle.bind(c.id), 16)
	nb.tooltip_text = Texte.t("org.auswahl_tip")
	left.add_child(nb)
	left.add_child(_l(Texte.t("org.honorar") % _fmt(int(c.fee)), 12, Color(0.65, 0.7, 0.78)))
	if is_driver:
		var bb := _choice(Texte.t("org.auch_einbrechen"), _burgle[c.id], _on_burgle_toggle.bind(c.id), 13)
		bb.disabled = not _selected[c.id]
		bb.tooltip_text = Texte.t("org.fahrer_tip")
		left.add_child(bb)
	var items: Array = []
	for gid in GameData.GEAR:
		if gid != "none" and Game.gear_owned.has(gid):
			items.append([Texte.t(GameData.GEAR[gid].name), gid])
	if items.is_empty():
		left.add_child(_l(Texte.t("org.kleidung_keine"), 12, Color(0.55, 0.6, 0.66)))
	else:
		left.add_child(UI.multi_menu(Texte.t("org.kleidung_waehlen"), items, _gear_pick[c.id], _gear_cb(c.id)))
	row.add_child(left)
	# Porträt der Person in der Mitte der Karte (zwischen Name und Fähigkeiten)
	var pp := GameData.portrait_path(c.id)
	if pp != "" and ResourceLoader.exists(pp):
		var ptr := TextureRect.new()
		ptr.texture = load(pp)
		ptr.custom_minimum_size = Vector2(72, 90)
		ptr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ptr)
	# Rechts: Fähigkeiten in Prozent mit Balken, untereinander
	var skills := VBoxContainer.new()
	skills.add_theme_constant_override("separation", 3)
	skills.custom_minimum_size = Vector2(230, 0)
	for k in c.skills:
		var sr := _skill_row(Texte.t(SKILL_NAMES.get(k, k)), int(c.skills[k]))
		sr.tooltip_text = Texte.t(GameData.SKILL_INFO.get(k, ""))
		skills.add_child(sr)
	row.add_child(skills)
	return _card(row)


func _skill_row(label: String, value: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_lbl := _l(label, 12, Color(0.78, 0.82, 0.88))
	name_lbl.custom_minimum_size = Vector2(78, 0)
	h.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var pct := _l("%d %%" % value, 12, Color(0.95, 0.9, 0.8))
	pct.custom_minimum_size = Vector2(44, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	return h


# ---------------------------------------------------------------- Bedarf und Abdeckung

func _team_best(skill: String) -> int:
	## Bester Wert im ausgewählten Team für diese Fähigkeit.
	var best := 0
	for c in _people():
		if not _selected[c.id]:
			continue
		if c.skills.has(skill):
			best = maxi(best, int(c.skills[skill]))
	return best


func _refresh_cover() -> void:
	for c in _cover_box.get_children():
		c.queue_free()
	var bedarf: Dictionary = GameData.bedarf_now(Game.stufe_of(Game.target_id), Game.target_id)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	for head in [Texte.t("org.faehigkeit"), Texte.t("org.bedarf_kopf"), Texte.t("org.team_kopf"), Texte.t("org.status")]:
		grid.add_child(_l(head.to_upper(), 11, Color(0.89, 0.71, 0.35)))
	for skill in bedarf:
		var need: int = bedarf[skill].wert
		var have := _team_best(skill)
		var ok := have >= need
		var name_lbl := _l(Texte.t(SKILL_NAMES.get(skill, skill)), 14, Color(0.95, 0.93, 0.88))
		name_lbl.tooltip_text = Texte.t(bedarf[skill].grund)
		grid.add_child(name_lbl)
		grid.add_child(_l("%d %%" % need, 14, Color(0.85, 0.9, 0.95)))
		grid.add_child(_l("%d %%" % have, 14, Color(0.6, 0.95, 0.65) if ok else Color(1, 0.6, 0.5)))
		if ok:
			grid.add_child(_l(Texte.t("org.gedeckt"), 14, Color(0.45, 0.95, 0.55)))
		else:
			grid.add_child(_l("✗ −%d %%" % (need - have), 14, Color(1, 0.5, 0.45)))
		grid.get_child(grid.get_child_count() - 1).tooltip_text = Texte.t(bedarf[skill].grund)
	_cover_box.add_child(grid)
	_cover_box.add_child(_l(Texte.t("org.abdeckung_tip"), 11, Color(0.55, 0.6, 0.66)))


# ---------------------------------------------------------------- Einkauf

var _shop_open := {}  # Titel -> zuletzt gewählter Zustand, bleibt beim Neuaufbau erhalten


func _shop_fold(title: String, content: Control) -> PanelContainer:
	var is_open: bool = _shop_open.get(title, true)   # Besitz ist standardmäßig ausgeklappt
	var f := UI.fold(title, content, is_open)
	var head: Button = f.get_child(0).get_child(0)
	head.toggled.connect(func(on: bool): _shop_open[title] = on)
	return f


func _build_shop() -> void:
	for c in _shop_box.get_children():
		c.queue_free()
	_shop_hint.text = Texte.t("org.shop_hint")
	var owned := VBoxContainer.new()
	owned.add_theme_constant_override("separation", 3)
	var tnames: Array = []
	for tid in GameData.TOOLS:
		if Game.tools_owned.has(tid):
			tnames.append(Texte.t(GameData.TOOLS[tid].name))
	owned.add_child(_w("Werkzeug: %s" % (", ".join(tnames) if not tnames.is_empty() else "keines"), 12))
	var gnames: Array = []
	for gid in GameData.GEAR:
		if gid != "none" and Game.gear_owned.has(gid):
			gnames.append(Texte.t(GameData.GEAR[gid].name))
	owned.add_child(_w(Texte.t("org.kleidung_liste") % (", ".join(gnames) if not gnames.is_empty() else Texte.t("journal.beute_keine")), 12))
	var car := GameData.car_now(Game.car_id, 85.0)
	var how := Texte.t("org.gemietet") % _fmt(int(car.rent)) if Game.car_id == "limo" else Texte.t("org.gekauft")
	owned.add_child(_w(Texte.t("org.fluchtwagen_info") % [Texte.t(car.name), how], 12))
	_shop_box.add_child(_shop_fold(Texte.t("org.besitz"), owned))


## Wer das Werkzeug benutzen kann (wie im Original: Fähigkeit und Mindeststufe).
func _use_text(t: Dictionary) -> String:
	if str(t.get("ability", "")) == "":
		return Texte.t("org.jeder_kann")
	return "%s ab %d %%" % [t.ability, int(t.min)]


# ---------------------------------------------------------------- Auswahl

## Fahrer: ausgewählte Fahrer. Einbrecher: ausgewählte Einbrecher plus Fahrer, die zusätzlich einbrechen.
func _selected_ids(driver: bool) -> Array:
	var out: Array = []
	for c in GameData.CREW:
		if not _selected[c.id]:
			continue
		var is_d: bool = c.get("driver", false)
		if driver and is_d:
			out.append(c.id)
		if not driver and (not is_d or _burgle[c.id]):
			out.append(c.id)
	return out


func _team_count() -> int:
	var n := 0
	for c in GameData.CREW:
		if _selected[c.id]:
			n += 1
	return n


func _cost() -> int:
	var total := int(GameData.car_now(Game.car_id, 85.0).rent)  # Miete (gekaufte Wagen kosten nichts extra)
	for c in GameData.CREW:
		if _selected[c.id]:
			total += int(c.fee)
	return total


func _refresh_summary() -> void:
	var b := _selected_ids(false).size()
	var d := _selected_ids(true).size()
	var missing := ""
	if b < 1 and d < 1:
		missing = Texte.t("org.fehlt_beide")
	elif b < 1:
		missing = Texte.t("org.fehlt_einbrecher")
	elif d < 1:
		missing = Texte.t("org.fehlt_fahrer")
	_summary.text = Texte.t("org.team_zeile") % [b, d, Texte.t("org.bereit") if missing == "" else Texte.t("org.es_fehlt") % missing]
	_cost_label.text = Texte.t("org.kosten") % [_fmt(_cost()), _fmt(Game.money)]
	_refresh_cover()
	_build_shop()


func _on_toggle(pressed: bool, id: String) -> void:
	var is_driver: bool = _crew_by_id(id).get("driver", false)
	if pressed:
		if _team_count() >= MAX_TEAM:
			_msg.text = Texte.t("org.zu_viele") % MAX_TEAM
			_build_people()
			_refresh_summary()
			return
		if is_driver and _selected_ids(true).size() >= MAX_DRIVERS:
			_msg.text = Texte.t("org.hoechstens_fahrer") % MAX_DRIVERS
			_build_people()
			_refresh_summary()
			return
		if not is_driver and _selected_ids(false).size() >= MAX_BURGLARS:
			_msg.text = Texte.t("org.hoechstens_einbrecher") % MAX_BURGLARS
			_build_people()
			_refresh_summary()
			return
	_selected[id] = pressed
	_msg.text = ""
	_build_people()
	_refresh_summary()


func _on_burgle_toggle(pressed: bool, id: String) -> void:
	if pressed and _selected_ids(false).size() >= MAX_BURGLARS:
		_msg.text = Texte.t("org.hoechstens_einbrecher") % MAX_BURGLARS
		_build_people()
		return
	_burgle[id] = pressed
	_msg.text = ""
	_build_people()
	_refresh_summary()


## Das Kleidungsmenü ruft (Kleidungs-ID, angehakt) auf; hier wird die Person ergänzt.
func _gear_cb(id: String) -> Callable:
	return func(gid: String, on: bool) -> void:
		_on_gear_toggle(on, id, gid)


func _on_gear_toggle(pressed: bool, id: String, gid: String) -> void:
	var lst: Array = _gear_pick[id]
	if pressed and not lst.has(gid):
		lst.append(gid)
	if not pressed:
		lst.erase(gid)
	_gear_pick[id] = lst


func _crew_by_id(id: String) -> Dictionary:
	for c in _people():
		if c.id == id:
			return c
	return {}


## Auswahlfeld als Schaltfläche mit ☑ / ☐.
func _choice(text: String, pressed: bool, cb: Callable, size := 15) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = pressed
	b.text = ("☑  " if pressed else "☐  ") + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.toggled.connect(func(on: bool):
		b.text = ("☑  " if on else "☐  ") + text
		cb.call(on))
	return b


# ---------------------------------------------------------------- Einkauf


func _on_confirm() -> void:
	var burglars := _selected_ids(false)
	var drivers := _selected_ids(true)
	# Original: Teamplanung nur mit Ermittlungsstand über etwa 50 % (organisa.c, tcCheckOrganisation)
	if int(Game.intel.get(Game.target_id, 0)) < 1:
		_msg.text = Texte.t("org.msg_ermitteln")
		return
	if drivers.is_empty():
		_msg.text = Texte.t("org.msg_fahrer")
		return
	if burglars.is_empty():
		_msg.text = Texte.t("org.msg_einbrecher")
		return
	if Game.money < _cost():
		_msg.text = Texte.t("org.msg_geld")
		return
	Game.money -= _cost()
	var best: String = drivers[0]
	for id in drivers:
		if int(_crew_by_id(id).skills.FAHREN) > int(_crew_by_id(best).skills.FAHREN):
			best = id
	Game.driver = _crew_by_id(best).duplicate(true)
	Game.driver["gear"] = _gear_pick[best]
	Game.team = []
	for id in burglars:
		var c: Dictionary = _crew_by_id(id).duplicate(true)
		c["gear"] = _gear_pick[id]
		Game.team.append(c)
	main.go("planner")


## Testhilfe: Beispielteam mit einer Fahrerin und Kleidung für Teodor.
func _on_example() -> void:
	for c in GameData.CREW:
		_selected[c.id] = c.id in ["teo", "ilja", "rosa", "greta"]
		_gear_pick[c.id] = ["gloves", "sneakers"] if c.id == "teo" else []
	for t in ["lockpick", "crowbar", "bypass"]:
		Game.tools_owned[t] = true
	for g in ["gloves", "sneakers"]:
		Game.gear_owned[g] = true
	_msg.text = Texte.t("org.msg_beispiel")
	_build_people()
	_build_shop()
	_refresh_summary()


func _on_back() -> void:
	main.go("town")


## Spalte, die bei wenig Höhe selbst scrollt. So bleibt die Leiste unten immer sichtbar.
func _scroll_col(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


func _card(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style())
	p.add_child(content)
	return p


func _l(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	var lbl := UI.label(t, size, col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl


func _w(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	return UI.label(t, size, col, true)


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

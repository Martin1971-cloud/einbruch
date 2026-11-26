extends Control
## Laden (Werkzeug, Kleidung) und Autohaus (Fahrzeuge). Wird über die Stadtkarte geöffnet.
## kind = "laden" oder "autohaus" (wird über args von main.go übergeben).

var main
var args: Dictionary = {}
var kind := "laden"
var _money: Label
var _msg: Label
var _body: VBoxContainer


func _ready() -> void:
	kind = str(args.get("kind", "laden"))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.backdrop())
	# Ladenbild über die ganze Fläche, gedämpft: die Auswahl liegt davor
	var base := ColorRect.new()
	base.color = Color(0.06, 0.08, 0.11)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var pic_path := "res://assets/art/shop_werkzeug.jpg" if kind == "laden" else "res://assets/art/shop_autohaus.jpg"
	if ResourceLoader.exists(pic_path):
		var bg := UI.backdrop(pic_path)
		bg.modulate = Color(1, 1, 1, 0.4)
		add_child(bg)
		var shade := ColorRect.new()   # dunkle Schicht: die Texte bleiben lesbar
		shade.color = Color(0.05, 0.06, 0.09, 0.5)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 14))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := Texte.t("shop.titel_laden") if kind == "laden" else (Texte.t("shop.titel_verleih") if kind == "verleih" else Texte.t("shop.titel_autohaus"))
	head.add_child(UI.label(title, 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_money = UI.label("", 15, Color(0.85, 0.9, 0.95))
	head.add_child(_money)
	head.add_child(UI.button(Texte.t("shop.zurueck"), func() -> void: main.go("town"), 160))
	root.add_child(head)
	# Bild des Ortes: ganz zu sehen, Seitenverhältnis bleibt
	_msg = UI.label("", 14, Color(1, 0.8, 0.5))
	root.add_child(_msg)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	_money.text = Texte.t("shop.geld") % _fmt(Game.money)
	if kind == "laden":
		_build_laden()
	elif kind == "verleih":
		_build_verleih()
	else:
		_build_autohaus()


func _build_laden() -> void:
	# Zwei Spalten nebeneinander: links Werkzeug (breiter), rechts Kleidung
	var haupt := _body
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.alignment = BoxContainer.ALIGNMENT_BEGIN
	haupt.add_child(cols)
	var werk := VBoxContainer.new()
	werk.add_theme_constant_override("separation", 6)
	werk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	werk.size_flags_stretch_ratio = 2.2
	# Jede Tabelle in eine eigene Karte, damit die Bereiche klar getrennt sind
	var karte_werk := PanelContainer.new()
	karte_werk.add_theme_stylebox_override("panel", UI.card_style(Color(0.05, 0.07, 0.12, 0.82)))
	karte_werk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte_werk.size_flags_stretch_ratio = 2.2
	karte_werk.add_child(werk)
	cols.add_child(karte_werk)
	var kleid := VBoxContainer.new()
	kleid.add_theme_constant_override("separation", 6)
	kleid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kleid.size_flags_stretch_ratio = 1.0
	var karte_kleid := PanelContainer.new()
	karte_kleid.add_theme_stylebox_override("panel", UI.card_style(Color(0.05, 0.07, 0.12, 0.82)))
	karte_kleid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	karte_kleid.size_flags_stretch_ratio = 1.0
	karte_kleid.add_child(kleid)
	cols.add_child(karte_kleid)
	_body = werk
	_body.add_child(UI.label(Texte.t("shop.werkzeug_kopf"), 15, Color(0.89, 0.71, 0.35)))
	# Tabelle, alphabetisch nach dem angezeigten Namen
	var ids: Array = GameData.TOOLS.keys()
	ids.sort_custom(func(x, y): return Texte.t(GameData.TOOLS[x].name) < Texte.t(GameData.TOOLS[y].name))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for k in [Texte.t("shop.t_status"), Texte.t("shop.t_name"), Texte.t("shop.t_preis"), Texte.t("shop.t_faehig"), Texte.t("shop.t_bedingung"), Texte.t("shop.t_aktion")]:
		grid.add_child(_zelle(k, 12, Color(0.6, 0.66, 0.74)))
	for tid in ids:
		var t: Dictionary = GameData.TOOLS[tid]
		var owned: bool = Game.tools_owned.has(tid)
		var locked: bool = (not owned) and int(t.get("stufe", 0)) > Game.stage()
		var col := Color(0.92, 0.9, 0.85) if not locked else Color(0.55, 0.58, 0.64)
		var lock_txt := Texte.t("shop.gesperrt_zeile") % GameData.stufe_hint(int(t.get("stufe", 0))) if locked else "–"
		grid.add_child(_zelle(Texte.t("shop.haken_an") if owned else Texte.t("shop.haken_aus"), 13, col))
		# Der Name ist ebenfalls ein Knopf: Klick auf den Namen kauft bzw. gibt zurück (wie der Knopf rechts)
		var nk := Button.new()
		nk.flat = true
		nk.text = Texte.t(t.name)
		nk.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nk.add_theme_font_size_override("font_size", 13)
		nk.add_theme_color_override("font_color", col)
		nk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nk.disabled = locked or ((not owned) and Game.money < int(t.price))
		nk.pressed.connect(func() -> void: buy_tool(tid))
		grid.add_child(nk)
		grid.add_child(_zelle("%s €" % _fmt(int(t.price)), 13, col))
		grid.add_child(_zelle(_use_text(t), 13, col, true))
		grid.add_child(_zelle(lock_txt, 12, Color(0.6, 0.62, 0.68) if locked else col, true))
		var btn := UI.button(Texte.t("shop.knopf_zurueck") if owned else Texte.t("shop.knopf_kaufen"), func() -> void: buy_tool(tid), 0)
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = locked or ((not owned) and Game.money < int(t.price))
		btn.custom_minimum_size = Vector2(110, 28)
		btn.tooltip_text = Texte.t("shop.tool_tip") % [t.time, t.noise, t.evidence, t.max] + "\n" + Texte.t("shop.tool_tip_skill")
		grid.add_child(btn)
	_body = kleid
	_body.add_child(UI.label(Texte.t("shop.kleidung_kopf"), 15, Color(0.89, 0.71, 0.35)))
	var gids: Array = []
	for gid in GameData.GEAR:
		if gid != "none":
			gids.append(gid)
	gids.sort_custom(func(x, y): return Texte.t(GameData.GEAR[x].name) < Texte.t(GameData.GEAR[y].name))
	var ggrid := GridContainer.new()
	ggrid.columns = 4
	ggrid.add_theme_constant_override("h_separation", 12)
	ggrid.add_theme_constant_override("v_separation", 6)
	_body.add_child(ggrid)
	for k in [Texte.t("shop.t_status"), Texte.t("shop.t_name"), Texte.t("shop.t_preis"), Texte.t("shop.t_aktion")]:
		ggrid.add_child(_zelle(k, 12, Color(0.6, 0.66, 0.74)))
	for gid in gids:
		var g: Dictionary = GameData.GEAR[gid]
		var owned_g: bool = Game.gear_owned.has(gid)
		ggrid.add_child(_zelle(Texte.t("shop.haken_an") if owned_g else Texte.t("shop.haken_aus"), 13, Color(0.92, 0.9, 0.85)))
		var gk := Button.new()
		gk.flat = true
		gk.text = Texte.t(g.name)
		gk.alignment = HORIZONTAL_ALIGNMENT_LEFT
		gk.add_theme_font_size_override("font_size", 13)
		gk.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
		gk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gk.disabled = (not owned_g) and Game.money < int(g.price)
		gk.pressed.connect(func() -> void: buy_gear(gid))
		ggrid.add_child(gk)
		ggrid.add_child(_zelle("%s €" % _fmt(int(g.price)), 13, Color(0.92, 0.9, 0.85)))
		var bg := UI.button(Texte.t("shop.knopf_zurueck") if owned_g else Texte.t("shop.knopf_kaufen"), func() -> void: buy_gear(gid), 0)
		bg.add_theme_font_size_override("font_size", 12)
		bg.disabled = (not owned_g) and Game.money < int(g.price)
		bg.custom_minimum_size = Vector2(110, 28)
		ggrid.add_child(bg)
	_body = haupt


## Zelle einer Tabelle im Laden.
func _zelle(txt: String, fs: int, col: Color, grow := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if grow:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _build_autohaus() -> void:
	_body.add_child(UI.label(Texte.t("shop.fahrzeug_kopf"), 15, Color(0.89, 0.71, 0.35)))
	for cid in GameData.CARS:
		if cid == "limo":
			continue  # der Leihwagen wird im Autoverleih gemietet
		var c: Dictionary = GameData.CARS[cid]
		var chosen: bool = Game.car_id == cid
		var owned: bool = cid == "limo" or Game.cars_owned.has(cid)
		var price_txt := Texte.t("shop.miete") % _fmt(int(c.rent)) if cid == "limo" else Texte.t("shop.kaufpreis") % _fmt(int(c.price))
		var status := Texte.t("shop.gewaehlt_status") if chosen else ""
		var car_locked: bool = (not owned) and int(c.get("stufe", 0)) > Game.stage()
		if car_locked:
			status = Texte.t("shop.gesperrt_zeile") % GameData.stufe_hint(int(c.get("stufe", 0)))
		if c.has("bild") and ResourceLoader.exists(str(c.bild)):
			var tr := TextureRect.new()
			tr.texture = load(str(c.bild))
			tr.custom_minimum_size = Vector2(0, 150)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_body.add_child(tr)
		_body.add_child(UI.label("%s  ·  %s%s" % [Texte.t(c.name), price_txt, status], 14, Color(0.92, 0.9, 0.85)))
		_body.add_child(UI.label(Texte.t(str(c.info)), 12, Color(0.75, 0.8, 0.88), true))
		if owned:
			var b := UI.button(Texte.t("shop.nehmen") if not chosen else Texte.t("shop.gewaehlt"), func() -> void: choose_car(cid), 0)
			b.disabled = chosen
			b.custom_minimum_size = Vector2(0, 34)
			_body.add_child(b)
			if cid != "limo":
				var bv := UI.button(Texte.t("shop.verkaufen") % _fmt(int(c.price) / 2), func() -> void: sell_car(cid), 0)
				bv.custom_minimum_size = Vector2(0, 34)
				_body.add_child(bv)
		else:
			var b2 := UI.button(Texte.t("shop.kaufen") % _fmt(int(c.price)), func() -> void: buy_car(cid), 0)
			b2.disabled = car_locked or Game.money < int(c.price)
			b2.custom_minimum_size = Vector2(0, 34)
			_body.add_child(b2)


## Werkzeug kaufen; nochmal klicken gibt es zurück (voller Preis).
func buy_tool(tid: String) -> void:
	var t: Dictionary = GameData.TOOLS[tid]
	if not Game.tools_owned.has(tid) and int(t.get("stufe", 0)) > Game.stage():
		_msg.text = "%s ist noch nicht zu haben (%s)." % [Texte.t(t.name), GameData.stufe_hint(int(t.get("stufe", 0)))]
		return
	if Game.tools_owned.has(tid):
		Game.tools_owned.erase(tid)
		Game.money += int(t.price)
		_msg.text = Texte.t("shop.zurueckgegeben") % [Texte.t(t.name), _fmt(Game.money)]
	else:
		if Game.money < int(t.price):
			_msg.text = Texte.t("shop.zu_wenig") % Texte.t(t.name)
			return
		Game.money -= int(t.price)
		Game.tools_owned[tid] = true
		_msg.text = "%s gekauft." % Texte.t(t.name)
	_build()


## Kleidung kaufen oder zurückgeben.
func buy_gear(gid: String) -> void:
	var g: Dictionary = GameData.GEAR[gid]
	if Game.gear_owned.has(gid):
		Game.gear_owned.erase(gid)
		Game.money += int(g.price)
		_msg.text = Texte.t("shop.zurueckgegeben") % [Texte.t(g.name), _fmt(Game.money)]
	else:
		if Game.money < int(g.price):
			_msg.text = Texte.t("shop.zu_wenig") % Texte.t(g.name)
			return
		Game.money -= int(g.price)
		Game.gear_owned[gid] = true
		_msg.text = "%s gekauft." % Texte.t(g.name)
	_build()


## Fahrzeug kaufen; danach ist es der gewählte Wagen.
func buy_car(cid: String) -> void:
	var c: Dictionary = GameData.CARS[cid]
	if not Game.cars_owned.has(cid) and int(c.get("stufe", 0)) > Game.stage():
		_msg.text = "%s ist noch nicht zu haben (%s)." % [Texte.t(c.name), GameData.stufe_hint(int(c.get("stufe", 0)))]
		return
	if Game.cars_owned.has(cid):
		choose_car(cid)
		return
	if Game.money < int(c.price):
		_msg.text = Texte.t("shop.zu_wenig") % Texte.t(c.name)
		return
	Game.money -= int(c.price)
	Game.cars_owned[cid] = true
	Game.car_id = cid
	_msg.text = Texte.t("shop.car_gekauft") % Texte.t(c.name)
	_build()


## Gekauften Wagen verkaufen: Rückkaufwert die Hälfte des Kaufpreises. Ist er gewählt, fährt man danach die Limousine.
func sell_car(cid: String) -> void:
	if cid == "limo" or not Game.cars_owned.has(cid):
		return
	var c: Dictionary = GameData.CARS[cid]
	var erloes := int(c.price) / 2
	Game.cars_owned.erase(cid)
	Game.money += erloes
	if Game.car_id == cid:
		Game.car_id = ""
	_msg.text = Texte.t("shop.car_verkauft") % [Texte.t(c.name), _fmt(erloes)]
	_build()


## Fahrzeug wählen: ein gekaufter Wagen (der Leihwagen wird im Autoverleih gemietet).
func choose_car(cid: String) -> void:
	if cid != "limo" and not Game.cars_owned.has(cid):
		_msg.text = Texte.t("shop.nicht_dein")
		return
	Game.car_id = cid
	_msg.text = Texte.t("shop.car_gewaehlt") % Texte.t(GameData.CARS[cid].name)
	_build()


## Autoverleih: Leihwagen mieten oder den Mietvertrag kündigen.
func _build_verleih() -> void:
	_body.add_child(UI.label(Texte.t("shop.verleih_kopf"), 15, Color(0.89, 0.71, 0.35)))
	var leih: Dictionary = GameData.CARS.limo
	_body.add_child(UI.label("%s  ·  %s" % [Texte.t(leih.name), Texte.t("shop.miete") % _fmt(int(leih.rent))], 14, Color(0.92, 0.9, 0.85)))
	_body.add_child(UI.label(Texte.t(str(leih.info)), 12, Color(0.75, 0.8, 0.88), true))
	if Game.car_id == "limo":
		_body.add_child(UI.label(Texte.t("shop.verleih_gemietet"), 13, Color(0.6, 0.85, 0.6)))
		var k := UI.button(Texte.t("shop.verleih_kuendigen"), func() -> void: verleih_kuendigen(), 0)
		k.custom_minimum_size = Vector2(0, 34)
		_body.add_child(k)
	else:
		if Game.car_id != "":
			_body.add_child(UI.label(Texte.t("shop.verleih_anderes") % Texte.t(GameData.CARS[Game.car_id].name), 13, Color(0.75, 0.8, 0.88)))
		var m := UI.button(Texte.t("shop.verleih_mieten"), func() -> void: verleih_mieten(), 0)
		m.custom_minimum_size = Vector2(0, 34)
		_body.add_child(m)


func verleih_mieten() -> void:
	Game.car_id = "limo"
	_msg.text = Texte.t("shop.verleih_gemietet_msg")
	_build()


func verleih_kuendigen() -> void:
	Game.car_id = ""
	_msg.text = Texte.t("shop.verleih_gekuendigt")
	_build()


func _use_text(t: Dictionary) -> String:
	if str(t.get("ability", "")) == "":
		return Texte.t("shop.jeder")
	return Texte.t("shop.ab_prozent") % [Texte.t(GameData.TOOL_SKILL_KEY.get(t.type, "skill.technik")), int(t.min)]


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

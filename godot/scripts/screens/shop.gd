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
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 14))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := Texte.t("shop.titel_laden") if kind == "laden" else Texte.t("shop.titel_autohaus")
	head.add_child(UI.label(title, 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_money = UI.label("", 15, Color(0.85, 0.9, 0.95))
	head.add_child(_money)
	head.add_child(UI.button(Texte.t("shop.zurueck"), func() -> void: main.go("town"), 160))
	root.add_child(head)
	# Bild des Ortes: ganz zu sehen, Seitenverhältnis bleibt
	var pic_path := "res://assets/art/shop_werkzeug.jpg" if kind == "laden" else "res://assets/art/shop_autohaus.jpg"
	if ResourceLoader.exists(pic_path):
		var pic := TextureRect.new()
		pic.texture = load(pic_path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, 280)
		root.add_child(pic)
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
	_money.text = "Geld: %s €" % _fmt(Game.money)
	if kind == "laden":
		_build_laden()
	else:
		_build_autohaus()


func _build_laden() -> void:
	_body.add_child(UI.label(Texte.t("shop.werkzeug_kopf"), 15, Color(0.89, 0.71, 0.35)))
	for tid in GameData.TOOLS:
		var t: Dictionary = GameData.TOOLS[tid]
		var owned: bool = Game.tools_owned.has(tid)
		var locked: bool = (not owned) and int(t.get("stufe", 0)) > Game.stage()
		var lock_txt := "  ·  gesperrt, %s" % GameData.stufe_hint(int(t.get("stufe", 0))) if locked else ""
		var b := UI.button(Texte.t("shop.tool_btn") % [t.name, _fmt(int(t.price)), _use_text(t), Texte.t("shop.gekauft") if owned else "", lock_txt], func() -> void: buy_tool(tid), 0)
		b.add_theme_font_size_override("font_size", 13)
		b.disabled = locked or ((not owned) and Game.money < int(t.price))
		b.custom_minimum_size = Vector2(0, 34)
		b.tooltip_text = Texte.t("shop.tool_tip") % [t.time, t.noise, t.evidence, t.max]
		_body.add_child(b)
	_body.add_child(UI.label("Kleidung", 15, Color(0.89, 0.71, 0.35)))
	for gid in GameData.GEAR:
		if gid == "none":
			continue
		var g: Dictionary = GameData.GEAR[gid]
		var owned_g: bool = Game.gear_owned.has(gid)
		var bg := UI.button(Texte.t("shop.gear_btn") % [g.name, _fmt(int(g.price)), Texte.t("shop.gekauft") if owned_g else ""], func() -> void: buy_gear(gid), 0)
		bg.add_theme_font_size_override("font_size", 13)
		bg.disabled = (not owned_g) and Game.money < int(g.price)
		bg.custom_minimum_size = Vector2(0, 34)
		_body.add_child(bg)


func _build_autohaus() -> void:
	_body.add_child(UI.label(Texte.t("shop.fahrzeug_kopf"), 15, Color(0.89, 0.71, 0.35)))
	for cid in GameData.CARS:
		var c: Dictionary = GameData.CARS[cid]
		var chosen: bool = Game.car_id == cid
		var owned: bool = cid == "limo" or Game.cars_owned.has(cid)
		var price_txt := "Miete %s € je Einbruch" % _fmt(int(c.rent)) if cid == "limo" else "Kaufpreis %s €" % _fmt(int(c.price))
		var status := Texte.t("shop.gewaehlt_status") if chosen else ""
		var car_locked: bool = (not owned) and int(c.get("stufe", 0)) > Game.stage()
		if car_locked:
			status = "  ·  gesperrt, %s" % GameData.stufe_hint(int(c.get("stufe", 0)))
		_body.add_child(UI.label("%s  ·  %s%s" % [c.name, price_txt, status], 14, Color(0.92, 0.9, 0.85)))
		_body.add_child(UI.label(str(c.info), 12, Color(0.75, 0.8, 0.88), true))
		if owned:
			var b := UI.button(Texte.t("shop.nehmen") if not chosen else Texte.t("shop.gewaehlt"), func() -> void: choose_car(cid), 0)
			b.disabled = chosen
			b.custom_minimum_size = Vector2(0, 34)
			_body.add_child(b)
		else:
			var b2 := UI.button("Kaufen – %s €" % _fmt(int(c.price)), func() -> void: buy_car(cid), 0)
			b2.disabled = car_locked or Game.money < int(c.price)
			b2.custom_minimum_size = Vector2(0, 34)
			_body.add_child(b2)


## Werkzeug kaufen; nochmal klicken gibt es zurück (voller Preis).
func buy_tool(tid: String) -> void:
	var t: Dictionary = GameData.TOOLS[tid]
	if not Game.tools_owned.has(tid) and int(t.get("stufe", 0)) > Game.stage():
		_msg.text = "%s ist noch nicht zu haben (%s)." % [t.name, GameData.stufe_hint(int(t.get("stufe", 0)))]
		return
	if Game.tools_owned.has(tid):
		Game.tools_owned.erase(tid)
		Game.money += int(t.price)
		_msg.text = Texte.t("shop.zurueckgegeben") % [t.name, _fmt(Game.money)]
	else:
		if Game.money < int(t.price):
			_msg.text = Texte.t("shop.zu_wenig") % t.name
			return
		Game.money -= int(t.price)
		Game.tools_owned[tid] = true
		_msg.text = "%s gekauft." % t.name
	_build()


## Kleidung kaufen oder zurückgeben.
func buy_gear(gid: String) -> void:
	var g: Dictionary = GameData.GEAR[gid]
	if Game.gear_owned.has(gid):
		Game.gear_owned.erase(gid)
		Game.money += int(g.price)
		_msg.text = Texte.t("shop.zurueckgegeben") % [g.name, _fmt(Game.money)]
	else:
		if Game.money < int(g.price):
			_msg.text = Texte.t("shop.zu_wenig") % g.name
			return
		Game.money -= int(g.price)
		Game.gear_owned[gid] = true
		_msg.text = "%s gekauft." % g.name
	_build()


## Fahrzeug kaufen; danach ist es der gewählte Wagen.
func buy_car(cid: String) -> void:
	var c: Dictionary = GameData.CARS[cid]
	if not Game.cars_owned.has(cid) and int(c.get("stufe", 0)) > Game.stage():
		_msg.text = "%s ist noch nicht zu haben (%s)." % [c.name, GameData.stufe_hint(int(c.get("stufe", 0)))]
		return
	if Game.cars_owned.has(cid):
		choose_car(cid)
		return
	if Game.money < int(c.price):
		_msg.text = Texte.t("shop.zu_wenig") % c.name
		return
	Game.money -= int(c.price)
	Game.cars_owned[cid] = true
	Game.car_id = cid
	_msg.text = Texte.t("shop.car_gekauft") % c.name
	_build()


## Fahrzeug wählen: Miete der Limousine oder ein gekaufter Wagen.
func choose_car(cid: String) -> void:
	if cid != "limo" and not Game.cars_owned.has(cid):
		_msg.text = Texte.t("shop.nicht_dein")
		return
	Game.car_id = cid
	_msg.text = Texte.t("shop.car_gewaehlt") % GameData.CARS[cid].name
	_build()


func _use_text(t: Dictionary) -> String:
	if str(t.get("ability", "")) == "":
		return "jeder kann es"
	return "%s ab %d %%" % [t.ability, int(t.min)]


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

class_name UI
extends RefCounted
## Kleine Helfer zum Bauen der Oberfläche im Code.


static func label(text: String, size := 16, color := Color(0.92, 0.9, 0.85), wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


## Symbol aus assets/icons (goldene Linien). Fehlt die Datei, bleibt es beim Text.
static func icon(name: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func button(text: String, cb: Callable, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 40)
	b.pressed.connect(cb)
	return b


static func background(color := Color(0.08, 0.09, 0.12)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func margin(child: Control, px := 20) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", px)
	m.add_theme_constant_override("margin_right", px)
	m.add_theme_constant_override("margin_top", px)
	m.add_theme_constant_override("margin_bottom", px)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_child(child)
	return m


static func card(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.18)
	sb.border_color = Color(0.75, 0.6, 0.25, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(content)
	return p


static func primary(text: String, cb: Callable, min_w := 0) -> Button:
	## Goldener Hauptknopf (z. B. „Ausführung vorbereiten“).
	var b := button(text, cb, min_w)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.89, 0.71, 0.35)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	var hover := sb.duplicate()
	hover.bg_color = Color(0.95, 0.78, 0.42)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", Color(0.07, 0.07, 0.1))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.08))
	return b


static func backdrop(path := "res://assets/art/bg_default.jpg") -> TextureRect:
	## Nächtlicher Hintergrund aus assets/art (falls vorhanden), sonst radialer Verlauf.
	if ResourceLoader.exists(path):
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return pic
	var grad := Gradient.new()
	grad.set_color(0, Color(0.13, 0.18, 0.3))
	grad.set_color(1, Color(0.02, 0.03, 0.06))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.45, 0.25)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 1024
	tex.height = 512
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func card_style(color := Color(0.07, 0.1, 0.16, 0.72)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.89, 0.71, 0.35, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	return sb


## Einklappbarer Bereich (Drop-down): Kopfzeile mit ▸/▾ klappt den Inhalt auf oder zu.
static func fold(title: String, content: Control, open := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := Button.new()
	head.toggle_mode = true
	head.button_pressed = open
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.flat = true
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Color(0.89, 0.71, 0.35))
	head.text = ("▾ " if open else "▸ ") + title.to_upper()
	head.tooltip_text = Texte.t("ui.klick_aufklappen")
	content.visible = open
	head.toggled.connect(func(on: bool):
		content.visible = on
		head.text = ("▾ " if on else "▸ ") + title.to_upper())
	v.add_child(head)
	v.add_child(content)
	return p


## Auswahlliste (Drop-down) für eine Einzelauswahl.
static func dropdown(items: Array, selected: int, cb: Callable) -> OptionButton:
	var ob := OptionButton.new()
	for i in range(items.size()):
		ob.add_item(str(items[i]), i)
	ob.select(selected)
	ob.item_selected.connect(func(i: int): cb.call(i))
	return ob


## Mehrfachauswahl als Menü mit Häkchen. items: [[Anzeige, Id], ...]. cb(id, an_oder_aus).
static func multi_menu(title: String, items: Array, selected: Array, cb: Callable) -> MenuButton:
	var mb := MenuButton.new()
	mb.flat = false
	var pm := mb.get_popup()
	pm.hide_on_checkable_item_selection = false
	for i in range(items.size()):
		pm.add_check_item(str(items[i][0]), i)
		pm.set_item_checked(i, selected.has(items[i][1]))
	mb.clip_text = true
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh := func():
		var names: Array = []
		for i in range(items.size()):
			if pm.is_item_checked(i):
				names.append(str(items[i][0]))
		# Kurze Anzeige, die Namen stehen im Hinweis
		if names.is_empty():
			mb.text = title
		elif names.size() == 1:
			mb.text = names[0]
		else:
			mb.text = Texte.t("ui.teile") % names.size()
		mb.tooltip_text = ", ".join(names) if not names.is_empty() else title
	refresh.call()
	pm.id_pressed.connect(func(i: int):
		var on := not pm.is_item_checked(i)
		pm.set_item_checked(i, on)
		cb.call(items[i][1], on)
		refresh.call())
	return mb

## Warnung, die man wegklicken muss: wenn etwas die nächste Aktion blockiert.
static func hinweis(host: Node, titel: String, text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = titel
	dlg.dialog_text = text
	dlg.ok_button_text = Texte.t("hint.verstanden")
	dlg.dialog_autowrap = true
	host.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(520, 0))

extends Control
## Spielstände: drei Plätze mit Übersicht. Laden, neu beginnen (mit Bestätigung), löschen (mit Sicherung).

var main
var args: Dictionary = {}
var _rows: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.backdrop())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 40))
	var head := HBoxContainer.new()
	var titel := "Neues Spiel: Platz wählen" if str(args.get("mode", "alle")) == "neu" else "Spielstände"
	head.add_child(UI.label(titel, 26, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.button("Zurück", func(): main.go("title"), 140))
	root.add_child(head)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	root.add_child(_rows)
	root.add_child(UI.label("Ein neues Spiel auf einem belegten Platz überschreibt den Stand. Der alte Stand bleibt als Sicherung (.bak) erhalten.", 13, Color(0.7, 0.74, 0.8), true))
	_fill()


func _fill() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for n in range(1, Game.SLOTS + 1):
		_rows.add_child(_row(n))


func _row(n: int) -> Control:
	var info: Dictionary = Game.slot_info(n)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card_style(Color(0.06, 0.08, 0.13, 0.96)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(txt)
	if info.get("leer", true):
		txt.add_child(UI.label("Platz %d: leer" % n, 16, Color(0.7, 0.72, 0.78)))
	elif info.get("defekt", false):
		txt.add_child(UI.label("Platz %d: Stand nicht lesbar" % n, 16, Color(1, 0.6, 0.5)))
	else:
		var pl: String = " · " + {"fahndung": "Fahndung zu hoch", "pleite": "Pleite"}.get(str(info.pleite), "") if str(info.pleite) != "" else ""
		txt.add_child(UI.label("Platz %d · Tag %d · Geld %s €%s" % [n, int(info.tag), _fmt(int(info.geld)), pl], 16, Color(0.92, 0.9, 0.85)))
		txt.add_child(UI.label("Einbrüche: %d" % int(info.einbrueche), 13, Color(0.75, 0.8, 0.88)))
	if str(args.get("mode", "alle")) == "neu":
		h.add_child(UI.button("Neues Spiel hier", func(): _new(n), 200))
	if not info.get("leer", true) and not info.get("defekt", false):
		h.add_child(UI.button("Laden", func(): _load(n), 130))
		h.add_child(UI.button("Löschen", func(): _ask_delete(n), 120))
	return card


func _load(n: int) -> void:
	if Game.load_game(n):
		main.go("town")
	else:
		main.show_error(Game.last_error if Game.last_error != "" else Texte.t("fehler.allgemein"), "Lösche den Platz oder wähle einen anderen Platz. Die Sicherung (.bak) bleibt erhalten.")


func _new(n: int) -> void:
	if Game.slot_info(n).get("leer", true):
		Game.new_game_in_slot(n)
		main.go("town")
		return
	var d := ConfirmationDialog.new()
	d.title = "Platz überschreiben?"
	d.dialog_text = "Platz %d wird mit einem neuen Spiel überschrieben. Der bisherige Stand bleibt als Sicherung erhalten." % n
	d.ok_button_text = "Überschreiben"
	add_child(d)
	d.confirmed.connect(func(): Game.new_game_in_slot(n); main.go("town"))
	d.popup_centered()


func _ask_delete(n: int) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Spielstand löschen?"
	d.dialog_text = "Platz %d wird gelöscht. Eine Sicherung bleibt erhalten." % n
	d.ok_button_text = "Löschen"
	add_child(d)
	d.confirmed.connect(func(): Game.delete_slot(n); _fill())
	d.popup_centered()


func _fmt(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if v < 0 else "") + out

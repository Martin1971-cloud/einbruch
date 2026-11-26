class_name Optionen
extends Control
## Optionen: Musik, Textgröße, Hinweise, Vollbild. Öffnet sich mit O (überall) oder über den Knopf im Stadtkopf.

var im_spiel := false  # true, wenn ein Spiel läuft (dann wird beim Beenden gespeichert angeboten)
var _music_lbl: Label
var _text_lbl: Label
var _hint_btn: Button
var _full_btn: Button
var _tele_btn: Button
var _einfach_btn: Button


func _toggle_einfach() -> void:
	Game.settings["einfach"] = not bool(Game.settings.get("einfach", false))
	Game.save_settings()
	_refresh()


func _toggle_telemetrie() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Game.SETTINGS_PATH)
	cfg.set_value("telemetrie", "an", not Telemetrie.enabled())
	cfg.save(Game.SETTINGS_PATH)
	_refresh()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card_style(Color(0.06, 0.08, 0.13, 0.98)))
	card.custom_minimum_size = Vector2(520, 0)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UI.label(Texte.t("optionen.titel"), 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.button(Texte.t("optionen.schliessen"), close, 150))
	box.add_child(head)

	# Musik: Lautstärke in Schritten von 10 %
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 10)
	mrow.add_child(UI.label(Texte.t("optionen.musik"), 15, Color(0.92, 0.9, 0.85)))
	var msp := Control.new()
	msp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(msp)
	mrow.add_child(UI.button("−", func(): _set_music(Game.settings.music - 10), 44))
	_music_lbl = UI.label("", 15, Color(0.92, 0.9, 0.85))
	_music_lbl.custom_minimum_size = Vector2(70, 0)
	_music_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mrow.add_child(_music_lbl)
	mrow.add_child(UI.button("+", func(): _set_music(Game.settings.music + 10), 44))
	box.add_child(mrow)

	# Textgröße (Planung): 10 bis 18
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	trow.add_child(UI.label(Texte.t("opt.textgroesse"), 15, Color(0.92, 0.9, 0.85)))
	var tsp := Control.new()
	tsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tsp)
	trow.add_child(UI.button("A−", func(): _set_text(Game.settings.text_size - 1), 56))
	_text_lbl = UI.label("", 15, Color(0.92, 0.9, 0.85))
	_text_lbl.custom_minimum_size = Vector2(70, 0)
	_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trow.add_child(_text_lbl)
	trow.add_child(UI.button("A+", func(): _set_text(Game.settings.text_size + 1), 56))
	box.add_child(trow)

	# Hinweise und Vollbild: Schalter
	_hint_btn = UI.button("", _toggle_hints, 0)
	box.add_child(_hint_btn)
	_full_btn = UI.button("", _toggle_full, 0)
	box.add_child(_full_btn)
	# Telemetrie ist nur für die Entwicklung: in Auslieferungsbuilds nicht sichtbar
	if OS.is_debug_build():
		_tele_btn = UI.button("", _toggle_telemetrie, 0)
		box.add_child(_tele_btn)
	_einfach_btn = UI.button("", _toggle_einfach, 0)
	box.add_child(_einfach_btn)
	box.add_child(UI.button(Texte.t("opt.beenden"), _on_beenden, 0))
	box.add_child(UI.label(Texte.t("opt.hinweis_text"), 12, Color(0.7, 0.74, 0.8), true))
	box.add_child(UI.label(Texte.t("opt.musik_quelle"), 11, Color(0.62, 0.66, 0.72), true))
	_refresh()


## Spiel beenden. Im laufenden Spiel wird vorher gefragt, ob der Stand gespeichert werden soll.
func _on_beenden() -> void:
	beenden_frage(self, im_spiel)


static func beenden_frage(host: Node, im_spiel_offen: bool) -> void:
	if not im_spiel_offen:
		host.get_tree().quit()
		return
	var d := ConfirmationDialog.new()
	d.title = Texte.t("opt.beenden_titel")
	d.dialog_text = Texte.t("opt.beenden_frage")
	d.ok_button_text = Texte.t("opt.beenden_speichern")
	d.cancel_button_text = Texte.t("ui.abbrechen")
	d.add_button(Texte.t("opt.beenden_ohne"), true, "ohne")
	host.add_child(d)
	d.confirmed.connect(func(): Game.save_game(); host.get_tree().quit())
	d.custom_action.connect(func(aktion: String): _beenden_ohne_speichern(host, aktion))
	d.popup_centered()


static func _beenden_ohne_speichern(host: Node, aktion: String) -> void:
	if aktion == "ohne":
		host.get_tree().quit()


func _set_music(v: int) -> void:
	Game.settings.music = clampi(v, 0, 100)
	Game.apply_settings()
	Game.save_settings()
	_refresh()


func _set_text(v: int) -> void:
	Game.settings.text_size = clampi(v, 10, 18)
	Game.save_settings()
	_refresh()


func _toggle_hints() -> void:
	Game.hints_enabled = not Game.hints_enabled
	Game.save_settings()
	Game.save_game()
	_refresh()


func _toggle_full() -> void:
	Game.settings.fullscreen = not Game.settings.fullscreen
	Game.apply_settings()
	Game.save_settings()
	_refresh()


func _refresh() -> void:
	_music_lbl.text = "%d %%" % Game.settings.music
	_text_lbl.text = "%d" % Game.settings.text_size
	_hint_btn.text = Texte.t("opt.hinweise_zeile") % (Texte.t("opt.an") if Game.hints_enabled else Texte.t("opt.aus"))
	_full_btn.text = Texte.t("opt.vollbild_zeile") % (Texte.t("opt.an") if Game.settings.fullscreen else Texte.t("opt.aus"))
	if _tele_btn != null:
		_tele_btn.text = Texte.t("opt.telemetrie_zeile") % (Texte.t("opt.an") if Telemetrie.enabled() else Texte.t("opt.aus"))
	_einfach_btn.text = Texte.t("opt.einfach_zeile") % (Texte.t("opt.an") if bool(Game.settings.get("einfach", false)) else Texte.t("opt.aus"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()

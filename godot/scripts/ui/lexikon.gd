class_name Lexikon
extends Control
## Lexikon: erklärt die Begriffe des Spiels. Öffnet sich mit L (überall) oder über den Knopf im Stadtkopf.

var _list: VBoxContainer
var _search: LineEdit
var _hint_btn: Button


func _toggle_hints() -> void:
	Game.hints_enabled = not Game.hints_enabled
	Game.save_game()
	_refresh_hint_button()


func _reset_hints() -> void:
	Game.hints_reset()
	_refresh_hint_button()


func _refresh_hint_button() -> void:
	if _hint_btn != null:
		_hint_btn.text = Texte.t("opt.hinweise_zeile") % (Texte.t("opt.an") if Game.hints_enabled else Texte.t("opt.aus"))


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
	card.custom_minimum_size = Vector2(640, 520)
	# Mitte des Fensters: Anker in der Mitte, das Fenster wächst nach beiden Seiten
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UI.label(Texte.t("lexikon.titel"), 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.button(Texte.t("ui.schliessen"), close, 150))
	box.add_child(head)
	# Hinweise: ein/aus und wieder zeigen
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 10)
	_hint_btn = UI.button("", _toggle_hints, 260)
	hint_row.add_child(_hint_btn)
	hint_row.add_child(UI.button(Texte.t("lexikon.alle_hinweise"), _reset_hints, 260))
	box.add_child(hint_row)
	_refresh_hint_button()
	_search = LineEdit.new()
	_search.placeholder_text = Texte.t("lexikon.suche")
	_search.text_changed.connect(func(_t: String) -> void: _fill())
	box.add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_fill()
	_search.grab_focus()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower() if _search != null else ""
	var shown := 0
	for e in GameData.LEXIKON:
		var term: String = Texte.d(str(e.term))
		var text: String = Texte.d(str(e.text))
		if q != "" and not (term.to_lower().contains(q) or text.to_lower().contains(q)):
			continue
		shown += 1
		_list.add_child(UI.label(term, 15, Color(0.97, 0.85, 0.55)))
		_list.add_child(UI.label(text, 13, Color(0.86, 0.88, 0.93), true))
	if shown == 0:
		_list.add_child(UI.label(Texte.t("lexikon.kein_eintrag"), 13, Color(0.7, 0.72, 0.78)))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()

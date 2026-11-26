class_name Journal
extends Control
## Rückblick: alle Einbrüche mit Ergebnis, Auszahlung, Fehlern und Alarm. Öffnet sich mit J (überall) oder über den Knopf im Stadtkopf.


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
	card.custom_minimum_size = Vector2(700, 540)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UI.label(Texte.t("journal.titel"), 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.button(Texte.t("menue.beenden"), func(): Optionen.beenden_frage(self, true), 110))
	head.add_child(UI.button(Texte.t("ui.schliessen"), close, 150))
	box.add_child(head)
	var sums := _summary()
	box.add_child(UI.label(sums, 14, Color(0.86, 0.9, 0.95), true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if Game.journal.is_empty():
		list.add_child(UI.label(Texte.t("journal.leer"), 13, Color(0.7, 0.72, 0.78), true))
	# neueste zuerst
	for i in range(Game.journal.size() - 1, -1, -1):
		list.add_child(_entry(Game.journal[i]))


## Zusammenfassung: Anzahl, Erfolge, Festnahmen, Summen.
func _summary() -> String:
	var n := Game.journal.size()
	var ok := 0
	var caught := 0
	var pay := 0
	var gain := 0
	for e in Game.journal:
		if str(e.status).begins_with("ENTKOMMEN"):
			ok += 1
		if str(e.status) == "GEFASST":
			caught += 1
		pay += int(e.auszahlung)
		gain += int(e.gewinn)
	return Texte.t("journal.summary") % [n, ok, caught, _fmt(pay), ("+" if gain >= 0 else "") + _fmt(gain)]


func _entry(e: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var st := str(e.status)
	# Symbol plus Wort, damit die Bedeutung nicht nur über die Farbe kommt
	var mark := "✔" if st.begins_with("ENTKOMMEN") else ("✖" if st == "GEFASST" else "–")
	var col := Color(0.45, 0.9, 0.55) if st.begins_with("ENTKOMMEN") else (Color(1.0, 0.45, 0.4) if st == "GEFASST" else Color(0.85, 0.85, 0.6))
	var word: String = str({"ENTKOMMEN": Texte.t("journal.st_entkommen"), "ENTKOMMEN_HEISS": Texte.t("journal.st_heiss"), "GEFASST": Texte.t("journal.st_gefasst")}.get(st, Texte.t("journal.st_abbruch")))
	v.add_child(UI.label(Texte.t("journal.zeile_kopf") % [mark, int(e.tag), int(e.stunde), str(e.ziel), word], 15, col))
	var zeile := Texte.t("journal.zeile_zahlen") % [_fmt(int(e.auszahlung)), _fmt(int(e.kosten)), "+" if int(e.gewinn) >= 0 else "", _fmt(int(e.gewinn)), int(e.dauer)]
	v.add_child(UI.label(zeile, 13, Color(0.86, 0.88, 0.93)))
	var beute: Array = e.beute
	v.add_child(UI.label(Texte.t("journal.beute") % (", ".join(_names(beute)) if not beute.is_empty() else Texte.t("journal.beute_keine")), 13, Color(0.8, 0.84, 0.9), true))
	if str(e.alarm) != "":
		v.add_child(UI.label(Texte.t("journal.alarm") % str(e.alarm), 13, Color(1.0, 0.7, 0.4), true))
	if int(e.fehler) > 0:
		var txt := Texte.t("journal.fehler") % [int(e.fehler), " · ".join(e.fehler_text)]
		v.add_child(UI.label(txt, 13, Color(1.0, 0.6, 0.5), true))
	return v


func _names(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(Texte.t(str(x)))
	return out


func _fmt(n: int) -> String:
	return GameData.geld(n)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	queue_free()

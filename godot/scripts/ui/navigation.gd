class_name Navigation
extends RefCounted
## Die eine Navigationsleiste für alle Fenster: gleiche Knöpfe, gleiche Reihenfolge, gleiche Stelle.
## Das aktive Fenster ist hervorgehoben. Ausführung ist nur mit einer gültigen Planung anklickbar.
## Während der Ausführung sind nur Pause und Beenden erlaubt.

static func leiste(main: Node, aktiv: String, ausfuehrung_extra: Array = []) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.label(Texte.t("app.titel"), 22, Color(0.97, 0.82, 0.42)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	if aktiv == "ausfuehrung":
		for c in ausfuehrung_extra:
			row.add_child(c)
		row.add_child(UI.button(Texte.t("menue.beenden"), func(): Optionen.beenden_frage(main, true), 110))
		return row
	row.add_child(_knopf(aktiv, "stadt", Texte.t("nav.stadt"), func(): main.go("town"), 100))
	row.add_child(_knopf(aktiv, "organisation", Texte.t("nav.organisation"), func(): main.go("organisation"), 130))
	row.add_child(_knopf(aktiv, "planung", Texte.t("nav.planung"), func(): main.go("planner"), 100))
	var bereit: bool = not Game.ausfuehrung_cfg.is_empty()
	var ausf := _knopf(aktiv, "ausfuehrung", Texte.t("nav.ausfuehrung"), func(): main.go("execution", {"config": Game.ausfuehrung_cfg}), 110)
	ausf.disabled = not bereit
	row.add_child(ausf)
	row.add_child(_knopf(aktiv, "journal", Texte.t("nav.journal"), func(): main.open_journal(), 120))
	row.add_child(_knopf(aktiv, "lexikon", Texte.t("nav.lexikon"), func(): main.open_lexikon(), 120))
	row.add_child(_knopf(aktiv, "optionen", Texte.t("nav.optionen"), func(): main.open_optionen(), 130))
	row.add_child(_knopf(aktiv, "speichern", Texte.t("nav.speichern"), func(): main.open_slots(), 150))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	row.add_child(UI.button(Texte.t("menue.beenden"), func(): Optionen.beenden_frage(main, true), 110))
	return row

static func _knopf(aktiv: String, id: String, text: String, cb: Callable, min_w: int) -> Button:
	if aktiv == id:
		return UI.primary(text, cb, min_w)
	return UI.button(text, cb, min_w)

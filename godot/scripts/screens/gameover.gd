extends Control
## Spielende: Grund, Bilanz aus dem Journal und die Wege weiter (neues Spiel oder Titel).

var main
var args: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.backdrop())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.margin(root, 40))
	var reason: String = Game.game_over_reason
	var titel := Texte.t("spielende.titel")
	var grund := Texte.t("spielende.fahndung")
	if reason == "pleite":
		titel = Texte.t("spielende.pleite.titel")
		grund = Texte.t("spielende.pleite")
	root.add_child(UI.label(titel, 30, Color(1, 0.55, 0.45)))
	root.add_child(UI.label(grund, 16, Color(0.9, 0.9, 0.92), true))
	root.add_child(UI.label(_bilanz(), 15, Color(0.86, 0.9, 0.95), true))
	root.add_child(UI.label(Texte.t("gameover.hinweis"), 13, Color(0.7, 0.74, 0.8), true))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(UI.button(Texte.t("spielende.neu"), _new_game, 240))
	row.add_child(UI.button(Texte.t("spielende.titelbild"), func(): main.go("title"), 240))
	root.add_child(row)


## Bilanz aus dem Journal: Einbrüche, erfolgreiche, Festnahmen, Summen.
func _bilanz() -> String:
	var n := Game.journal.size()
	var ok := 0
	var caught := 0
	var pay := 0
	for e in Game.journal:
		if str(e.status).begins_with("ENTKOMMEN"):
			ok += 1
		if str(e.status) == "GEFASST":
			caught += 1
		pay += int(e.auszahlung)
	if n == 0:
		return Texte.t("gameover.noch_kein")
	return Texte.t("gameover.bilanz") % [n, ok, caught, pay]


func _new_game() -> void:
	Game.reset()
	Game.save_game()
	main.go("town")

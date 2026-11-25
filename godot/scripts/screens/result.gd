extends Control
## Auswertung nach einem Coup. Die Effekte (Geld, Fahndung, Zeit) wurden bereits in Game.apply_result angewendet.

var main: Node
var args: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UI.background(Color(0.07, 0.08, 0.11)))
	var res: Dictionary = args.get("result", {})
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	add_child(UI.margin(root, 26))

	var status: String = res.get("status", "ABBRUCH")
	var title_col := Color(0.5, 1.0, 0.6)
	var title_txt := Texte.t("res.entkommen")
	match status:
		"ENTKOMMEN_HEISS":
			title_txt = Texte.t("res.entkommen_heiss")
			title_col = Color(1.0, 0.9, 0.4)
		"GEFASST":
			title_txt = Texte.t("res.festgenommen")
			title_col = Color(1.0, 0.45, 0.4)
		"ABBRUCH":
			title_txt = Texte.t("res.abgebrochen")
			title_col = Color(1.0, 0.6, 0.4)
	root.add_child(UI.label(title_txt, 32, title_col))
	root.add_child(UI.label(str(res.get("reason", "")), 17, Color(0.92, 0.9, 0.85), true))

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_box.add_child(UI.label(Texte.t("res.erbeutet") % _list(res.get("loot_taken", [])), 17))
	card_box.add_child(UI.label(Texte.t("res.zurueck") % _list(res.get("loot_missed", [])), 17))
	card_box.add_child(UI.label(Texte.t("res.auszahlung") % _fmt(int(res.get("payout", 0))), 20, Color(0.95, 0.85, 0.5)))
	card_box.add_child(UI.label(Texte.t("res.fahndung") % [int(Game.heat), int(res.get("heat", 0.0))], 17))
	card_box.add_child(UI.label(Texte.t("res.geld") % [_fmt(Game.money), Game.day, Game.clock_text()], 17))
	root.add_child(UI.card(card_box))

	var log_box := RichTextLabel.new()
	log_box.custom_minimum_size = Vector2(0, 240)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.text = "\n".join(res.get("log", []))
	root.add_child(log_box)

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(sp)
	if Game.game_over:
		root.add_child(UI.label(Texte.t("res.vorbei"), 20, Color(1, 0.5, 0.4)))
		bottom.add_child(UI.button(Texte.t("res.weiter"), func(): main.go("gameover"), 240))
	else:
		bottom.add_child(UI.button(Texte.t("res.zur_stadt"), _on_town, 240))


func _list(a: Array) -> String:
	if a.is_empty():
		return "nichts"
	return ", ".join(a)


func _on_town() -> void:
	main.go("town")


func _on_restart() -> void:
	Game.reset()
	main.go("town")


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var i := s.length()
	while i > 3:
		out = "." + s.substr(i - 3, 3) + out
		i -= 3
	out = s.substr(0, i) + out
	return ("-" if n < 0 else "") + out

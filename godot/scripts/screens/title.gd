extends Control
## Titelbildschirm mit Spieltitel über der nächtlichen Stadt.

var main: Node
var args: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Startbild: Stadtpalais bei Nacht. Dunkler Verlauf von unten, damit der Titel lesbar bleibt.
	var pic := TextureRect.new()
	pic.texture = load("res://assets/art/title_palace.webp")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pic)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.06, 0.25))
	grad.set_color(1, Color(0.02, 0.03, 0.06, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.35)
	gt.fill_to = Vector2(0, 1)
	shade.material = null
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := UI.label(Texte.t("app.titel"), 74, Color(0.97, 0.82, 0.42))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var sub := UI.label(Texte.t("app.untertitel"), 22, Color(0.86, 0.82, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(sub)
	var line := ColorRect.new()
	line.color = Color(0.89, 0.71, 0.35, 0.8)
	line.custom_minimum_size = Vector2(360, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	var btns := VBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(btns)
	btns.add_child(UI.primary(Texte.t("menue.neu"), _on_new, 300))
	var _b := UI.button(Texte.t("menue.fortsetzen"), _on_continue, 300)
	_b.disabled = not Game.has_save(Game.last_slot())
	btns.add_child(_b)
	btns.add_child(UI.button(Texte.t("menue.staende"), func(): main.go("slots", {"mode": "alle"}), 300))
	btns.add_child(UI.button(Texte.t("menue.beenden"), func(): get_tree().quit(), 300))

	var credit := UI.label(Texte.t("app.hinweis_fiktiv"), 13, Color(0.7, 0.72, 0.78))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -34
	credit.offset_bottom = -10
	add_child(credit)


func _on_continue() -> void:
	if Game.load_game(Game.last_slot()):
		main.go("town")
	else:
		main.show_error(Game.last_error if Game.last_error != "" else Texte.t("fehler.allgemein"), "Wähle „Spielstände“ und einen anderen Platz, oder beginne ein neues Spiel.")


func _on_new() -> void:
	main.go("slots", {"mode": "neu"})

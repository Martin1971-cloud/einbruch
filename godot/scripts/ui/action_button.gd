class_name ActionButton
extends Button
## Aktions-Aktion in der Palette. Wird per Drag & Drop auf eine Zeitleiste gezogen.

var kind := ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "  " + text + "  "
	preview.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	var panel := PanelContainer.new()
	panel.add_child(preview)
	set_drag_preview(panel)
	return {"type": "aktion", "kind": kind}

class_name Lane
extends PanelContainer
## Zeitleiste einer Person. Nimmt Aktionen per Drag & Drop an und
## zeigt die Aktionen mit ihren Parametern.

signal dropped(crew_id: String, kind: String)
signal changed()

var crew_id := ""
var actions: Array = []
var _rows: VBoxContainer
var _options: Dictionary  # Name -> Array für Auswahllisten (vom Planer gesetzt)


func _init(p_crew_id: String) -> void:
	crew_id = p_crew_id
	custom_minimum_size = Vector2(0, 40)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)


func setup(p_actions: Array, options: Dictionary) -> void:
	actions = p_actions
	_options = options
	rebuild()


func rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	if actions.is_empty():
		var hint := UI.label("Aktion hierher ziehen …", 14, Color(0.5, 0.52, 0.56))
		_rows.add_child(hint)
		return
	for i in range(actions.size()):
		_rows.add_child(_row(i))


func _row(i: int) -> HBoxContainer:
	var a: Dictionary = actions[i]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_lbl := UI.label("%d. %s" % [i + 1, GameData.ACTION_NAMES.get(a.t, a.t)], 14)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name_lbl)
	match a.t:
		"MOVE":
			row.add_child(_option(_options.points, a.get("to", ""), func(v): a.to = v))
		"TOOL":
			row.add_child(_option(_options.tools, a.tool, func(v): a.tool = v))
			row.add_child(UI.label("an", 14))
			row.add_child(_option(_options.doors, a.on, func(v): a.on = v))
		"OPEN":
			row.add_child(_option(_options.doors, a.on, func(v): a.on = v))
		"TAKE":
			row.add_child(_option(_options.loot, a.loot, func(v): a.loot = v))
		"WAIT":
			var sb := SpinBox.new()
			sb.min_value = 1
			sb.max_value = 180
			sb.value = float(a.sec)
			sb.value_changed.connect(func(v): a.sec = v; changed.emit())
			row.add_child(sb)
			row.add_child(UI.label("Sekunden", 14))
		"NEUTRALIZE":
			row.add_child(_option(_options.guards, a.guard, func(v): a.guard = v))
		"FLAG_SET", "FLAG_WAIT":
			row.add_child(_option(_options.flags, a.flag, func(v): a.flag = v))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(_small_button("▲", func(): _move(i, -1)))
	row.add_child(_small_button("▼", func(): _move(i, 1)))
	row.add_child(_small_button("✕", func(): _remove(i)))
	return row


func _option(list: Array, current: String, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	var sel := 0
	for j in range(list.size()):
		var item: Array = list[j]
		ob.add_item(item[0])
		ob.set_item_metadata(j, item[1])
		if item[1] == current:
			sel = j
	ob.select(sel)
	ob.custom_minimum_size = Vector2(150, 0)
	ob.item_selected.connect(func(idx): on_pick.call(ob.get_item_metadata(idx)); changed.emit())
	return ob


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(28, 26)
	b.pressed.connect(cb)
	return b


func _move(i: int, dir: int) -> void:
	var j := i + dir
	if j < 0 or j >= actions.size():
		return
	var tmp = actions[i]
	actions[i] = actions[j]
	actions[j] = tmp
	rebuild()
	changed.emit()


func _remove(i: int) -> void:
	actions.remove_at(i)
	rebuild()
	changed.emit()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "aktion"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(crew_id, data.kind)

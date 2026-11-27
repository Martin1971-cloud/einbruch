extends Control
## Wechselt zwischen den Bildschirmen: Stadt, Organisation, Planung, Ausführung, Auswertung.

var current: Node = null


func _ready() -> void:
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	go("title")


## Lexikon: mit L von jedem Bildschirm aus (ein zweites Mal drücken schließt es).
var _lexikon: Control = null


func open_lexikon() -> void:
	if _lexikon != null and is_instance_valid(_lexikon):
		_lexikon.close()
		_lexikon = null
		return
	_lexikon = Lexikon.new()
	add_child(_lexikon)


var _optionen: Control = null
var _journal: Control = null


## Fehlerbericht für den Spieler: verständliche Meldung mit Hinweis, was zu tun ist. Der Fehler wird zusätzlich
## in eine Protokolldatei geschrieben (für den Entwickler), ohne persönliche Daten.
const FEHLER_LOG := "user://einbruch_fehler.log"


func show_error(meldung: String, was_tun: String, details := "") -> void:
	var f := FileAccess.open(FEHLER_LOG, FileAccess.READ_WRITE if FileAccess.file_exists(FEHLER_LOG) else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line("%s | %s | %s" % [Time.get_datetime_string_from_system(), meldung, details])
	var dlg := AcceptDialog.new()
	dlg.title = "Hinweis"
	dlg.dialog_text = "%s\n\nWas du tun kannst: %s" % [meldung, was_tun]
	dlg.ok_button_text = Texte.t("hint.verstanden")
	dlg.dialog_autowrap = true
	dlg.get_label().add_theme_font_size_override("font_size", 14)
	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(480, 0))


func open_journal() -> void:
	if _journal != null and is_instance_valid(_journal):
		_journal.close()
		_journal = null
		return
	_journal = Journal.new()
	add_child(_journal)


## Laden/Speichern (Spielstände) als Überlagerung über dem aktuellen Fenster.
var _slots: Control = null


func open_slots() -> void:
	if _slots != null and is_instance_valid(_slots):
		_slots.queue_free()
		_slots = null
		return
	_slots = preload("res://scripts/screens/slots.gd").new()
	_slots.main = self
	_slots.args = {"overlay": true}
	add_child(_slots)


func open_optionen() -> void:
	if _optionen != null and is_instance_valid(_optionen):
		_optionen.close()
		_optionen = null
		return
	_optionen = Optionen.new()
	_optionen.im_spiel = not _auf_titel()
	add_child(_optionen)


## Ist der Titelbildschirm offen? Dort gibt es noch keinen Spielstand zum Speichern.
func _auf_titel() -> bool:
	var skript = current.get_script() if current != null else null
	return skript != null and str(skript.resource_path).ends_with("title.gd")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		open_lexikon()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		open_lexikon()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		open_journal()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		open_optionen()
		get_viewport().set_input_as_handled()


func _fit_viewport() -> void:
	## Der Hauptknoten liegt direkt unter dem Fenster, daher Größe manuell setzen.
	position = Vector2.ZERO
	size = get_viewport_rect().size


func go(screen: String, args: Dictionary = {}) -> void:
	# Spielende: Fahndung oder Pleite führen zuerst auf den Bildschirm „Spielende“
	if screen == "town":
		Game.check_pleite()
		if Game.game_over:
			screen = "gameover"
	# Stand sichern, wenn man in der Stadt ankommt (zwischen den Einbrüchen)
	if screen == "town":
		Game.save_game()
	if _slots != null and is_instance_valid(_slots):
		_slots.queue_free()
		_slots = null
	if current:
		current.queue_free()
		current = null
	var node = null
	match screen:
		"title":
			node = preload("res://scripts/screens/title.gd").new()
			Game.play_music("town")
		"town":
			node = preload("res://scripts/screens/town.gd").new()
			Game.play_music("town")
		"organisation":
			node = preload("res://scripts/screens/organisation.gd").new()
			Game.play_music("town")
		"shop":
			node = preload("res://scripts/screens/shop.gd").new()
			Game.play_music("town")
		"planner":
			node = preload("res://scripts/screens/planner.gd").new()
			Game.play_music("planning")
		"execution":
			node = preload("res://scripts/screens/execution.gd").new()
			Game.play_music("heist")
		"slots":
			node = preload("res://scripts/screens/slots.gd").new()
			Game.play_music("town")
		"gameover":
			node = preload("res://scripts/screens/gameover.gd").new()
			Game.play_music("town")
		"result":
			node = preload("res://scripts/screens/result.gd").new()
			Game.play_music("town")
		_:
			push_error("Unbekannter Bildschirm: %s" % screen)
			return
	node.main = self
	node.args = args
	add_child(node)
	if node is Control:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current = node

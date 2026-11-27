class_name DebugPanel
extends RefCounted
## Entwicklerhilfe: Gebäude direkt auswählen und alles freischalten. Wird nur in Debug-Versionen eingeblendet
## (OS.is_debug_build), in den Release-Versionen erscheint es nicht.

const ZIELE := ["kiosk", "curiosity", "juwelier", "museum", "testhaus"]


## Das Spielobjekt (Autoload „Game“) über den Baum holen, weil statische Funktionen den Namen nicht sehen.
static func _g() -> Node:
	return Engine.get_main_loop().root.get_node("/root/Game")


## Bedienelemente für die Entwicklerzeile der Stadt.
static func zeile(main: Node) -> Array:
	var labels: Array = []
	for z in ZIELE:
		labels.append(Texte.t(GameData.TARGETS[z].name))
	var auswahl := {"id": "kiosk"}
	return [
		UI.dropdown(labels, 0, func(i: int): auswahl.id = ZIELE[i]),
		UI.button(Texte.t("debug.freischalten"), func(): alles_freischalten(); main.go("town"), 200),
		UI.button(Texte.t("debug.waehlen"), func(): gebaeude_starten(auswahl.id, main), 170),
		UI.button(Texte.t("debug.tag"), func(): _g().advance_hours(24.0); main.go("town"), 130),
		UI.button(Texte.t("debug.hitze"), func(): _g().heat = 0.0; main.go("town"), 130),
		UI.button(Texte.t("debug.ermittlung"), func(): ermittlung_voll(); main.go("town"), 170),
		UI.button(Texte.t("debug.leihwagen"), func(): _g().car_id = "limo"; main.go("town"), 150),
		UI.button(Texte.t("debug.reset"), func(): _g().reset(); main.go("town"), 130),
		UI.button(Texte.t("debug.screenshot"), screenshot, 150),
	]


## Ermittlung für alle Gebäude auf voll.
static func ermittlung_voll() -> void:
	for z in ZIELE:
		_g().intel[z] = 2


## Bild des gesamten Fensters speichern (Ordner user://screenshots).
static func screenshot() -> void:
	var ordner := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ordner))
	var zeit := Time.get_datetime_string_from_system().replace(":", "-")
	var pfad := "%s/debug_%s.png" % [ordner, zeit]
	Engine.get_main_loop().root.get_texture().get_image().save_png(ProjectSettings.globalize_path(pfad))
	print("Screenshot gespeichert: ", ProjectSettings.globalize_path(pfad))


## Alle Werkzeuge, Kleidung, Fahrzeuge und Gebäude freischalten; 100.000 € Geld.
static func alles_freischalten() -> void:
	_g().money = 100000
	for t in GameData.TOOLS.keys():
		_g().tools_owned[t] = true
	for g in GameData.GEAR.keys():
		_g().gear_owned[g] = true
	for c in GameData.CARS.keys():
		if c != "limo":
			_g().cars_owned[c] = true
	for z in ZIELE:
		_g().unlocked[z] = true
		_g().intel[z] = 2


## Ein Gebäude direkt planen: auswählen, freischalten, Ermittlung voll, dann zur Organisation.
static func gebaeude_starten(ziel: String, main: Node) -> void:
	_g().unlocked[ziel] = true
	_g().intel[ziel] = 2
	_g().target_id = ziel
	main.go("organisation")

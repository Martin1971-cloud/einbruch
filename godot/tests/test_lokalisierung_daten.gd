extends SceneTree
## Prüft die Gebäudedaten: jeder Text eines Gebäudes (Name, Info, Beschreibung, Dialog, Fakten, Bedarfsgründe)
## hat eine englische Fassung. In Englisch liefert Texte.d die Übersetzung, nicht den deutschen Text.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	var fehlend := []
	for id in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[id]
		for feld in ["name", "info", "desc", "dialog"]:
			if t.has(feld) and not Texte.TABELLE["en"].has(str(t[feld])):
				fehlend.append("%s.%s" % [id, feld])
		for f in t.get("facts", []):
			for x in f:
				# Fakt-Schlüssel wie "oeffnung" werden über ihren Anzeigenamen geprüft
				var txt := str(GameData.FAKTEN[x]) if typeof(x) == TYPE_STRING and GameData.FAKTEN.has(x) else str(x)
				if typeof(x) == TYPE_STRING and not Texte.TABELLE["en"].has(txt) and txt.length() > 2 and not txt.begins_with("res://"):
					fehlend.append("%s fakt %s" % [id, txt])
		for skill in t.get("bedarf", {}):
			var g := str(t.bedarf[skill].get("grund", ""))
			if g != "" and not Texte.TABELLE["en"].has(g):
				fehlend.append("%s bedarf %s" % [id, g])
	_check(fehlend.is_empty(), "Alle Gebäudetexte haben eine englische Fassung %s" % str(fehlend))
	Texte.sprache = "en"
	var kiosk: Dictionary = GameData.TARGETS.kiosk
	_check(Texte.t(kiosk.name) != kiosk.name, "In Englisch wird der Name des Kiosks übersetzt")
	Texte.sprache = "de"
	_check(Texte.t(kiosk.name) == Texte.TABELLE["de"][kiosk.name], "In Deutsch steht der deutsche Text aus der Tabelle")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

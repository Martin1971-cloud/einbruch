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
			if t.has(feld) and not TexteDaten.EN.has(str(t[feld])):
				fehlend.append("%s.%s" % [id, feld])
		for f in t.get("facts", []):
			for x in f:
				if typeof(x) == TYPE_STRING and not TexteDaten.EN.has(x) and x.length() > 2 and not x.begins_with("res://"):
					fehlend.append("%s fakt %s" % [id, x])
		for skill in t.get("bedarf", {}):
			var g := str(t.bedarf[skill].get("grund", ""))
			if g != "" and not TexteDaten.EN.has(g):
				fehlend.append("%s bedarf %s" % [id, g])
	_check(fehlend.is_empty(), "Alle Gebäudetexte haben eine englische Fassung %s" % str(fehlend))
	Texte.sprache = "en"
	var kiosk: Dictionary = GameData.TARGETS.kiosk
	_check(Texte.d(kiosk.name) != kiosk.name, "In Englisch wird der Name des Kiosks übersetzt")
	Texte.sprache = "de"
	_check(Texte.d(kiosk.name) == kiosk.name, "In Deutsch bleibt der Name unverändert")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

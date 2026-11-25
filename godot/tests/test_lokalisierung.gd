extends SceneTree
## Prüft die Texttabelle: Sprache wechseln, Rückfall auf Deutsch, fehlende Schlüssel bleiben sichtbar.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	_check(Texte.t("spielende.titel") == "Das Spiel ist vorbei", "Deutsch ist die Standardsprache")
	Texte.sprache = "en"
	_check(Texte.t("spielende.titel") == "Game over", "Englisch wird gewählt")
	_check(Texte.t("fehler.allgemein").begins_with("Etwas"), "Fehlt eine Übersetzung, kommt der deutsche Text")
	_check(Texte.t("gibt.es.nicht") == "gibt.es.nicht", "Unbekannter Schlüssel bleibt sichtbar")
	Texte.sprache = "de"
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

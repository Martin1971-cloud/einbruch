extends SceneTree
## Prüft: Protokoll und Ereignisse haben eine englische Fassung, und der Alarmgrund kommt strukturiert (sprachunabhängig).
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	var fehlend := []
	for k in Texte.TABELLE["de"]:
		if (k.begins_with("sim.") or k.begins_with("fail.") or k.begins_with("end.")) and not Texte.TABELLE["en"].has(k):
			fehlend.append(k)
	_check(fehlend.is_empty(), "Englisch hat alle Protokoll-Schlüssel (%s)" % str(fehlend))
	Texte.sprache = "en"
	var s := Texte.t("sim.alarm") % ["Microphone", 600.0]
	_check(s.begins_with("ALARM by Microphone"), "Englisches Protokoll: %s" % s)
	Texte.sprache = "de"
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

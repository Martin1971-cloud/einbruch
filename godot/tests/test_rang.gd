extends SceneTree
## Prüft den Rang nach der Gesamtauszahlung: Schwellen, Grenzfälle und Textschlüssel.
var _fails := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _initialize() -> void:
	_check(GameData.rang_key(0) == "rang.anfaenger", "Ohne Beute: Anfänger")
	_check(GameData.rang_key(49999) == "rang.anfaenger", "Knapp unter 50.000 €: noch Anfänger")
	_check(GameData.rang_key(50000) == "rang.einzelgaenger", "Ab 50.000 €: Einzelgänger")
	_check(GameData.rang_key(200000) == "rang.profi", "Ab 200.000 €: Profi")
	_check(GameData.rang_key(500000) == "rang.mr_big", "Ab 500.000 €: Mr. Big")
	_check(GameData.rang_key(9000000) == "rang.mr_big", "Darüber bleibt es bei Mr. Big")
	for k in ["rang.anfaenger", "rang.einzelgaenger", "rang.profi", "rang.mr_big"]:
		_check(Texte.t(k) != k, "Text vorhanden: %s" % k)
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

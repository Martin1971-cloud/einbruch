extends SceneTree
## Prüft den Hehler: jede Beute hat eine bekannte Kategorie, und die Auszahlung folgt dem gewählten Satz.
var _fails := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _initialize() -> void:
	for t in GameData.TARGETS.values():
		for l in t.get("loot", []):
			_check(GameData.KATEGORIEN.has(str(l.get("kat", ""))), "Beute %s hat eine Kategorie" % l.id)
	var beute := [[1000, "kunst"], [1000, "bargeld"]]
	_check(GameData.auszahlung(beute, "allround") == 1200, "Allround: 60 % von allem (1200)")
	_check(GameData.auszahlung(beute, "kunst") == 1200, "Kunsthändler: 80 % Kunst + 40 % Bargeld (1200)")
	_check(GameData.auszahlung([[1000, "kunst"]], "kunst") == 800, "Kunsthändler zahlt 80 % für Kunst")
	_check(GameData.auszahlung([[1000, "schmuck"]], "gold") == 800, "Goldschmied zahlt 80 % für Schmuck")
	_check(GameData.auszahlung([[1000, "metall"]], "gold") == 750, "Goldschmied zahlt 75 % für Metall")
	_check(GameData.auszahlung([[1000, "kunst"]], "gold") == 400, "Goldschmied zahlt 40 % für Kunst")
	_check(GameData.auszahlung([[1000, "kunst"]], "unbekannt") == 600, "Unbekannter Hehler fällt auf Allround zurück")
	_check(GameData.auszahlung([], "allround") == 0, "Ohne Beute keine Auszahlung")
	for id in GameData.HEHLER_ORDER:
		_check(Texte.t("hehler." + id) != "hehler." + id, "Name vorhanden: %s" % id)
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

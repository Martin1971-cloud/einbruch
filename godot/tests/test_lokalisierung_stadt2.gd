extends SceneTree
## Prüft die Stadt-Meldungen: Deutsch und Englisch, Hinweistexte, Platzhalter richtig gefüllt.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
	elif _frames == 4:
		var G = root.get_node("/root/Game")
		G.intel[_main.current._selected] = 0
		_main.current._on_think()
		_check(_main.current._msg.text == "Du denkst nach: Dir fehlt noch alles.", "Nachdenken: deutsche Meldung mit Platzhalter")
		Texte.sprache = "en"
		G.intel[_main.current._selected] = 0
		_main.current._on_think()
		_check(_main.current._msg.text == "You think: you still lack everything.", "Nachdenken: englische Meldung mit Platzhalter")
		var fehlend := []
		for k in Texte.TABELLE["de"]:
			if k.begins_with("stadt.") and not Texte.TABELLE["en"].has(k):
				fehlend.append(k)
		_check(fehlend.is_empty(), "Englisch hat alle Stadt-Schlüssel (%s)" % str(fehlend))
		Texte.sprache = "de"
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

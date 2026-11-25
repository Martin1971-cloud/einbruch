extends SceneTree
## Prüft das Lexikon: Einträge vorhanden, Suche filtert, L öffnet und schließt.
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
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		_check(GameData.LEXIKON.size() >= 15, "Lexikon hat mindestens 15 Einträge (%d)" % GameData.LEXIKON.size())
		var terms := []
		for e in GameData.LEXIKON:
			terms.append(str(e.term))
		for t in ["Lautstärke", "Treppe", "Schaufenster", "Etage"]:
			var found := false
			for x in terms:
				if str(x).to_lower().contains(t.to_lower()):
					found = true
			_check(found, "Begriff „%s“ vorhanden" % t)
		var lärm_im_text := false
		for e in GameData.LEXIKON:
			if str(e.text).to_lower().contains("lärm"):
				lärm_im_text = true
		_check(lärm_im_text, "„Lärm“ wird im Lexikon erklärt (Suche findet „Lautstärke“)")
		_main.open_lexikon()
	elif _frames == 6:
		var lex = _main._lexikon
		_check(lex != null and is_instance_valid(lex), "L öffnet das Lexikon")
		lex._search.text = "treppe"
		lex._fill()
	elif _frames == 7:
		var n := 0
		for c in _main._lexikon._list.get_children():
			if c is Label:
				n += 1
		_check(n == 2, "Suche „treppe“ zeigt genau einen Eintrag (Begriff + Text)")
		_main.open_lexikon()
	elif _frames == 9:
		_check(_main._lexikon == null, "Zweites Öffnen schließt das Lexikon")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

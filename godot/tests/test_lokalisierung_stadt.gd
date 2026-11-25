extends SceneTree
## Prüft: Titel und Stadt holen ihre Texte aus der Texttabelle, Englisch ist vollständig für die Schlüssel der Stadt.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _labels(node: Node, out: Array) -> Array:
	if node is Label or node is Button:
		out.append(node)
	for c in node.get_children():
		_labels(c, out)
	return out


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("title")
	elif _frames == 4:
		var de := _labels(_main.current, []).map(func(n): return str(n.text))
		_check(de.has("Neues Spiel") and de.has("Fortsetzen") and de.has("Spielstände"), "Titel zeigt die deutschen Texte")
		Texte.sprache = "en"
		_main.go("title")
	elif _frames == 6:
		var en := _labels(_main.current, []).map(func(n): return str(n.text))
		_check(en.has("New game") and en.has("Continue") and en.has("Save slots"), "Titel wechselt auf Englisch")
		Texte.sprache = "de"
		_main.go("town")
	elif _frames == 8:
		var de := _labels(_main.current, []).map(func(n): return str(n.text))
		_check(de.has("Stadt") and de.has("Organisation") and de.has("Fahndung"), "Stadt zeigt die deutschen Texte")
		var fehlend := []
		for k in Texte.TABELLE["de"]:
			if k.begins_with("nav.") or k.begins_with("stadt.") or k.begins_with("app.") or k.begins_with("menue.") or k.begins_with("ort."):
				if not Texte.TABELLE["en"].has(k):
					fehlend.append(k)
		_check(fehlend.is_empty(), "Englisch hat alle Schlüssel für Titel und Stadt (%s)" % str(fehlend))
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

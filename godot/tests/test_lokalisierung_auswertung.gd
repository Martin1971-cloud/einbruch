extends SceneTree
## Prüft: Auswertung zeigt Deutsch und Englisch, alle Ausführungs- und Auswertungs-Schlüssel sind übersetzt.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _texts(node: Node, out: Array) -> Array:
	if node is Label or node is Button:
		out.append(str(node.text))
	for c in node.get_children():
		_texts(c, out)
	return out


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		var ergebnis := {"status": "ENTKOMMEN", "payout": 1000, "heat": 5.0, "time": 60.0, "loot_taken": [], "loot_missed": []}
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("result", {"result": ergebnis})
	elif _frames == 4:
		var de := _texts(_main.current, [])
		_check(de.has("Entkommen") and de.has("Zurück in die Stadt"), "Auswertung zeigt die deutschen Texte")
		Texte.sprache = "en"
		_main.go("result", {"result": {"status": "ENTKOMMEN", "payout": 1000, "heat": 5.0, "time": 60.0, "loot_taken": [], "loot_missed": []}})
	elif _frames == 6:
		var en := _texts(_main.current, [])
		_check(en.has("Escaped") and en.has("Back to town"), "Auswertung wechselt auf Englisch")
		var fehlend := []
		for k in Texte.TABELLE["de"]:
			if (k.begins_with("ausf.") or k.begins_with("res.")) and not Texte.TABELLE["en"].has(k):
				fehlend.append(k)
		_check(fehlend.is_empty(), "Englisch hat alle Ausführungs- und Auswertungs-Schlüssel (%s)" % str(fehlend))
		Texte.sprache = "de"
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

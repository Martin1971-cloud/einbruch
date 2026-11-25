extends SceneTree
## Prüft: die Planung zeigt Deutsch und Englisch, und alle Planungs-Schlüssel haben eine englische Fassung.
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
		G.target_id = "kiosk"
		G.intel["kiosk"] = 2
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 4:
		var de := _texts(_main.current, [])
		_check(de.has("Speichern") and de.has("Laden") and de.has("Legende ▾"), "Planung zeigt die deutschen Texte")
		Texte.sprache = "en"
		_main.go("planner")
	elif _frames == 6:
		var en := _texts(_main.current, [])
		_check(en.has("Save") and en.has("Load") and en.has("Legend ▾"), "Planung wechselt auf Englisch")
		var fehlend := []
		for k in Texte.TABELLE["de"]:
			if k.begins_with("plan.") or k.begins_with("status.") or k.begins_with("laerm.") or k.begins_with("skill."):
				if not Texte.TABELLE["en"].has(k):
					fehlend.append(k)
		_check(fehlend.is_empty(), "Englisch hat alle Planungs-Schlüssel (%s)" % str(fehlend))
		Texte.sprache = "de"
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

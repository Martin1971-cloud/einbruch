extends SceneTree
## Prüft den Schalter „Einfache Darstellung“: speichern, laden und Standard aus.
var _fails := 0
var _frames := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		_check(not bool(G.settings.get("einfach", true)), "Einfache Darstellung ist standardmäßig aus")
		G.settings.einfach = true
		G.save_settings()
		G.settings.einfach = false
		G.load_settings()
		_check(bool(G.settings.einfach), "Einstellung wird gespeichert und geladen")
		G.settings.einfach = false
		G.save_settings()
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

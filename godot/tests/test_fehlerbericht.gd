extends SceneTree
## Prüft den Fehlerbericht: Meldung mit Hinweis erscheint, Fehler wird protokolliert.
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
		_main.show_error("Testfehler", "Nichts weiter tun.", "details")
	elif _frames == 4:
		var dialogs := 0
		for c in _main.get_children():
			if c is AcceptDialog:
				dialogs += 1
		_check(dialogs >= 1, "Der Spieler sieht eine Meldung")
		_check(FileAccess.file_exists(_main.FEHLER_LOG), "Der Fehler wird protokolliert")
		var txt := FileAccess.open(_main.FEHLER_LOG, FileAccess.READ).get_as_text()
		_check(txt.contains("Testfehler"), "Das Protokoll enthält die Meldung")
		DirAccess.remove_absolute(_main.FEHLER_LOG)
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

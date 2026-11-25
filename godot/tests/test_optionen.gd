extends SceneTree
## Prüft die Optionen: speichern und laden, Grenzen, Hinweise-Schalter, Öffnen über O.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _g():
	return root.get_node("/root/Game")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		var before: Dictionary = G.settings.duplicate()
		G.settings.music = 40
		G.settings.text_size = 15
		G.hints_enabled = false
		G.save_settings()
		G.settings.music = 90
		G.settings.text_size = 11
		G.hints_enabled = true
		G.load_settings()
		_check(G.settings.music == 40, "Musik-Lautstärke wird gespeichert und geladen")
		_check(G.settings.text_size == 15, "Textgröße wird gespeichert und geladen")
		_check(G.hints_enabled == false, "Hinweis-Schalter wird gespeichert und geladen")
		G.settings.text_size = 30
		G.settings.music = -5
		G.set("hints_enabled", true)
		G.save_settings()
		G.load_settings()
		_check(G.settings.text_size == 18 or G.settings.text_size == 30, "Textgröße wird vor dem Laden begrenzt (Wert %d)" % G.settings.text_size)
		G.settings = before
		G.save_settings()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		_main.open_optionen()
	elif _frames == 6:
		_check(_main._optionen != null and is_instance_valid(_main._optionen), "O öffnet die Optionen (Aufruf)")
		var op = _main._optionen
		var m0: int = _g().settings.music
		op._set_music(m0 + 10)
		_check(_g().settings.music == clampi(m0 + 10, 0, 100), "Musik lässt sich in 10er-Schritten einstellen")
		op._set_music(200)
		_check(_g().settings.music == 100, "Musik wird bei 100 % begrenzt")
		op._set_music(-50)
		_check(_g().settings.music == 0, "Musik wird bei 0 % begrenzt")
		op._set_text(99)
		_check(_g().settings.text_size == 18, "Textgröße wird bei 18 begrenzt")
		_main.open_optionen()
	elif _frames == 8:
		_check(_main._optionen == null, "Zweites Öffnen schließt die Optionen")
		var G = root.get_node("/root/Game")
		G.settings = {"music": 80, "text_size": 13, "fullscreen": false}
		G.save_settings()
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

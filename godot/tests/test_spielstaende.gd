extends SceneTree
## Prüft die Speicherplätze: speichern, laden, Sicherungskopie beim Überschreiben, löschen, Übersicht.
var _fails := 0
var _frames := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _g():
	return root.get_node("/root/Game")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	return false


func _run() -> void:
	var G = _g()
	G.new_game_in_slot(2)
	G.money = 12345
	G.save_game()
	_check(G.has_save(2), "Platz 2 ist belegt")
	_check(int(G.slot_info(2).geld) == 12345, "Übersicht zeigt das Geld des Platzes")
	_check(G.slot_info(3).leer, "Platz 3 ist leer")
	G.money = 999
	G.new_game_in_slot(2)
	_check(FileAccess.file_exists(G.slot_path(2) + ".bak"), "Überschreiben legt eine Sicherung an")
	_check(G.load_game(2) and G.money == Game.START_MONEY, "Laden von Platz 2 nach dem Neustart (Startgeld)")
	_check(G.last_slot() == 2, "Letzter Platz wird gemerkt")
	G.delete_slot(2)
	_check(not G.has_save(2) and FileAccess.file_exists(G.slot_path(2) + ".bak"), "Löschen entfernt den Platz, Sicherung bleibt")
	G.slot = 1
	G.reset()
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

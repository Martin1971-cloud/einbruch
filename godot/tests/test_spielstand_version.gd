extends SceneTree
## Prüft Versionsnummer, Löschen alter Stände, Sicherung bei beschädigter Datei und Fehlermeldungen.
var _fails := 0
var _frames := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _g():
	return root.get_node("/root/Game")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	return false


func _run() -> void:
	var G = _g()
	G.new_game_in_slot(3)
	G.save_game()
	var raw := FileAccess.open(G.slot_path(3), FileAccess.READ).get_as_text()
	var d = JSON.parse_string(raw)
	_check(int(d.get("version", 0)) == G.SAVE_VERSION, "Spielstand trägt die Versionsnummer")
	# Alter Stand ohne Version, Journal und Hinweise
	var old := {"money": 5000, "day": 3, "hour": 10.0, "heat": 0.0, "target_id": "kiosk", "team": [], "driver": {}, "stufe": {"kiosk": 1}, "unlocked": {"kiosk": true, "museum": false}}
	_write(G.slot_path(3), JSON.stringify(old))
	_check(not G.load_game(3) and not FileAccess.file_exists(G.slot_path(3)), "Alter Stand ohne Version wird gelöscht")
	_check(G.last_error.contains("älteren Version"), "Der Spieler erfährt, warum der Stand fehlt")
	# Beschädigte Datei mit Sicherung
	G.new_game_in_slot(3)
	G.money = 4321
	G.save_game()
	G.money = 1
	G.save_game()  # Sicherung enthält jetzt den Stand mit 4321
	_write(G.slot_path(3), "{kaputt")
	_check(G.load_game(3) and G.money == 4321, "Beschädigter Platz wird aus der Sicherung wiederhergestellt")
	_check(G.last_error.contains("wiederhergestellt"), "Der Spieler sieht, dass die Sicherung benutzt wurde")
	# Beschädigt ohne Sicherung
	G.delete_slot(3)
	DirAccess.remove_absolute(G.slot_path(3) + ".bak")
	_write(G.slot_path(3), "{kaputt")
	_check(not G.load_game(3) and G.last_error.contains("beschädigt"), "Ohne Sicherung gibt es eine verständliche Meldung")
	# Neuere Version
	_write(G.slot_path(3), JSON.stringify({"version": 99, "money": 1}))
	_check(not G.load_game(3) and G.last_error.contains("neueren Version"), "Neuere Version wird abgelehnt mit Hinweis")
	G.delete_slot(3)
	DirAccess.remove_absolute(G.slot_path(3) + ".bak")
	G.slot = 1
	G.reset()
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

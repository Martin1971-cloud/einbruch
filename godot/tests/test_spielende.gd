extends SceneTree
## Prüft das Spielende: Fahndung 100 und Pleite führen zum Bildschirm „Spielende“, ein neues Spiel setzt alles zurück.
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
		_g().reset()
		_check(_g().min_job_cost() > 0 and _g().min_job_cost() < 20000, "Mindestkosten eines Einbruchs (%d €)" % _g().min_job_cost())
		_g().money = 100
		_g().check_pleite()
		_check(_g().game_over and _g().game_over_reason == "pleite", "Pleite beendet das Spiel")
		_g().reset()
		_g().apply_result({"status": "GEFASST", "payout": 0, "time": 300.0, "heat": 150.0, "log": [], "segments": {}})
		_check(_g().game_over and _g().game_over_reason == "fahndung", "Fahndung 100 beendet das Spiel")
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
	elif _frames == 6:
		_check(_main.current.name != "" and _main.current is Control and _main.current.get_script() != null and str(_main.current.get_script().resource_path).contains("gameover"), "Stadt führt bei Spielende zum Bildschirm Spielende")
		_g().reset()
		_g().money = 100
		_g().check_pleite()
		_main.go("gameover")
		_main.current._new_game()
	elif _frames == 10:
		_check(not _g().game_over and _g().money > 0, "Neues Spiel setzt Geld und Spielende zurück")
		_check(_main.current.get_script() != null and str(_main.current.get_script().resource_path).contains("town"), "Neues Spiel führt in die Stadt")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

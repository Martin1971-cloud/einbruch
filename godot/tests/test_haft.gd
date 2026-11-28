extends SceneTree
## Prüft die Haft: Festgenommene sind zwei Tage gesperrt, fliegen aus dem Team und kommen danach frei.
var _fails := 0
var _frames := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _process(_d: float) -> bool:
	if _frames < 2:
		_frames += 1
		return false
	var G = root.get_node("/root/Game")
	G.reset()
	G.day = 3
	G.team = [{"id": "teo", "name": "Teo Vance"}, {"id": "rosa", "name": "Rosa Wendt"}]
	G.driver = {"id": "otto", "name": "Otto Brenner"}
	G.apply_result({"status": "GEFASST", "payout": 0, "heat": 0.0, "time": 60.0, "gefangen": ["teo", "otto"], "loot_taken": [], "loot_missed": []})
	_check(G.in_haft("teo"), "Festgenommene Person ist in Haft")
	_check(G.haft["teo"] == 3 + GameData.HAFT_TAGE, "Haft endet nach %d Tagen" % GameData.HAFT_TAGE)
	_check(not G.team.any(func(c): return c.id == "teo"), "Festgenommene fliegt aus dem Team")
	_check(G.driver.is_empty(), "Festgenommener Fahrer ist weg")
	_check(not G.in_haft("rosa"), "Nicht Festgenommene ist frei")
	G.day = 3 + GameData.HAFT_TAGE
	_check(not G.in_haft("teo"), "Nach der Haftzeit ist die Person wieder frei")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
	return true

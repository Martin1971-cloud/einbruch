extends SceneTree
## Planung speichern: gespeicherte Pläne bleiben über Speichern und Laden des Spielstands erhalten.
## Aufruf: godot --headless --path godot --script res://tests/test_plan_speichern.gd
var _frames := 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var G = root.get_node("/root/Game")
	G.reset()
	G.saved_plans = {"kiosk": [{"name": "Test", "team": ["teo"], "plans": {"teo": [{"t": "MOVE", "to": "Fluchtwagen"}]}}]}
	G.save_game()
	G.saved_plans = {}
	var ok: bool = G.load_game()
	var list: Array = G.saved_plans.get("kiosk", [])
	var good: bool = ok and list.size() == 1 and str(list[0].name) == "Test" and str(list[0].plans.teo[0].t) == "MOVE"
	print("  %s  Planung bleibt nach Speichern und Laden erhalten" % ("ok  " if good else "FAIL"))
	G.reset()
	quit(0 if good else 1)
	return true

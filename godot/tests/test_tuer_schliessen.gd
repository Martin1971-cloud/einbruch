extends SceneTree
## Offene Tür: „Tür schließen“ steht im Menü auch dann, wenn die Person weit weg steht.
## Aufruf: godot --headless --path . --script res://tests/test_tuer_schliessen.gd
var _f := 0
var _s := 0
var _main: Node
var _w := 0
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"
		G.target_id = "kiosk"
		G.unlocked["kiosk"] = true
		G.intel["kiosk"] = 2
		G.money = 100000
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		return false
	if _f < 6:
		return false
	if _s == 0:
		_main.current._on_look()
		_main.current._on_look()
		_main.go("organisation")
		_s = 1
		return false
	if _s == 1:
		var org = _main.current
		for c in GameData.CREW:
			org._selected[c.id] = c.id in ["teo", "otto"]
			org._gear_pick[c.id] = ["gloves", "sneakers"] if c.id == "teo" else []
		var G = root.get_node("/root/Game")
		G.tools_owned["lockpick"] = true
		G.gear_owned["gloves"] = true
		G.gear_owned["sneakers"] = true
		org._burgle["otto"] = true
		org._build_people()
		org._build_shop()
		org._refresh_summary()
		org._on_confirm()
		_s = 2
		_w = 0
		return false
	if _s == 2:
		_w += 1
		if _w < 10:
			return false
		var pl = _main.current
		pl.plans["teo"] = [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"}, {"t": "MOVE", "cell": [5, 4]}]
		pl._active = "teo"
		pl._on_changed()
		pl._on_preview()
		var e: Array = pl._object_entries(Vector2i(8, 7))
		var gefunden := false
		for x in e:
			var akt: Dictionary = x[1]
			if akt.get("t", "") == "CLOSE" and akt.has("approach"):
				gefunden = true
		_check(gefunden, "Tür schließen steht im Menü, auch wenn die Person weit weg steht (mit Schritt dorthin)")
		print("Fehler: %d" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

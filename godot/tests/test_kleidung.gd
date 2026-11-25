extends SceneTree
## Prüft: Kleidung wird im Laden gekauft, und die Organisation zeigt den Besitz an.
var _fails := 0
var _frames := 0
var _main: Node

func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("shop", {"kind": "laden"})
	elif _frames == 6:
		var shop = _main.current
		var G = root.get_node("/root/Game")
		shop.buy_gear("gloves")
		_check(G.gear_owned.has("gloves"), "Lederhandschuhe gekauft")
		_main.go("organisation")
	elif _frames == 10:
		var org = _main.current
		var found := false
		for f in org._shop_box.get_children():
			var txt := ""
			for ch in f.find_children("*", "Label", true, false):
				txt += ch.text
			if txt.contains("Lederhandschuhe"):
				found = true
		_check(found, "Organisation zeigt die Lederhandschuhe als Besitz")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

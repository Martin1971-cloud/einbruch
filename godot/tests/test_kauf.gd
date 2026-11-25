extends SceneTree
## Prüft: Kauf und Rückgabe von Werkzeug im Laden (Geld stimmt, Werkzeug ist da bzw. weg).
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
		var start: int = G.money
		G.stufe["kiosk"] = 1
		G.stufe["curiosity"] = 1  # Bohrmaschine ist ab Stufe 2 (zwei erfolgreiche Gebäude) zu haben
		shop.buy_tool("bohrmaschine")
		_check(G.tools_owned.has("bohrmaschine"), "Bohrmaschine ist gekauft")
		_check(G.money == start - 700, "Preis abgezogen (%d)" % G.money)
		shop.buy_tool("bohrmaschine")
		_check(not G.tools_owned.has("bohrmaschine"), "zweiter Klick gibt sie zurück")
		_check(G.money == start, "voller Preis zurück")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

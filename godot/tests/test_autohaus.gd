extends SceneTree
## Prüft: Sportwagen kaufen, Kosten der Organisation (Miete entfällt), Abholzeit der Simulation.
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
		_main.go("shop", {"kind": "autohaus"})
	elif _frames == 6:
		var shop = _main.current
		var G = root.get_node("/root/Game")
		var start: int = G.money
		var price: int = int(GameData.CARS.sport.price)
		G.money = maxi(G.money, price + 1000)  # Startgeld reicht nicht für den Sportwagen
		start = G.money
		G.stufe["kiosk"] = 1
		G.stufe["curiosity"] = 1  # zwei erfolgreiche Gebäude: Sportwagen freigeschaltet
		shop.buy_car("sport")
		_check(G.cars_owned.has("sport"), "Sportwagen ist gekauft")
		_check(G.money == start - price, "Kaufpreis abgezogen")
		_check(G.car_id == "sport", "Sportwagen ist der gewählte Wagen")
		var c := GameData.car_now("sport", 85.0)
		var l := GameData.car_now("limo", 85.0)
		_check(c.eta < l.eta, "Sportwagen kommt schneller (%.1f s gegen %.1f s)" % [c.eta, l.eta])
		_check(int(c.rent) == 0, "gekaufter Wagen hat keine Miete")
		shop.choose_car("limo")
		_check(G.car_id == "limo", "Limousine wieder gewählt")
		shop.choose_car("sport")
		_check(G.car_id == "sport", "gekaufter Wagen lässt sich wieder wählen")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

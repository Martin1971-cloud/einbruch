extends SceneTree
## Prüft die Sperre im Laden und Autohaus: gesperrte Artikel sind ausgegraut und mit Hinweis versehen.
var _fails := 0
var _frames := 0
var _main: Node


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _buttons(node: Node, out: Array) -> Array:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out


func _find(btns: Array, part: String) -> Button:
	for b in btns:
		if str((b as Button).text).contains(part):
			return b
	return null


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("shop", {"kind": "laden"})
	elif _frames == 6:
		var G = root.get_node("/root/Game")
		var btns := _buttons(_main.current, [])
		var glas := _find(btns, "Glasschneider")
		var axt := _find(btns, "Axt")
		var bohr := _find(btns, "Bohrmaschine")
		_check(glas != null and not glas.disabled, "Glasschneider ist von Anfang an kaufbar (Stufe 0)")
		_check(axt != null and axt.disabled and _label_has(_main.current, "Kiosk"), "Axt ist gesperrt mit Hinweis (Stufe 1)")
		_check(bohr != null and bohr.disabled and _label_has(_main.current, "Kuriosit"), "Bohrmaschine ist gesperrt mit Hinweis (Stufe 2)")
		G.stufe["kiosk"] = 1
		_main.current._build()
	elif _frames == 8:
		var btns := _buttons(_main.current, [])
		var axt := _find(btns, "Axt")
		_check(axt != null and not axt.disabled, "Nach dem Kiosk ist die Axt kaufbar")
		_check(_find(btns, "Bohrmaschine") != null and _find(btns, "Bohrmaschine").disabled, "Bohrmaschine bleibt bis zur Stufe 2 gesperrt")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false


## Gibt es ein Textfeld mit dem Text (Hinweis auf die Sperre in der Spalte „Verfügbar“)?
func _label_has(node: Node, text: String) -> bool:
	if node is Label and str(node.text).contains("gesperrt") and str(node.text).contains(text):
		return true
	for c in node.get_children():
		if _label_has(c, text):
			return true
	return false

extends SceneTree
## Prüft das Hinweissystem: jeder Hinweis erscheint nur einmal, Texte sind vorhanden, Planer zeigt die Hinweise.
var _fails := 0
var _frames := 0
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		for id in ["glas", "treppe", "laut"]:
			_check(GameData.HINTS.has(id) and str(GameData.HINTS[id].text) != "", "Text für Hinweis „%s“ vorhanden" % id)
		_check(G.hint_once("glas"), "Glas-Hinweis wird beim ersten Mal gezeigt")
		_check(not G.hint_once("glas"), "Glas-Hinweis kommt kein zweites Mal")
		G.hints_seen = {}
		G.hints_enabled = false
		_check(not G.hint_once("laut"), "Ausgeschaltete Hinweise erscheinen nicht")
		G.hints_enabled = true
		_check(G.hint_once("laut"), "Eingeschaltete Hinweise erscheinen wieder")
		G.hints_reset()
		_check(G.hint_once("laut"), "Zurücksetzen zeigt die Hinweise erneut")
		G.hints_seen = {}
		G.target_id = "kiosk"
		G.unlocked["kiosk"] = true
		G.intel["kiosk"] = 2
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
	elif _frames == 8:
		var G = root.get_node("/root/Game")
		# Klick aufs Schaufenster (Tür kind glas) im Kiosk
		_main.current._on_map_click(Vector2i(6, 4))
		_main.current._show_hint.call_deferred("treppe")
	elif _frames == 12:
		var G = root.get_node("/root/Game")
		_check(G.hints_seen.has("glas"), "Klick aufs Schaufenster löst den Glas-Hinweis aus")
		_check(G.hints_seen.has("treppe"), "Treppen-Hinweis wurde gezeigt (einmalig)")
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
	return false

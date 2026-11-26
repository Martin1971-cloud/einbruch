extends SceneTree
## Prüft die Objekt-IDs: Alle Ziele und Aktionen nutzen IDs, alte gespeicherte Planungen werden beim Laden umgeschrieben.
var _fails := 0
var _frames := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _initialize() -> void:
	# Jede Tür, das Panel und jeder Ort hat einen Anzeigenamen aus der Namenstabelle
	var ohne_name := []
	for zid in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[zid]
		for d in t.doors:
			if str(d.get("name", "")) == "" or not GameData.NAMEN.has(d.id):
				ohne_name.append("%s %s" % [zid, d.get("id", "?")])
		if t.has("panel") and not GameData.NAMEN.has(t.panel.id):
			ohne_name.append("%s panel" % zid)
		for pid in t.points:
			if not GameData.NAMEN.has(pid) and not GameData.ITEMS.has(pid):
				ohne_name.append("%s punkt %s" % [zid, pid])
	_check(ohne_name.is_empty(), "Alle Türen, Panel und Orte haben einen Namen %s" % str(ohne_name))
	_frames = 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var G = root.get_node("/root/Game")
	var f := FileAccess.open(G.slot_path(9), FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "money": 1000}))
	f.close()
	var ok: bool = G.load_game(9)
	_check(not ok and not FileAccess.file_exists(G.slot_path(9)), "Alter Spielstand wird gelöscht")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
	return false

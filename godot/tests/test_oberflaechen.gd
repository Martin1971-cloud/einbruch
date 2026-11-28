extends SceneTree
## Prüft die Oberflächen-Bezüge: jede verwendete ID ist in der Tabelle, die Datei existiert, Art passt.
var _fails := 0

func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1

func _initialize() -> void:
	for id in GameData.OBERFLAECHEN:
		var e: Dictionary = GameData.OBERFLAECHEN[id]
		_check(ResourceLoader.exists("res://assets/tiles/%s.png" % e.datei), "Datei vorhanden: %s" % id)
	for t in GameData.TARGETS.values():
		var ob: Dictionary = t.get("oberflaeche", {})
		var tid := str(t.get("id", ""))
		# Ohne Angabe gilt der Standard; ist eine Angabe da, muss sie in der Tabelle stehen und die richtige Art haben
		if ob.has("boden"):
			_check(GameData.OBERFLAECHEN.has(ob.boden) and GameData.OBERFLAECHEN[ob.boden].art == "boden", "%s: Boden gültig" % tid)
		if ob.has("wand"):
			_check(GameData.OBERFLAECHEN.has(ob.wand) and GameData.OBERFLAECHEN[ob.wand].art == "wand", "%s: Wand gültig" % tid)
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)


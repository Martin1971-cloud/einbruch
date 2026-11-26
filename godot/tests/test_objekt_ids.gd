extends SceneTree
## Prüft die Objekt-IDs: Alle Ziele und Aktionen nutzen IDs, alte gespeicherte Planungen werden beim Laden umgeschrieben.
var _fails := 0


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
	# Alte gespeicherte Planung wird auf IDs umgeschrieben
	var alt := {"kiosk": [{"name": "x", "plans": {"otto": [{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "MOVE", "to": "Fluchtwagen"}, {"t": "TAKE", "loot": "kasse"}, {"t": "MOVE", "to": "Außen vor dem Eingang"}]}}]}
	var neu: Dictionary = GameData.migriere_plaene(alt)
	var akt: Array = (neu["kiosk"][0]["plans"]["otto"] as Array)
	_check(akt[0].on == "eingangstuer" and akt[1].to == "fluchtwagen" and akt[3].to == "aussen_eingang", "Alte Namen werden in IDs umgeschrieben")
	_check(akt[2].loot == "kasse", "Beute-IDs bleiben unverändert")
	# Bereits neue Planungen bleiben unverändert
	var schon: Dictionary = GameData.migriere_plaene({"on": "eingangstuer", "to": "fluchtwagen"})
	_check(schon.on == "eingangstuer" and schon.to == "fluchtwagen", "Neue IDs bleiben unverändert")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

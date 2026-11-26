extends SceneTree
## Prüft, dass alle Inhaltstexte der Daten (Werkzeuge, Ausrüstung, Fahrzeuge, Beute, Ziele, Lexikon, Hinweise, Namen)
## als Schlüssel in texte.gd stehen, in Deutsch und Englisch. Ein fehlender Schlüssel würde roh im Spiel erscheinen.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _schluessel(werte: Array) -> Array:
	var fehlend := []
	for w in werte:
		var s := str(w)
		if s != "" and not Texte.TABELLE["de"].has(s):
			fehlend.append(s)
	return fehlend


func _initialize() -> void:
	var werte: Array = []
	for k in GameData.TOOLS: werte.append(GameData.TOOLS[k].name)
	for k in GameData.GEAR: werte.append(GameData.GEAR[k].name)
	for k in GameData.CARS: werte.append(GameData.CARS[k].name); werte.append(GameData.CARS[k].info)
	for k in GameData.ITEMS: werte.append(GameData.ITEMS[k].name)
	for c in GameData.CREW: werte.append(c.get("role", ""))
	for e in GameData.LEXIKON: werte.append(e.term); werte.append(e.text)
	for k in GameData.HINTS: werte.append(GameData.HINTS[k].title); werte.append(GameData.HINTS[k].text)
	for k in GameData.SKILL_INFO: werte.append(GameData.SKILL_INFO[k])
	for k in GameData.FLAG_NAMES: werte.append(GameData.FLAG_NAMES[k])
	for k in GameData.ACTION_NAMES: werte.append(GameData.ACTION_NAMES[k])
	for k in GameData.NAMEN: werte.append(GameData.NAMEN[k])
	for k in GameData.FAKTEN: werte.append(GameData.FAKTEN[k])
	for o in GameData.OTHER_PLACES: werte.append(o.name); werte.append(o.get("info", ""))
	for zid in GameData.TARGETS:
		var t: Dictionary = GameData.TARGETS[zid]
		for f in ["name", "info", "desc", "dialog"]:
			if t.has(f): werte.append(t[f])
		for d in t.doors: werte.append(d.name)
		for l in t.loot:
			werte.append(l.name)
			for p in l.get("parts", []): werte.append(p[0])
		for g in t.guards: werte.append(g.name)
		for s in t.sensors: werte.append(s.name)
		for r in t.get("rooms", []): werte.append(r.name)
		for fa in t.facts: werte.append(fa[1])
		for k in t.get("bedarf", {}): werte.append(t.bedarf[k].grund)
	var fehlend := _schluessel(werte)
	_check(fehlend.is_empty(), "Alle Inhaltsschlüssel sind in Deutsch vorhanden %s" % str(fehlend.slice(0, 5)))
	# Englisch: jeder Schlüssel hat eine Fassung
	var ohne_en := []
	for w in werte:
		var s := str(w)
		if s != "" and Texte.TABELLE["de"].has(s) and not Texte.TABELLE["en"].has(s):
			ohne_en.append(s)
	_check(ohne_en.is_empty(), "Alle Inhaltsschlüssel haben eine englische Fassung %s" % str(ohne_en.slice(0, 5)))
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

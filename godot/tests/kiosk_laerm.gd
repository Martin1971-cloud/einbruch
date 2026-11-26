extends SceneTree
## Lautstärke am Kiosk-Plan: je Aktion und Spitze, mit Ausrüstung aus dem Spiel und ohne Kleidung.
func _init() -> void:
	var plan := [
		{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}, {"t": "OPEN", "on": "Eingangstür"},
		{"t": "MOVE", "cell": [8, 4]}, {"t": "MOVE", "cell": [9, 3]}, {"t": "TOOL", "tool": "lockpick", "on": "Kassenlade"}, {"t": "OPEN", "on": "Kassenlade"}, {"t": "TAKE", "loot": "kasse"},
		{"t": "CALL_CAR"}, {"t": "MOVE", "to": "Fluchtwagen"},
	]
	for variant in ["ohne Kleidung", "Brecheisen mit Kleidung"]:
		var team := []
		for c in GameData.CREW:
			if c.id == "teo":
				var d: Dictionary = c.duplicate(true)
				d["gear"] = [] if variant == "ohne Kleidung" else ["gloves", "sneakers"]
				team.append(d)
		var p := plan.duplicate(true)
		if variant != "ohne Kleidung":
			p[1] = {"t": "TOOL", "tool": "crowbar", "on": "Eingangstür"}
		var s := Sim.create(GameData.TARGETS.kiosk, team, {"teo": p, "otto": [{"t": "MOVE", "to": "Fluchtwagen"}]}, GameData.car_now("limo", 85.0))
		var n := 0
		while s.status == "RUNNING" and n < 9000:
			s.step(Sim.DT)
			n += 1
		print("== %s ==  Ergebnis %s, Spitze %d dB, Grenze %d dB" % [variant, s.status, int(s.peak_loud), int(s.max_volume)])
		for c in s.crew:
			if c.id == "teo":
				for sg in c.segments:
					print("   %-6s %5.0f–%5.0f s  Lärm %5.1f dB" % [sg.t, float(sg.start), float(sg.end), float(sg.loud)])
	quit(0)

extends SceneTree
## Prüft Budget, Lernen nach Erfolg und die Sicherungsstufe.
## Aufruf: godot --headless --path godot --script res://tests/test_lernen.gd
var _frames := 0
var G: Node
var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + label)
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		print("Budget:")
		for c in GameData.CREW:
			var total := 0
			for k in c.skills:
				total += int(c.skills[k])
			_check(total == GameData.BUDGET, "%s hat %d Punkte" % [c.name, total])
		print("Lernen:")
		var teo_before := int(G.skills_of("teo").TECH)
		G.team = [{"id": "teo", "name": "Teodor Vance"}]
		G.driver = {"id": "greta", "name": "Greta Lind"}
		G.target_id = "museum"
		G.apply_result({"status": "ENTKOMMEN", "payout": 0, "heat": 0, "time": 60, "used": {"teo": {"TECH": 6, "FORCE": 2}}})
		var sk: Dictionary = G.skills_of("teo")
		var gained := (int(sk.TECH) - teo_before) + (int(sk.FORCE) - 40)
		_check(gained == 10, "Erfolg bringt 10 Punkte (gemessen %d)" % gained)
		_check(int(sk.TECH) - teo_before > int(sk.FORCE) - 40, "Technik (meist genutzt) wächst am stärksten")
		_check(G.stufe_of("museum") == 1, "Sicherungsstufe steigt auf 1")
		print("Sicherung:")
		var t1: Dictionary = GameData.target_now(1)
		_check(int(t1.bedarf.FORCE.wert) == 65, "Gewalt-Bedarf steigt auf 65")
		_check(float(t1.doors[0].cplx) > float(GameData.TARGETS.museum.doors[0].cplx), "Schlösser schwerer")
		print("Obergrenze:")
		G.apply_result({"status": "ENTKOMMEN", "payout": 0, "heat": 0, "time": 60, "used": {"rosa": {"FORCE": 9}}})
		G.team = [{"id": "rosa", "name": "Rosa Wendt"}]
		G.apply_result({"status": "ENTKOMMEN", "payout": 0, "heat": 0, "time": 60, "used": {"rosa": {"FORCE": 9}}})
		_check(int(G.skills_of("rosa").FORCE) <= GameData.SKILL_CAP, "Gewalt von Rosa bleibt bei höchstens 100")
		print("Ergebnis: %d Fehler" % _fails)
		quit(_fails)
		return true
	return false

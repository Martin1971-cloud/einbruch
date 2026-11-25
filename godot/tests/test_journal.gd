extends SceneTree
## Prüft das Journal: ein Eintrag je Einbruch mit Kosten, Gewinn, Fehlern und Alarm; Speichern im Spielstand.
var _fails := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


var _frames := 0


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var G = root.get_node("/root/Game")
	G.reset()
	var res := {
		"status": "ENTKOMMEN", "payout": 12000, "time": 71.0, "loot_taken": ["Kassenlade"],
		"log": ["[00:10] ALARM durch Mikrofon Verkauf. Polizei in 600 s."], "alarm_source": "Mikrofon Verkauf",
		"segments": {"teo": [{"fail": "Tür zu"}, {"fail": ""}], "otto": []},
	}
	G.apply_result(res)
	_check(G.journal.size() == 1, "Ein Einbruch ergibt einen Journal-Eintrag")
	var e: Dictionary = G.journal[0]
	_check(int(e.auszahlung) == 12000, "Auszahlung steht im Eintrag")
	_check(int(e.kosten) == G.team_fee_total() + int(GameData.car_now(G.car_id, 85.0).rent) + (0 if G.driver.is_empty() or G.team.any(func(c): return c.id == G.driver.id) else int(G.driver.fee)), "Kosten: Honorare und Wagenmiete")
	_check(int(e.gewinn) == 12000 - int(e.kosten), "Gewinn ist Auszahlung minus Kosten")
	_check(int(e.fehler) == 1 and str(e.fehler_text[0]) == "Tür zu", "Fehlgeschlagene Aktion wird gezählt und genannt")
	_check(str(e.alarm) == "Mikrofon Verkauf", "Alarmquelle wird aus dem Protokoll übernommen")
	_check(str(e.beute[0]) == "Kassenlade", "Beute steht im Eintrag")
	G.apply_result(res)
	_check(G.journal.size() == 2, "Jeder Einbruch wird eigener Eintrag")
	G.save_game()
	G.journal = []
	G.load_game()
	_check(G.journal.size() == 2, "Journal bleibt im Spielstand erhalten")
	G.reset()
	_check(G.journal.is_empty(), "Neues Spiel leert das Journal")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)
	return false

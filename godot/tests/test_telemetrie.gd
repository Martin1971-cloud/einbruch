extends SceneTree
## Prüft die lokale Telemetrie: nur wenn eingeschaltet, eine Zeile je Einbruch, keine Namen.
var _fails := 0
var _frames := 0


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_run()
	return false


func _run() -> void:
	var G = root.get_node("/root/Game")
	var cfg := ConfigFile.new()
	cfg.load(G.SETTINGS_PATH)
	cfg.set_value("telemetrie", "an", false)
	cfg.save(G.SETTINGS_PATH)
	Telemetrie.clear()
	G.reset()
	G.apply_result({"status": "ENTKOMMEN", "payout": 1000, "time": 60.0, "log": [], "segments": {}})
	_check(Telemetrie.export_text() == "", "Ohne Einschalten wird nichts aufgezeichnet")
	cfg.set_value("telemetrie", "an", true)
	cfg.save(G.SETTINGS_PATH)
	G.apply_result({"status": "GEFASST", "payout": 0, "time": 300.0, "log": ["[01:00] ALARM durch Mikrofon Verkauf. Polizei in 600 s."], "alarm_source": "Mikrofon Verkauf", "segments": {}})
	var lines := Telemetrie.export_text().strip_edges().split("\n")
	_check(lines.size() == 1, "Eingeschaltet: eine Zeile je Einbruch")
	var d = JSON.parse_string(lines[0])
	_check(typeof(d) == TYPE_DICTIONARY and str(d.status) == "GEFASST" and str(d.alarm) == "Mikrofon Verkauf", "Zeile enthält Ergebnis und Alarmquelle")
	_check(not lines[0].contains("name") and not lines[0].contains("Teodor"), "Keine Namen in der Telemetrie")
	cfg.set_value("telemetrie", "an", false)
	cfg.save(G.SETTINGS_PATH)
	Telemetrie.clear()
	G.reset()
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

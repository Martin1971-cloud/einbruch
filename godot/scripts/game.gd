extends Node
## Globaler Spielzustand (Autoload "Game").

const START_MONEY := 30000
const START_HOUR := 19.0

var money := START_MONEY
var day := 1
var hour := START_HOUR
var heat := 0.0
var intel := {}          # target_id -> Stufe 0..2
## Woher die Informationen stammen: target_id -> {"look": 0..2 (Umsehen), "inf": bool (Informant)}
var ermittlung_quelle := {}
var tools_owned := {}    # tool_id -> true
var gear_owned := {}     # gear_id -> true
var cars_owned := {}     # car_id -> true (gekaufte Fahrzeuge)
var car_id := "limo"     # gewähltes Fahrzeug für den nächsten Einbruch
# Auswahl in der Organisation (Team, Einbrechen, Kleidung). Bleibt erhalten, wenn man zwischendurch die Stadt oder den Laden besucht.
var org_selected := {}
var org_burgle := {}
var org_gear_pick := {}
var team: Array = []     # [{id, name, skills, start, gear}]
var driver: Dictionary = {}  # gewählter Fahrer (Pflicht)
var roster := {}          # id -> aktuelle Fähigkeiten (wachsen mit Erfolgen)
var stufe := {}           # Ziel -> Sicherungsstufe (steigt nach jedem Erfolg)
var target_id := "kiosk"  # gewähltes Ziel
var unlocked := {"kiosk": true, "museum": false, "curiosity": false, "juwelier": false}  # Ziele, die spielbar sind
var last_result: Dictionary = {}
var game_over := false
var game_over_reason := ""  # "fahndung" oder "pleite" (leer = läuft)

var _music: AudioStreamPlayer
var _music_name := ""


func _input(event: InputEvent) -> void:
	# F11 wechselt zwischen Fenster und Vollbild
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	load_settings()
	reset()


const SLOTS := 3  # Speicherplätze
const SAVE_VERSION := 2  # 1 = bisheriger Stand ohne Journal und Hinweise, 2 = aktuell
var last_error := ""  # verständliche Meldung für den Spieler (leer = keine)
const SAVE_PATH := "user://einbruch_spielstand.json"  # alter einzelner Spielstand: wird auf Platz 1 übernommen
var slot := 1  # aktueller Speicherplatz (1 bis 3)
const LAST_SLOT_KEY := "letzter_platz"
## Gespeicherte Planungen je Ziel: Ziel-Id -> Liste von {name, team, plans}
var saved_plans := {}


## Spielstand speichern (in der Stadt, zwischen den Einbrüchen). Fehler werden still übergangen.
func save_game() -> void:
	var data := {
		"money": money, "day": day, "hour": hour, "heat": heat,
		"intel": intel, "ermittlung_quelle": ermittlung_quelle, "tools_owned": tools_owned, "gear_owned": gear_owned,
		"cars_owned": cars_owned, "car_id": car_id,
		"team": team, "driver": driver, "roster": roster, "stufe": stufe,
		"target_id": target_id, "unlocked": unlocked, "game_over": game_over,
		"saved_plans": saved_plans, "hints_seen": hints_seen, "hints_enabled": hints_enabled, "journal": journal, "game_over_reason": game_over_reason,
		"version": SAVE_VERSION,
	}
	# Sicherungskopie vor dem Überschreiben: der vorige Stand bleibt als .bak erhalten
	var p := slot_path(slot)
	if FileAccess.file_exists(p):
		DirAccess.copy_absolute(p, p + ".bak")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
	_remember_slot()


func slot_path(n: int) -> String:
	return "user://einbruch_spielstand_%d.json" % n


func has_save(n: int = -1) -> bool:
	var k := slot if n < 0 else n
	if k == 1 and not FileAccess.file_exists(slot_path(1)) and FileAccess.file_exists(SAVE_PATH):
		# alter Spielstand: auf Platz 1 übernehmen
		DirAccess.copy_absolute(SAVE_PATH, slot_path(1))
	return FileAccess.file_exists(slot_path(k))


## Übersicht eines Platzes für die Auswahl: leer oder Tag, Geld, Einbrüche.
func slot_info(n: int) -> Dictionary:
	if not has_save(n):
		return {"leer": true}
	var f := FileAccess.open(slot_path(n), FileAccess.READ)
	if f == null:
		return {"leer": true}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"leer": true, "defekt": true}
	return {"leer": false, "tag": int(parsed.get("day", 1)), "geld": int(parsed.get("money", 0)), "einbrueche": (parsed.get("journal", []) as Array).size(), "pleite": str(parsed.get("game_over_reason", ""))}


## Ein Platz löschen (mit Sicherungskopie).
func delete_slot(n: int) -> void:
	var p := slot_path(n)
	if FileAccess.file_exists(p):
		DirAccess.copy_absolute(p, p + ".bak")
		DirAccess.remove_absolute(p)


## Den zuletzt benutzten Platz merken (für „Fortsetzen“).
func _remember_slot() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("spiel", LAST_SLOT_KEY, slot)
	cfg.save(SETTINGS_PATH)


func last_slot() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return clampi(int(cfg.get_value("spiel", LAST_SLOT_KEY, 1)), 1, SLOTS)
	return 1


## Spielstand laden. Gibt false zurück, wenn keiner da ist oder er nicht lesbar ist.
func load_game(n: int = -1) -> bool:
	if n > 0:
		slot = n
	last_error = ""
	if not has_save():
		return false
	var parsed = _read_save(slot_path(slot))
	if parsed == null:
		# Beschädigt: die Sicherung (.bak) versuchen
		var bak = _read_save(slot_path(slot) + ".bak")
		if bak == null:
			last_error = Texte.t("game.beschaedigt_ohne_sicherung") % slot
			return false
		DirAccess.copy_absolute(slot_path(slot) + ".bak", slot_path(slot))
		parsed = bak
		last_error = Texte.t("game.wiederhergestellt") % slot
	var v := int(parsed.get("version", 1))
	if v > SAVE_VERSION:
		last_error = Texte.t("game.neuere_version") % slot
		return false
	parsed = migrate(parsed)
	_apply_save(parsed)
	return true


## Lesen einer Spielstand-Datei. null, wenn sie fehlt, nicht lesbar oder kein Spielstand ist.
func _read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


## Migration alter Stände auf die aktuelle Version. Fehlende Felder bekommen ihren Startwert.
func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		d["journal"] = []
		d["hints_seen"] = {}
		d["hints_enabled"] = true
		d["game_over_reason"] = ""
	d["version"] = SAVE_VERSION
	return d


func _apply_save(parsed: Dictionary) -> void:
	money = int(parsed.get("money", START_MONEY))
	day = int(parsed.get("day", 1))
	hour = float(parsed.get("hour", START_HOUR))
	heat = float(parsed.get("heat", 0.0))
	intel = parsed.get("intel", intel)
	ermittlung_quelle = parsed.get("ermittlung_quelle", {})
	tools_owned = parsed.get("tools_owned", {})
	gear_owned = parsed.get("gear_owned", {"none": true})
	cars_owned = parsed.get("cars_owned", {})
	car_id = str(parsed.get("car_id", "limo"))
	team = parsed.get("team", [])
	driver = parsed.get("driver", {})
	roster = parsed.get("roster", roster)
	stufe = parsed.get("stufe", {"kiosk": 0, "museum": 0})
	target_id = str(parsed.get("target_id", "kiosk"))
	unlocked = parsed.get("unlocked", {"kiosk": true, "museum": false})
	game_over = bool(parsed.get("game_over", false))
	saved_plans = parsed.get("saved_plans", {})
	hints_seen = parsed.get("hints_seen", {})
	hints_enabled = bool(parsed.get("hints_enabled", true))
	journal = parsed.get("journal", [])
	game_over_reason = str(parsed.get("game_over_reason", ""))


func reset() -> void:
	saved_plans = {}
	money = START_MONEY
	day = 1
	hour = START_HOUR
	heat = 0.0
	intel = {}
	ermittlung_quelle = {}
	for t in GameData.TARGETS:
		intel[t] = 0
		ermittlung_quelle[t] = {"look": 0, "inf": false}
	tools_owned = {}
	gear_owned = {"none": true}
	cars_owned = {}
	car_id = "limo"
	org_selected = {}
	org_burgle = {}
	org_gear_pick = {}
	team = []
	driver = {}
	roster = {}
	for c in GameData.CREW:
		roster[c.id] = c.skills.duplicate(true)
	stufe = {"kiosk": 0, "museum": 0}
	target_id = "kiosk"
	unlocked = {"kiosk": true, "museum": false}
	hints_seen = {}
	hints_enabled = true
	journal = []
	last_result = {}
	game_over = false
	game_over_reason = ""


func clock_text() -> String:
	return "%02d:%02d" % [int(hour) % 24, int(fmod(hour, 1.0) * 60.0)]


func advance_hours(h: float) -> void:
	hour += h
	while hour >= 24.0:
		hour -= 24.0
		day += 1


func sleep_until_morning() -> void:
	# Bis 08:00 am nächsten Morgen
	var target := 8.0
	if hour < 8.0:
		hour = target
	else:
		day += 1
		hour = target


func skills_of(id: String) -> Dictionary:
	if roster.has(id):
		return roster[id]
	return {}


## Hinweise: jeder Hinweis erscheint nur einmal. Gibt true zurück, wenn er jetzt gezeigt werden soll.
var hints_seen := {}
var hints_enabled := true  # Schalter im Lexikon: aus = keine Hinweise mehr


func hint_once(id: String) -> bool:
	if not hints_enabled or hints_seen.has(id):
		return false
	hints_seen[id] = true
	return true


## Neues Spiel auf einem Platz: der Platz wird überschrieben (Bestätigung kommt vorher vom Bildschirm).
func new_game_in_slot(n: int) -> void:
	slot = n
	reset()
	save_game()


## Alle Hinweise wieder zeigen (Lexikon).
func hints_reset() -> void:
	hints_seen = {}
	save_game()


func stufe_of(target_id: String) -> int:
	return int(stufe.get(target_id, 0))


## Quelle der Ermittlung eines Gebäudes (fehlt sie, etwa in alten Ständen: nichts ermittelt).
func quelle_of(target_id: String) -> Dictionary:
	if ermittlung_quelle.has(target_id):
		return ermittlung_quelle[target_id]
	# alter Stand ohne Quelle: bisherige Stufe als Umsehen werten
	return {"look": int(intel.get(target_id, 0)), "inf": false}


## Schlüssel des Ermittlungstextes nach Quellen (Umsehen, Informant). Stadt und Planung nutzen denselben Text.
func ermittlung_key(target_id: String) -> String:
	var q := quelle_of(target_id)
	var n := int(q.get("look", 0))
	var inf := bool(q.get("inf", false))
	if inf and n >= 2:
		return "stadt.erm_beide"
	if inf and n == 1:
		return "stadt.erm_inf_look1"
	if inf:
		return "stadt.erm_inf"
	if n >= 2:
		return "stadt.erm_look2"
	if n == 1:
		return "stadt.erm_look1"
	return "stadt.ermittlung_0"


## Stufe für Loot-Spanne: der Informant liefert den genauen Beutewert, Umsehen nur eine Spanne.
func intel_level(target_id: String) -> int:
	var q := quelle_of(target_id)
	if bool(q.get("inf", false)):
		return 2
	return 1 if int(q.get("look", 0)) >= 1 else 0


## Anzahl erfolgreich abgeschlossener Gebäude (Stufe für Werkzeuge und Autos).
func stage() -> int:
	var n := 0
	for t in GameData.ORDER:
		if stufe_of(t) > 0:
			n += 1
	return n


## Lernen: Jede genutzte Fähigkeit wächst. Pro Erfolg 10 Punkte, verteilt nach
## Nutzung (wer eine Fähigkeit oft einsetzt, verbessert sie). Höchstens 100 je Fähigkeit.
func _grow(id: String, usage: Dictionary, points := 10) -> void:
	if not roster.has(id):
		return
	var sk: Dictionary = roster[id]
	# Nur Fähigkeiten, die die Person hat und die noch nicht am Maximum sind
	var cand := {}
	var total := 0
	for k in usage:
		if sk.has(k) and int(sk[k]) < GameData.SKILL_CAP and int(usage[k]) > 0:
			cand[k] = int(usage[k])
			total += int(usage[k])
	if total == 0:
		return
	var given := 0
	var top := ""
	for k in cand:
		var add := int(points * cand[k] / total)
		sk[k] = mini(GameData.SKILL_CAP, int(sk[k]) + add)
		given += add
		if top == "" or cand[k] > cand[top]:
			top = k
	# Rest (Rundung) an die meistgenutzte Fähigkeit
	var rest := points - given
	if rest > 0:
		sk[top] = mini(GameData.SKILL_CAP, int(sk[top]) + rest)


## Rückblick: jeder Einbruch wird im Journal festgehalten (neueste zuletzt, höchstens 200).
var journal: Array = []


func journal_add(res: Dictionary) -> void:
	var fails: Array = []
	for id in res.get("segments", {}):
		for sg in res.segments[id]:
			if str(sg.get("fail", "")) != "":
				fails.append(str(sg.fail))
	var alarm_src := str(res.get("alarm_source", ""))
	var driver_extra := 0
	if not driver.is_empty() and not team.any(func(c): return c.id == driver.get("id", "")):
		driver_extra = int(driver.get("fee", 0))
	var rent := int(GameData.car_now(car_id, 85.0).get("rent", 0))
	var cost := team_fee_total() + driver_extra + rent
	var payout_v := int(res.get("payout", 0))
	journal.append({
		"tag": day, "stunde": hour, "ziel": GameData.TARGETS[target_id].name,
		"status": str(res.get("status", "")), "auszahlung": payout_v, "kosten": cost, "gewinn": payout_v - cost,
		"dauer": int(res.get("time", 0.0)), "beute": res.get("loot_taken", []), "fehler": fails.size(),
		"fehler_text": fails.slice(0, 3), "alarm": alarm_src,
	})
	while journal.size() > 200:
		journal.pop_front()
	# Telemetrie (nur wenn eingeschaltet): wo wurde abgebrochen, wie viele Personen, Ergebnis
	var last_act := ""
	for id in res.get("segments", {}):
		for sg in res.segments[id]:
			last_act = str(sg.get("t", ""))
	Telemetrie.record({"typ": "einbruch", "ziel": target_id, "stufe": stage(), "team": team.size() + (0 if driver.is_empty() or team.any(func(c): return c.id == driver.get("id", "")) else 1),
		"status": str(res.get("status", "")), "auszahlung": payout_v, "kosten": cost, "dauer": int(res.get("time", 0.0)),
		"alarm": alarm_src, "fehler": fails.size(), "letzte_aktion": last_act, "spitze_db": int(res.get("peak_loud", 0.0))})


func apply_result(res: Dictionary) -> void:
	journal_add(res)
	last_result = res
	if str(res.get("status", "")).begins_with("ENTKOMMEN"):
		stufe[target_id] = stufe_of(target_id) + 1
		if target_id == "kiosk":
			unlocked["curiosity"] = true  # kleine Läden zuerst, danach Museen
		if target_id == "curiosity":
			unlocked["juwelier"] = true  # Gebäude 3: Alarm
		if target_id == "juwelier":
			unlocked["museum"] = true  # Gebäude 4
		var used: Dictionary = res.get("used", {})
		for c in team:
			_grow(c.id, used.get(c.id, {}))
		if not driver.is_empty():
			_grow(driver.id, {"FAHREN": 1})
	money += int(res.get("payout", 0))
	heat = clampf(heat + float(res.get("heat", 0.0)), 0.0, 100.0)
	if heat >= 100.0:
		_end_game("fahndung")
	advance_hours(float(res.get("time", 0.0)) / 3600.0 + 1.0)


func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var path := "res://audio/%s.ogg" % track
	if not ResourceLoader.exists(path):
		_music.stop()
		return
	var stream: AudioStream = load(path)
	# Ogg Vorbis: Schleife über die Import-Einstellung (loop) der Datei
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.play()


func team_fee_total() -> int:
	var total := 0
	for c in team:
		total += int(c.get("fee", 0))
	return total


## Optionen des Spielers: eigene Datei, unabhängig vom Spielstand.
const SETTINGS_PATH := "user://einbruch_optionen.cfg"
var settings := {"music": 80, "text_size": 13, "fullscreen": false, "einfach": false}


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		settings.music = clampi(int(cfg.get_value("ton", "musik", 80)), 0, 100)
		settings.text_size = clampi(int(cfg.get_value("anzeige", "textgroesse", 13)), 10, 18)
		settings.fullscreen = bool(cfg.get_value("anzeige", "vollbild", false))
		settings.einfach = bool(cfg.get_value("anzeige", "einfach", false))
		hints_enabled = bool(cfg.get_value("hinweise", "an", true))
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ton", "musik", settings.music)
	cfg.set_value("anzeige", "textgroesse", settings.text_size)
	cfg.set_value("anzeige", "vollbild", settings.fullscreen)
	cfg.set_value("anzeige", "einfach", bool(settings.get("einfach", false)))
	cfg.set_value("hinweise", "an", hints_enabled)
	cfg.save(SETTINGS_PATH)


## Einstellungen wirksam machen: Musik-Lautstärke und Vollbild.
func apply_settings() -> void:
	if _music != null:
		_music.volume_db = -80.0 if settings.music <= 0 else linear_to_db(float(settings.music) / 100.0) - 6.0
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Spielende: Fahndung zu hoch, oder Pleite (zu wenig Geld für einen Einbruch mit dem günstigsten Team).
func min_job_cost() -> int:
	var cheapest_crew := 999999
	var cheapest_driver := 999999
	for c in GameData.CREW:
		if c.get("driver", false):
			cheapest_driver = mini(cheapest_driver, int(c.fee))
		else:
			cheapest_crew = mini(cheapest_crew, int(c.fee))
	return cheapest_crew + cheapest_driver + int(GameData.CARS.limo.rent)


func check_pleite() -> void:
	if not game_over and money < min_job_cost():
		_end_game("pleite")


func _end_game(reason: String) -> void:
	if game_over:
		return
	game_over = true
	game_over_reason = reason
	save_game()

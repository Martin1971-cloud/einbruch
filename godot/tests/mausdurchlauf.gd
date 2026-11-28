extends SceneTree
## Durchlauf nur mit der Maus: echte Mausereignisse auf Schaltflächen, Stadtkarte, Grundriss und Menü.
## Aufruf: xvfb-run ... --script res://tests/mausdurchlauf.gd            (Deutsch)
##         xvfb-run ... --script res://tests/mausdurchlauf.gd -- en     (Englisch, Ordner en/)
## Bilder: Godot-Benutzerordner unter mausdurchlauf/. Die Ausgabe nennt jeden Schritt.
const OUT := "user://mausdurchlauf/"
var _f := 0
var _next := 2
var _schritte: Array = []   # Ablauf: je Schritt ein Name und ein Aufruf
var _s := 0
var _en := false
var _main: Node
var _G: Node
var _plan: Array = []       # Planungsschritte: [Zelle, Auswahlbedingung, Nachgehen]
var _warte := 0
var _plan_laeuft := false
var _versuche := 0
var _letzter_s := -1       # letzter Schritt, der vorangekommen ist
var _letzter_f := 0        # Bildnummer, bei der er vorangekommen ist
const MAX_WARTEN := 3600   # Bilder ohne Fortschritt, dann Abbruch mit Meldung


func _snap(name: String) -> void:
	var ordner := ProjectSettings.globalize_path(OUT + ("en/" if _en else ""))
	DirAccess.make_dir_recursive_absolute(ordner)
	root.get_texture().get_image().save_png(ordner + "/" + name + ".png")
	print("Bild: %s" % name)


## Alle sichtbaren Knoten einer Klasse unter n.
func _finde(n: Node, klasse: String, out: Array) -> void:
	if n.get_class() == klasse or (n.get_script() != null and n.get_script().get_global_name() == klasse):
		out.append(n)
	for c in n.get_children():
		_finde(c, klasse, out)


## Erste sichtbare Schaltfläche mit diesem Text (nr-te bei mehreren).
func _knopf(text: String, exakt := true, nr := 0) -> Button:
	var alle: Array = []
	_knoepfe(root, text, exakt, alle)
	return alle[nr] if nr < alle.size() else null


func _knoepfe(n: Node, text: String, exakt: bool, out: Array) -> void:
	if n is Button and (n as Button).is_visible_in_tree():
		var t: String = (n as Button).text
		if (exakt and t == text) or (not exakt and t.contains(text)):
			out.append(n)
	for c in n.get_children():
		_knoepfe(c, text, exakt, out)


## Mausklick wie ein Benutzer: Bewegung, Taste nieder, Taste los.
func _maus(p: Vector2) -> void:
	var bewegung := InputEventMouseMotion.new()
	bewegung.position = p
	bewegung.global_position = p
	Input.parse_input_event(bewegung)
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	Input.parse_input_event(ev2)


## Klick auf eine Schaltfläche, Text aus dem Schlüssel (Deutsch und Englisch).
func _klick_key(key: String, exakt := true, nr := 0) -> bool:
	return _klick_text(Texte.t(key), exakt, nr)


func _klick_text(text: String, exakt := true, nr := 0) -> bool:
	var b := _knopf(text, exakt, nr)
	if b == null:
		print("  NICHT GEFUNDEN: „%s“" % text)
		return false
	_maus(b.get_global_rect().get_center())
	print("  Klick: %s" % text)
	return true


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "en":
		_en = true
		Texte.sprache = "en"
	_G = root.get_node("/root/Game")
	_G.reset()
	_G.money = 30000  # Beispielteam kostet mehr als das Startkapital
	_G.delete_slot(3)   # Platz 3 leeren: Stände aus früheren Läufen würden überschrieben
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	print("Ordner: %s" % ProjectSettings.globalize_path(OUT))
	_schritte = [
		["Titel", func(): _snap("01_titel"); _klick_key("menue.neu")],
		["Platz wählen", func(): _snap("02_platz"); _klick_key("slots.neu_hier", true, 2)],
		["Stadt", func(): _snap("03_stadt"); _klick_key("stadt.umsehen")],
		["Stadt: zweites Umsehen", func(): _snap("04_stadt_umgesehen"); _klick_key("stadt.umsehen")],
		["Werkzeugladen", func(): _snap("05_stadt_zweimal"); _pin_klick("laden")],
		["Laden: Dietrich-Set kaufen", func(): _snap("06_laden"); _klick_key("werkzeug.lockpick.name")],
		["Laden verlassen", func(): _snap("07_laden_gekauft"); _klick_key("nav.stadt")],
		["Autoverleih", func(): _pin_klick("autoverleih")],
		["Leihwagen mieten", func(): _snap("07b_verleih"); _klick_key("shop.verleih_mieten")],
		["Verleih verlassen", func(): _klick_key("nav.stadt")],
		["Kiosk wählen", func(): _pin_klick("kiosk")],
		["Am Kiosk umsehen", func(): _klick_text("Umsehen", false)],
		["Organisation", func(): _snap("08_stadt_nach_laden"); _klick_key("nav.organisation")],
		["Otto wählen", func(): _snap("09_organisation"); _klick_person("Otto Brenner")],
		["Otto als Einbrecher", func(): _snap("10_organisation_otto"); _klick_auch_einbrechen()],
		["Team bestätigen", func(): _snap("11_organisation_team"); _klick_key("org.bestaetigen")],
		["Planung: Person wählen", func(): _snap("12_planung_leer"); _klick_text("Otto Brenner", false)],
		["Grundriss: Alles", func(): _klick_key("grid.alles")],
		["Plan bauen", func(): _plan_einrichten()],
		["Planung: Vorschau", func(): _snap("13_planung_fertig")],
		["Ausführung starten", func(): _snap("14_planung_vor_start"); _klick_key("plan.ausfuehrung_btn")],
		["Ausführung läuft", func(): _snap("15_ausfuehrung_start")],
		["Ausführung Mitte", func(): _snap("16_ausfuehrung_mitte")],
		["Ausführung abwarten", func(): _warten_ende()],
		["Auswertung", func(): _snap("17_ausfuehrung_ende"); _klick_key("ausf.auswertung")],
		["Auswertung: zurück", func(): _snap("18_auswertung"); _klick_key("nav.stadt")],
		["Tagebuch", func(): _snap("19_stadt_nach_einbruch"); _klick_key("nav.journal")],
		["Lexikon", func(): _snap("20_tagebuch"); _klick_key("nav.lexikon")],
		["Optionen", func(): _snap("21_lexikon"); _klick_key("nav.optionen")],
		["Ende", func(): _snap("22_optionen")],
	]


## Die Auswahl-Schaltfläche einer Person (Text beginnt mit ☐ oder ☑) anklicken.
func _klick_person(name: String) -> bool:
	var kandidaten: Array = []
	_finde(root, "Button", kandidaten)
	for b in kandidaten:
		var t := str(b.text)
		if (t.begins_with("☐") or t.begins_with("☑")) and t.contains(name) and b.is_visible_in_tree():
			_maus(b.get_global_rect().get_center())
			print("  Klick: Auswahl %s (%s)" % [name, t.left(12)])
			return true
	print("  KEINE AUSWAHL bei %s" % name)
	return false


## „auch einbrechen“ anklicken, aber nur einen aktiven (nicht deaktivierten) Schalter.
func _klick_auch_einbrechen() -> bool:
	var kandidaten: Array = []
	_finde(root, "Button", kandidaten)
	for b in kandidaten:
		if str(b.text).contains(Texte.t("org.auch_einbrechen")) and not b.disabled and b.is_visible_in_tree():
			_maus(b.get_global_rect().get_center())
			print("  Klick: auch einbrechen")
			return true
	print("  KEIN AKTIVER SCHALTER: auch einbrechen")
	return false


func _pin_klick(id: String) -> void:
	var karten: Array = []
	_finde(root, "CityMap", karten)
	if karten.is_empty():
		print("  KEINE KARTE")
		return
	var karte = karten[0]
	for p in karte.pins:
		if p.id == id:
			var punkt: Vector2 = karte.get_global_transform() * karte._px(p.pos)
			_maus(punkt)
			print("  Klick: Pin %s" % p.name)
			return
	print("  KEIN PIN %s" % id)


## Planung: Schritte mit Feld und Auswahl. Steht die Person zu weit weg, geht sie zuerst daneben.
func _plan_einrichten() -> void:
	_plan_laeuft = true
	# Feldkoordinaten aus den Gebäudedaten des Kiosks
	_plan = [
		[Vector2i(8, 8), func(a): return a.t == "MOVE", false],
		[Vector2i(8, 7), func(a): return a.t == "TOOL" and a.get("on", "") == "eingangstuer", true],
		[Vector2i(8, 7), func(a): return a.t == "OPEN", true],
		[Vector2i(9, 3), func(a): return a.t == "MOVE", false],
		[Vector2i(10, 3), func(a): return a.t == "TOOL" and a.get("on", "") == "kasse", true],
		[Vector2i(10, 3), func(a): return a.t == "OPEN", true],
		[Vector2i(10, 3), func(a): return a.t == "TAKE", true],
		[_wagen_feld(), func(a): return a.t == "BOARD", false],
	]


func _wagen_feld() -> Vector2i:
	var p = GameData.TARGETS[root.get_node("/root/Game").target_id].points.fluchtwagen
	return Vector2i(int(p[0]), int(p[1]))


func _in_planung() -> bool:
	var sc = _main.current
	return sc != null and sc.get_script() != null and str(sc.get_script().resource_path).ends_with("planner.gd")


func _zelle_pos(zelle: Vector2i) -> Vector2:
	if not _in_planung():
		return Vector2.ZERO
	var g = _main.current._grid
	return g.get_global_transform() * g._c(zelle)


## Im geöffneten Menü den Eintrag wählen. Liefert "ok", "nachgehen" (Person geht zuerst daneben) oder "nichts".
func _menue_waehlen(pred: Callable) -> String:
	if not _in_planung():
		return "nichts"
	var pl = _main.current
	var eintraege: Array = pl._menu_entries
	for i in range(eintraege.size()):
		if pred.call(eintraege[i][1]) and not eintraege[i][1].is_empty() and bool(eintraege[i][2]):
			_menue_klick(i, eintraege[i][0])
			return "ok"
	for i in range(eintraege.size()):
		if str(eintraege[i][0]).contains("gehen (dann") or str(eintraege[i][0]).contains("neben") or str(eintraege[i][0]).contains("next to"):
			_menue_klick(i, eintraege[i][0])
			return "nachgehen"
	print("  NICHT IM MENÜ: %s" % str(eintraege.map(func(e): return e[0])))
	return "nichts"


func _menue_klick(i: int, text: String) -> void:
	if not _in_planung():
		return
	var m: PopupMenu = _main.current._menu
	var y := float(m.position.y) + (float(i) + 0.5) * float(m.size.y) / float(max(m.item_count, 1))
	_maus(Vector2(float(m.position.x) + 30.0, y))
	print("  Menü: %s" % text)


func _warten_ende() -> void:
	# Hier nicht schrittweise: der Ablauf prüft in _process, ob die Ausführung fertig ist
	pass


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_start()
		return false
	if _f < _next:
		return false
	# Wächter: kommt der Ablauf nicht voran, wird mit einer Meldung abgebrochen statt zu hängen
	if _s != _letzter_s:
		_letzter_s = _s
		_letzter_f = _f
	elif _f - _letzter_f > MAX_WARTEN:
		var wo: String = str(_schritte[_s][0]) if _s < _schritte.size() else "Ende"
		print("ZEITÜBERSCHREITUNG bei Schritt: %s (kein Fortschritt seit %d Bildern)" % [wo, MAX_WARTEN])
		_G.delete_slot(3)
		quit(1)
		return false
	# Planungsphase: Feld anklicken, Menü abwarten, Eintrag wählen, ggf. nachgehen und erneut versuchen
	if _plan_laeuft:
		_plan_schritt()
		return false
	if _s >= _schritte.size():
		print("Ende des Mausdurchlaufs. Geld: %d" % _G.money)
		_G.delete_slot(3)   # Teststand wieder entfernen
		quit(0)
		return false
	var name: String = _schritte[_s][0]
	if name == "Ausführung abwarten":
		# Warten, bis der Knopf „Auswertung“ sichtbar ist (nach der Fluchtszene)
		if _knopf(Texte.t("ausf.auswertung")) != null:
			_s += 1
		else:
			_next = _f + 30
		return false
	print("Schritt: %s" % name)
	_schritte[_s][1].call()
	_s += 1
	_next = _f + 10
	return false


func _kurz(a: Dictionary) -> String:
	var ziel = a.get("cell", a.get("to", a.get("on", a.get("loot", ""))))
	if a.has("fine"):
		ziel = a.fine
	return "%s %s" % [a.t, str(ziel)]


## Ein Planungsschritt: Feld anklicken, Menü abwarten, Eintrag wählen. Die Planung ist fertig, wenn keine Schritte übrig sind.
func _plan_schritt() -> void:
	if not _in_planung():
		var sk = _main.current.get_script() if _main.current != null else null
		print("  Planung nicht offen (offen: %s), Planungsschritte werden übersprungen" % (str(sk.resource_path) if sk != null else str(_main.current)))
		_plan.clear()
	if _plan.is_empty():
		_plan_laeuft = false
		_next = _f + 8
		return
	if _warte == 0:
		var schritt: Array = _plan[0]
		_maus(_zelle_pos(schritt[0]))
		print("Plan: Feld %s" % str(schritt[0]))
		_warte = 1
		_next = _f + 6
		return
	var s: Array = _plan[0]
	var ergebnis := _menue_waehlen(s[1])
	_warte = 0
	_versuche += 1
	_next = _f + 14
	if ergebnis != "nachgehen" or _versuche >= 3:
		_plan.pop_front()
		_versuche = 0
	_next = _f + 8

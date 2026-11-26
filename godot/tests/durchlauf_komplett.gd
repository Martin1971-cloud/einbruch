extends SceneTree
## Durchlauf des laufenden Spiels mit einem Bild an jeder Station. Schritte nacheinander, jeweils mit Wartezeit
## in Bildern: Titel, Stadt, Organisation, Planung mit Vorschau, Ausführung (Mitte, Ende), Auswertung.
## Aufruf: xvfb-run ... --script res://tests/durchlauf_komplett.gd  (Bilder landen im Ordner OUT)
const OUT := "user://durchlauf/"  # Bilder: Godot-Benutzerordner, Pfad wird beim Start ausgegeben
var _sprache := "de"
var _f := 0
var _next := 2
var _i := 0
var _main: Node
var _G: Node
var _schritte: Array = []


func _snap(name: String) -> void:
	var ordner := ProjectSettings.globalize_path(OUT + ("en/" if _sprache == "en" else ""))
	DirAccess.make_dir_recursive_absolute(ordner)
	root.get_texture().get_image().save_png(ordner + "/" + name + ".png")
	print("Bild: %s" % name)


func _start() -> void:
	# Aufruf mit "-- en" für die englische Fassung (Bilder in Unterordner en/)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "en":
		_sprache = "en"
		Texte.sprache = "en"
	_G = root.get_node("/root/Game")
	_G.reset()
	_G.tools_owned["lockpick"] = true
	_G.tools_owned["crowbar"] = true
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _stadt() -> void:
	_main.current._on_look()
	_main.current._on_look()
	_main.go("organisation")


func _organisation() -> void:
	var org = _main.current
	for c in GameData.CREW:
		org._selected[c.id] = c.id == "otto"
		org._gear_pick[c.id] = []
	org._burgle["otto"] = true
	org._build_people()
	org._build_shop()
	org._refresh_summary()
	_snap("03_organisation")
	org._on_confirm()


func _planung() -> void:
	# Wie der Spieler: Aktion auf die Zeitleiste ziehen, dann Ziel und Werkzeug wählen
	var pl = _main.current
	var schritte := [
		["MOVE", {"to": "aussen_eingang"}],
		["TOOL", {"tool": "lockpick", "on": "eingangstuer"}],
		["OPEN", {"on": "eingangstuer"}],
		["MOVE", {"cell": [9, 3]}],
		["TOOL", {"tool": "lockpick", "on": "kasse"}],
		["OPEN", {"on": "kasse"}],
		["TAKE", {"loot": "kasse"}],
		["MOVE", {"to": "fluchtwagen"}],
	]
	for st in schritte:
		pl._on_dropped("otto", st[0])
		var a: Dictionary = pl.plans["otto"][-1]
		for k in st[1]:
			a[k] = st[1][k]
	pl._on_changed()
	print("Aktionen: %d" % pl.plans["otto"].size())


func _ausfuehrung_start() -> void:
	var ex = _main.current
	print("Bildschirm nach Ausführen: %s" % ex.get_script().resource_path.get_file())
	ex.speed = 8.0


func _ausfuehrung_mitte() -> void:
	_snap("05_ausfuehrung_mitte")


func _auswertung() -> void:
	var ex = _main.current
	print("Ausführung: %s – %s" % [ex.sim.status, ex.sim.ended_reason])
	_snap("06_ausfuehrung_ende")
	_main.go("result", {"result": ex.sim.result()})


func _ende() -> void:
	_snap("07_auswertung")
	print("Geld: %d, Fahndung: %d, Tag %d" % [_G.money, int(_G.heat), _G.day])
	quit(0)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_start()
		_next = _f + 10
		return false
	if _f < _next:
		return false
	match _i:
		0:
			_snap("01_titel")
			_main.go("town")
			_weiter(12)
		1:
			_snap("02_stadt")
			_stadt()
			_weiter(12)
		2:
			_organisation()
			_weiter(12)
		3:
			_planung()
			_i = 4
			_next = _f + 6
		4:
			_snap("04_planung")
			var f := FileAccess.open(OUT + _sprache + "_vorschau.txt", FileAccess.WRITE)
			print("Ordner: %s" % ProjectSettings.globalize_path(OUT))
			f.store_string(_main.current._preview.text)
			f.close()
			_main.current._on_execute()
			_i = 5
			_next = _f + 60
		5:
			_ausfuehrung_start()
			_weiter(200)
		6:
			_ausfuehrung_mitte()
			_i = 7
			_next = _f + 2
		7:
			if _main.current.finished:
				_auswertung()
				_i = 8
				_next = _f + 12
			else:
				_next = _f + 30
		8:
			_snap("07_auswertung")
			_main.go("town")
			_weiter(12)
		9:
			_snap("08_stadt_nach_dem_einbruch")
			_main.open_journal()
			_weiter(12)
		10:
			_snap("09_tagebuch")
			_main.open_journal()
			_main.open_lexikon()
			_weiter(12)
		11:
			_snap("10_lexikon")
			_main.open_lexikon()
			_main.open_optionen()
			_weiter(12)
		12:
			_snap("11_optionen")
			_ende()
	return false


func _weiter(bilder: int) -> void:
	_i += 1
	_next = _f + bilder

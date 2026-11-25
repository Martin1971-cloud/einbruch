extends SceneTree
## Prüft das Bild in der Auswertung: erfolgreich zeigt das Erfolgsbild, Festnahme das Fehlschlagbild,
## Abbruch zeigt kein Bild. Mit Ordner als Argument wird je Ausgang ein Screenshot gespeichert.
## Aufruf: godot --headless --path godot --script res://tests/test_auswertung_bild.gd
## Mit Screenshots: xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://tests/test_auswertung_bild.gd -- <Ordner>
var _fails := 0
var _frame := 0
var _case := 0
var _phase := 0
var _out := ""
const CASES := [["ENTKOMMEN", "res://assets/art/result_erfolg.webp"], ["GEFASST", "res://assets/art/result_fehl.webp"], ["ABBRUCH", ""]]
var _main: Node


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _find_picture(node: Node, path: String = "") -> TextureRect:
	# ohne Pfad: irgendein Bild; mit Pfad: genau dieses Bild
	if node is TextureRect and node.texture != null and (path == "" or node.texture.resource_path == path):
		return node
	for c in node.get_children():
		var f := _find_picture(c, path)
		if f != null:
			return f
	return null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		root.get_node("/root/Game").reset()
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		return false
	if _frame < 3:
		return false
	if _case >= CASES.size():
		print("Ergebnis: %d Fehler" % _fails)
		quit(1 if _fails > 0 else 0)
		return false
	var status: String = CASES[_case][0]
	var expect: String = CASES[_case][1]
	if _phase == 0:
		_main.go("result", {"result": {"status": status, "reason": "Testausgang " + status, "loot_taken": ["Kassenlade"], "loot_missed": [], "payout": 2400, "heat": 0.0, "log": ["[00:00] Test"], "crew": [], "events": []}})
		_phase = 1
		return false
	if _phase == 1:
		# einen Bildlauf abwarten, dann prüfen und speichern
		_phase = 2
		return false
	if expect == "":
		_check(_find_picture(_main.current) == null, "%s: kein Bild" % status)
	else:
		_check(_find_picture(_main.current, expect) != null, "%s: Bild %s" % [status, expect])
	if _out != "":
		root.get_texture().get_image().save_png(_out.path_join("auswertung_%s.png" % status.to_lower()))
	_case += 1
	_phase = 0
	return false

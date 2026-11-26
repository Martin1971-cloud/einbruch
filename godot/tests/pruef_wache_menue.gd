extends SceneTree
## Sichtprüfung des Wachen-Menüs in der Planung: Kampfsport zu gering, riskant und möglich.
## Aufruf: godot --rendering-method gl_compatibility --path . --script res://tests/pruef_wache_menue.gd -- <Ordner> [en]
var _f := 0
var _main: Node
var _out := "/tmp"
var _schritt := 0
var _sprache := "de"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.has("en"):
		_sprache = "en"
		Texte.sprache = "en"


func _crew(id: String) -> Dictionary:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			return d
	return {}


func _process(_d: float) -> bool:
	_f += 1
	var G = root.get_node("/root/Game")
	if _f == 2:
		G.reset()
		G.car_id = "limo"
		G.target_id = "testhaus"
		G.unlocked["testhaus"] = true
		G.intel["testhaus"] = 2
		G.money = 1000000
		G.tools_owned["lockpick"] = true
		G.tools_owned["chloroform"] = true
		G.team = [_crew("ilja"), _crew("teo")]
		G.driver = _crew("otto")
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
		return false
	if _f < 12:
		return false
	var pl = _main.current
	match _schritt:
		0:
			pl._active = "ilja"
			pl._on_map_click(Vector2i(11, 8))
			_schritt = 1
		1:
			root.get_texture().get_image().save_png("%s/1_ilja_%s.png" % [_out, _sprache])
			pl._active = "teo"
			pl._on_map_click(Vector2i(11, 8))
			_schritt = 2
		2:
			root.get_texture().get_image().save_png("%s/2_teodor_%s.png" % [_out, _sprache])
			quit(0)
	return false

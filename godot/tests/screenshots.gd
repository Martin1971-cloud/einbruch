extends SceneTree
## Macht Screenshots aller Bildschirme (braucht Anzeige, z. B. über xvfb-run).
## Aufruf: xvfb-run -a godot --path godot --script res://tests/screenshots.gd -- <Ausgabeordner>

var _out := "/tmp"
var _frames := 0
var _stage := -1
var _main: Node
var G: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("gespeichert: " + name)


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == -1 and _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		G.tools_owned["lockpick"] = true
		G.tools_owned["crowbar"] = true
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_stage = 0
		_frames = 0
		return false
	match _stage:
		0:
			if _frames == 10:
				_shot("01_stadt")
				_main.go("organisation")
				_stage = 1
				_frames = 0
		1:
			if _frames == 10:
				_shot("02_organisation")
				G.team = []
				for c in GameData.CREW:
					if c.id in ["teo", "ilja", "rosa"]:
						var d: Dictionary = c.duplicate(true)
						d["gear"] = "sneakers" if c.id == "teo" else "none"
						G.team.append(d)
				_main.go("planner")
				_stage = 2
				_frames = 0
		2:
			if _frames == 10:
				var p = _main.current
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][0]["to"] = "Außen vor dem Eingang"
				p._on_dropped("teo", "TOOL")
				p.plans["teo"][1] = {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][2]["to"] = "Gemälde"
				p._on_dropped("teo", "CALL_CAR")
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][4]["to"] = "Fluchtwagen"
				p._on_changed()
				_stage = 3
				_frames = 0
		3:
			if _frames == 15:
				_shot("03_planung")
				_main.current._on_execute()
				_stage = 4
				_frames = 0
		4:
			if _frames == 60:
				_main.current._speed = 4.0
				_stage = 5
				_frames = 0
		5:
			if _frames == 90:
				_shot("04_ausfuehrung_mitte")
			if _main.current.finished or _frames > 6000:
				_stage = 6
				_frames = 0
		6:
			if _frames == 20:
				_shot("05_ausfuehrung_ende")
				_main.current._on_result()
				_stage = 7
				_frames = 0
		7:
			if _frames == 15:
				_shot("06_auswertung")
				quit(0)
				return true
	return false

extends SceneTree
## Screenshot der Planung am Einstiegs-Kiosk (Beispielplan, Wiedergabe am Ende).
## Aufruf: xvfb-run -a godot --path godot --script res://tests/screenshots_kiosk.gd -- <Ordner>

var _out := "/tmp"
var _frames := 0
var _stage := 0
var _main: Node
var G: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == 0 and _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"  # Leihwagen im Autoverleih gemietet
		G.money = 30000  # Beispielteam kostet mehr als das Startkapital
		G.tools_owned["lockpick"] = true
		G.team = []
		for c in GameData.CREW:
			if c.id in ["teo", "ilja", "rosa"]:
				var d: Dictionary = c.duplicate(true)
				d["gear"] = "none"
				G.team.append(d)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames == 10:
		_main.current._on_example()
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames == 10:
		root.get_texture().get_image().save_png(_out.path_join("kiosk_planner.png"))
		var dur: float = _main.current._res.get("time", 60.0)
		_main.current._seek(dur)
		_stage = 3
		_frames = 0
	elif _stage == 3 and _frames == 8:
		root.get_texture().get_image().save_png(_out.path_join("kiosk_ende.png"))
		print("fertig")
		quit()
	return false

extends SceneTree
## Screenshots der Wiedergabe (Sichtkegel, Alarm) an einem Beispielplan.
## Aufruf: xvfb-run -a godot --path godot --script res://tests/screenshots_play.gd -- <Ordner>

var _out := "/tmp"
var _frames := 0
var _stage := -1
var _main: Node
var _shots: Array = []
var G: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == -1 and _frames == 2:
		G = root.get_node("/root/Game")
		G.reset()
		G.tools_owned["lockpick"] = true
		G.tools_owned["crowbar"] = true
		G.intel["museum"] = 2
		G.team = []
		for c in GameData.CREW:
			if c.id in ["teo", "ilja", "rosa"]:
				var d: Dictionary = c.duplicate(true)
				d["gear"] = "sneakers" if c.id == "teo" else "none"
				G.team.append(d)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
		_stage = 0
		_frames = 0
		return false
	if _stage == 0 and _frames == 10:
		var p = _main.current
		p.plans["teo"] = [
			{"t": "MOVE", "to": "Außen vor dem Eingang"},
			{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "MOVE", "to": "Gemälde"},
			{"t": "TAKE", "loot": "gemaelde"},
			{"t": "CALL_CAR"},
			{"t": "MOVE", "to": "Fluchtwagen"},
		]
		p.plans["ilja"] = [{"t": "MOVE", "to": "Außen vor dem Eingang"}, {"t": "MOVE", "to": "Fluchtwagen"}]
		p.plans["rosa"] = [{"t": "MOVE", "to": "Fluchtwagen"}]
		p._on_changed()
		_stage = 1
		_frames = 0
	elif _stage == 1 and _frames == 10:
		var p2 = _main.current
		var dur: float = p2._res.get("time", 60.0)
		_shots = [["07_play_start", 2.0], ["08_play_wache_sieht", 12.0], ["09_play_alarm", 18.0], ["10_play_ende", dur]]
		_stage = 2
		_frames = 0
	elif _stage == 2 and _frames == 6:
		var shot: Array = _shots.pop_front()
		_main.current._seek(float(shot[1]))
		_stage = 3
		_frames = 0
		_pending = shot[0]
	elif _stage == 3 and _frames == 8:
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join(_pending + ".png"))
		print("gespeichert: " + _pending + " t=" + str(_main.current._playhead))
		if _shots.is_empty():
			quit(0)
			return true
		_stage = 2
		_frames = 0
	return false


var _pending := ""

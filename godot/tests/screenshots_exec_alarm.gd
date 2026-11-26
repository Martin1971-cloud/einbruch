extends SceneTree
## 3D-Ausführung des Beispielplans: Screenshots vor, bei und nach dem Alarm.
## Aufruf: xvfb-run -a godot --path godot --script res://tests/screenshots_exec_alarm.gd -- <Ordner>

var _out := "/tmp"
var _frames := 0
var _stage := -1
var _main: Node
var _targets: Array = [[12.0, "11_exec_vor_alarm"], [19.0, "12_exec_alarm"], [30.0, "13_exec_verfolgung"]]
var _pending := ""
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
		G.intel["museum"] = 2
		G.team = []
		for c in GameData.CREW:
			if c.id in ["teo", "ilja", "rosa"]:
				var d: Dictionary = c.duplicate(true)
				d["gear"] = "sneakers" if c.id == "teo" else "none"
				G.team.append(d)
		var plans := {
			"teo": [
				{"t": "MOVE", "to": "aussen_eingang"},
				{"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"},
				{"t": "MOVE", "to": "gemaelde"},
				{"t": "TAKE", "loot": "gemaelde"},
				{"t": "CALL_CAR"},
				{"t": "MOVE", "to": "fluchtwagen"},
			],
			"ilja": [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "MOVE", "to": "fluchtwagen"}],
			"rosa": [{"t": "MOVE", "to": "fluchtwagen"}],
		}
		var cfg := {"target": GameData.TARGETS.museum, "team": G.team, "plans": plans, "car": GameData.car_now("limo", 85.0)}
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("execution", {"config": cfg})
		_main.current.speed = 4.0
		_stage = 0
		_frames = 0
		return false
	if _stage == 0:
		var ex = _main.current
		if ex.sim.time >= float(_targets[0][0]) or ex.finished:
			_pending = _targets[0][1]
			_targets.pop_front()
			_stage = 1
			_frames = 0
	elif _stage == 1 and _frames == 5:
		root.get_texture().get_image().save_png("%s/%s.png" % [_out, _pending])
		print("gespeichert: %s t=%.1f status=%s" % [_pending, _main.current.sim.time, _main.current.sim.status])
		if _targets.is_empty():
			quit(0)
			return true
		_stage = 0
		_frames = 0
	return false

extends SceneTree
## Screenshot: freier Weg in der Planung (Teodor geht zu einem Punkt im Raum).
var _out := "/tmp"
var U := Sim.SUB / 8  # Koordinaten sind in Einheiten von 8 Unterfeldern geschrieben
var _frames := 0
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.tools_owned["lockpick"] = true
		G.team = []
		var d: Dictionary = GameData.CREW[0].duplicate(true)
		for c in GameData.CREW:
			if c.id == "teo":
				d = c.duplicate(true)
				d["gear"] = "none"
		G.team.append(d)
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("planner")
		return false
	if _frames == 10:
		var pl = _main.current
		pl.plans["teo"] = [
			{"t": "MOVE", "to": "Außen vor dem Eingang"},
			{"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"},
			{"t": "OPEN", "on": "Eingangstür"},
			{"t": "MOVE", "fine": [60 * U, 46 * U]},
			{"t": "MOVE", "fine": [96 * U, 60 * U]},
		]
		pl._on_changed()
		return false
	if _frames == 20:
		root.get_texture().get_image().save_png(_out.path_join("frei_planer.png"))
		quit(0)
	return false

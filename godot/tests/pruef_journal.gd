extends SceneTree
## Sichtprüfung: Journal mit zwei Einbrüchen (einer gelungen, einer mit Festnahme).
var _frames := 0
var _out := "/tmp"
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
		G.apply_result({"status": "ENTKOMMEN", "payout": 12000, "time": 71.0, "loot_taken": ["Kassenlade", "Wertschrank"], "log": [], "segments": {"teo": [{"fail": ""}]}})
		G.apply_result({"status": "GEFASST", "payout": 0, "time": 300.0, "loot_taken": [], "log": ["[02:10] ALARM durch Mikrofon Verkauf. Polizei in 600 s."], "segments": {"teo": [{"fail": "Tür zu"}]}})
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("town")
		_main.open_journal()
	elif _frames == 30:
		root.get_texture().get_image().save_png(_out.path_join("journal.png"))
		quit(0)
	return false

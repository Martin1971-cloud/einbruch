extends SceneTree
## Sichtprüfung der 3D-Ausführung für ein Gebäude (Curiosity oder Juwelier) über die Ausführungsszene.
## Aufruf: godot --rendering-driver opengl3 --path . --script res://tests/pruef_3d_ausfuehrung.gd -- <Ordner> <curiosity|juwelier>
var _f := 0
var _main: Node
var _out := "/tmp"
var _ziel := "curiosity"
var _shots := 0
const MAX_SHOTS := 8
const FRAMES_PRO_SHOT := 240


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_ziel = args[1]


func _crew(id: String) -> Dictionary:
	for c in GameData.CREW:
		if c.id == id:
			var d: Dictionary = c.duplicate(true)
			d["gear"] = ["gloves"]
			return d
	return {}


func _plan(ziel: String) -> Array:
	var entry := [{"t": "MOVE", "to": "aussen_eingang"}, {"t": "TOOL", "tool": "lockpick", "on": "eingangstuer"}, {"t": "OPEN", "on": "eingangstuer"}]
	if ziel == "juwelier":
		return entry + [
			{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "diamantring"}, {"t": "OPEN", "on": "diamantring"}, {"t": "TAKE", "loot": "diamantring"},
			{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "perlen"}, {"t": "OPEN", "on": "perlen"}, {"t": "TAKE", "loot": "perlen"},
			{"t": "MOVE", "cell": [8, 6]}, {"t": "TOOL", "tool": "schneidbrenner", "on": "stahltuer"},
			{"t": "MOVE", "cell": [12, 7]}, {"t": "TOOL", "tool": "lockpick", "on": "tresor"}, {"t": "OPEN", "on": "tresor"}, {"t": "TAKE", "loot": "tresor"},
			{"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
		]
	return entry + [
		{"t": "MOVE", "cell": [4, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "uhren"}, {"t": "OPEN", "on": "uhren"}, {"t": "TAKE", "loot": "uhren"},
		{"t": "MOVE", "cell": [6, 5]}, {"t": "TOOL", "tool": "lockpick", "on": "besteck"}, {"t": "OPEN", "on": "besteck"}, {"t": "TAKE", "loot": "besteck"},
		{"t": "MOVE", "cell": [4, 6]}, {"t": "TAKE", "loot": "landschaft"},
		{"t": "MOVE", "cell": [4, 8]}, {"t": "TREPPE"}, {"t": "MOVE", "cell": [4, 17]}, {"t": "TOOL", "tool": "lockpick", "on": "gemmen"}, {"t": "OPEN", "on": "gemmen"}, {"t": "TAKE", "loot": "gemmen"},
		{"t": "MOVE", "cell": [4, 20]}, {"t": "TREPPE"}, {"t": "CALL_CAR"}, {"t": "MOVE", "to": "fluchtwagen"},
	]


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var G = root.get_node("/root/Game")
		G.reset()
		G.car_id = "limo"
		G.money = 30000
		G.tools_owned["lockpick"] = true
		G.tools_owned["schneidbrenner"] = true
		var team := [_crew("teo"), _crew("otto")]
		var plans := {"teo": _plan(_ziel), "otto": [{"t": "MOVE", "to": "fluchtwagen"}]}
		var cfg := {"target": GameData.TARGETS[_ziel], "team": team, "plans": plans, "car": GameData.car_now("limo", 85.0)}
		_main = load("res://scenes/main.tscn").instantiate()
		root.add_child(_main)
		_main.go("execution", {"config": cfg})
		return false
	if _f < 10:
		return false
	var ex = _main.current
	if _f % FRAMES_PRO_SHOT == 0 and _shots < MAX_SHOTS:
		root.get_texture().get_image().save_png("%s/%02d_%s_t%03d.png" % [_out, _shots + 1, _ziel, int(ex.sim.time)])
		print("shot %d t=%.0f status=%s" % [_shots + 1, ex.sim.time, ex.sim.status])
		_shots += 1
	if _shots >= MAX_SHOTS or ex.finished:
		quit(0)
	return false

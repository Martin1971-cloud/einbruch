extends SceneTree
## Screenshot der 2D-Fluchtszene (Festnahme und Entkommen).
var _f := 0
var _s := ["GEFASST", "ENTKOMMEN_HEISS"]
var _sc: Node
var _out := "/tmp"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_out = a[0]

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_sc = EscapeScene.new()
		_sc.set_anchors_preset(Control.PRESET_FULL_RECT)
		_sc.status = _s[0]
		_sc.alarm = true
		root.add_child(_sc)
		_sc._t = 3.0
	if _f == 6:
		root.get_texture().get_image().save_png(_out.path_join("flucht_gefasst.png"))
		_sc._t = 2.0
		_sc.status = "ENTKOMMEN_HEISS"
	if _f == 10:
		root.get_texture().get_image().save_png(_out.path_join("flucht_heiss.png"))
		print("gespeichert")
		quit(0)
		return true
	return false

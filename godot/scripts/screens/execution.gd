extends ExecAnzeige
## Ausführungsphase in 3D. Dieselbe Simulation wie in der Vorschau, nur sichtbar und in Echtzeit.
## Aufbau der Oberfläche und Ablauf. Die Darstellung steht in execution_welt.gd und execution_anzeige.gd.

func _ready() -> void:
	cfg = args.config
	sim = Sim.create(cfg.target, cfg.team, cfg.plans, cfg.car, cfg.karte)
	_build_world()
	_build_ui()
	_sync()
	_update_cones()

# ---------------------------------------------------------------- Oberfläche
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_layer = layer
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	layer.add_child(root)

	# Während der Ausführung nur Pause und Beenden aus der Leiste; Etagen, Tempo und Funk darunter
	_pause_btn = UI.button(Texte.t("ausf.pause"), _on_pause, 110)
	root.add_child(Navigation.leiste(main, "ausfuehrung", [_pause_btn]))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	_clock = UI.label("", 20, Color(0.95, 0.8, 0.4))
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_clock)
	_status = UI.label("", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_status)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	# Etagen-Schalter (nur bei Zielen mit Etagen)
	if not cfg.target.get("floors", []).is_empty():
		top.add_child(UI.button(Texte.t("ausf.folgen"), _on_floor_pick.bind("folgen"), 80))
	for fl in cfg.target.get("floors", []):
		top.add_child(UI.button(Texte.t(str(fl.name)), _on_floor_pick.bind(str(fl.id)), 70))
	if not cfg.target.get("floors", []).is_empty():
		top.add_child(UI.button(Texte.t("ausf.alle"), _on_floor_pick.bind("alle"), 70))
	var abort_btn := UI.button(Texte.t("ausf.funk"), _on_abort, 250)
	abort_btn.tooltip_text = Texte.t("ausf.funk_tip")
	top.add_child(abort_btn)
	top.add_child(UI.dropdown(["1x", "4x", "16x"], 0, func(i: int): speed = [1.0, 4.0, 16.0][i]))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, 170)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	bottom.add_child(_log)
	_result_btn = UI.button(Texte.t("ausf.auswertung"), _on_result, 200)
	_result_btn.visible = false
	bottom.add_child(_result_btn)

func _on_abort() -> void:
	sim.abort()
	_sync()

func _on_pause() -> void:
	paused = not paused
	_pause_btn.text = Texte.t("ausf.weiter") if paused else Texte.t("ausf.pause")

func _on_speed(s: float) -> void:
	speed = s

func _on_result() -> void:
	main.go("result", {"result": sim.result()})

func _finish() -> void:
	finished = true
	Game.apply_result(sim.result())
	_status.text = Texte.t("ausf.ende") % sim.status
	# Erst die Fluchtszene, danach die Auswertung
	var sc := EscapeScene.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.status = sim.status
	sc.alarm = sim.alarm_active
	sc.chase = sim.chase
	sc.car_id = Game.car_id
	sc.done.connect(func():
		sc.queue_free()
		_result_btn.visible = true)
	_layer.add_child(sc)

# ---------------------------------------------------------------- Schleife
func _process(delta: float) -> void:
	if finished or paused:
		return
	_acc += delta * speed
	_cone_t += delta
	_alarm_light(delta)
	var guard := 0
	while _acc >= Sim.DT and guard < 400:
		sim.step(Sim.DT)
		_acc -= Sim.DT
		guard += 1
		if sim.status != "RUNNING":
			break
	_sync()
	if _cone_t >= 0.1:
		_cone_t = 0.0
		_update_cones()
	if sim.status != "RUNNING":
		_finish()

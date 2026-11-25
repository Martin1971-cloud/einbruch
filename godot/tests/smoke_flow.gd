extends SceneTree
## Durchlauf des kompletten Ablaufs ohne Mausklicks:
## Stadt -> Organisation -> Planung (Aktionen gesetzt) -> Ausführung -> Auswertung.
## Aufruf: godot --headless --path godot --script res://tests/smoke_flow.gd

var _frames := 0
var _stage := 0
var _main: Node
var _errors := 0
var G: Node


func _initialize() -> void:
	_stage = -1


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == -1:
		if _frames == 2:
			G = root.get_node("/root/Game")
			G.reset()
			G.target_id = "museum"
			G.unlocked.museum = true
			G.tools_owned["lockpick"] = true
			G.tools_owned["crowbar"] = true
			var packed: PackedScene = load("res://scenes/main.tscn")
			_main = packed.instantiate()
			root.add_child(_main)
			_stage = 0
			_frames = 0
		return false
	match _stage:
		0:
			if _frames == 3:
				print("Stadt geladen: %s" % _current_name())
				_main.go("organisation")
				_stage = 1
				_frames = 0
		1:
			if _frames == 3:
				print("Organisation geladen")
				var crew := []
				for c in GameData.CREW:
					if c.id == "teo" or c.id == "ilja" or c.id == "rosa":
						var d: Dictionary = c.duplicate(true)
						d["gear"] = "sneakers" if c.id == "teo" else "none"
						crew.append(d)
				G.team = crew
				_main.go("planner")
				_stage = 2
				_frames = 0
		2:
			if _frames == 3:
				print("Planung geladen")
				var p = _current()
				# Drag & Drop simulieren: Aktions auf die Zeitleisten legen
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][0]["to"] = "Außen vor dem Eingang"
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][1]["to"] = "Eingangstür"
				p._on_dropped("teo", "TOOL")
				p.plans["teo"][2] = {"t": "TOOL", "tool": "lockpick", "on": "Eingangstür"}
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][3]["to"] = "Gemälde"
				p._on_dropped("teo", "TAKE")
				p.plans["teo"][4]["loot"] = "gemaelde"
				p._on_dropped("teo", "CALL_CAR")
				p._on_dropped("teo", "MOVE")
				p.plans["teo"][6]["to"] = "Fluchtwagen"
				p._on_dropped("ilja", "WAIT")
				p._on_dropped("ilja", "MOVE")
				p.plans["ilja"][1]["to"] = "Fluchtwagen"
				p._on_dropped("rosa", "MOVE")
				p.plans["rosa"][0]["to"] = "Fluchtwagen"
				p._on_preview()
				print("Vorschau: %s" % p._preview.text.split("\n")[0])
				p._on_execute()
				_stage = 3
				_frames = 0
		3:
			if _frames == 3:
				print("Ausführung geladen")
				current_exec().speed = 16.0
			var ex = _current()
			if ex.finished:
				print("Ausführung beendet: %s – %s" % [ex.sim.status, ex.sim.ended_reason])
				print("Zeit: %s, Auszahlung: %d €, Fahndung: %d" % [Sim.clock(ex.sim.time), ex.sim.payout, int(ex.sim.fence_heat())])
				_stage = 4
				_frames = 0
			elif _frames > 60 * 120:
				print("FEHLER: Ausführung endet nicht")
				_errors += 1
				quit(1)
				return true
		4:
			if _frames == 3:
				_main.go("result", {"result": G.last_result})
				_stage = 5
				_frames = 0
		5:
			if _frames == 3:
				print("Auswertung geladen. Geld: %d, Fahndung: %d, Tag %d %s" % [G.money, int(G.heat), G.day, G.clock_text()])
				print("Smoke-Test abgeschlossen. Fehler: %d" % _errors)
				quit(_errors)
				return true
	return false


func current_exec() -> Node:
	return _main.current


func _current() -> Node:
	return _main.current


func _current_name() -> String:
	return _current().get_class() + " " + str(_current().get_script().resource_path)

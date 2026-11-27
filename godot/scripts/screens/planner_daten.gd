class_name PlannerDaten
extends Control
## Planer, Grundlage: Zustand, Auswahllisten, Texte und Hilfen, Layout-Bausteine.

var main: Node

var args: Dictionary = {}

var target: Dictionary

var plans := {}

var _grid: GridView

var _gantt: Gantt

var _preview: RichTextLabel

var _steps_rt: RichTextLabel

var _options := {}

var _checklist: VBoxContainer

var _team_box: VBoxContainer

var _intel_label: Label

var _res: Dictionary = {}

var _labels := {}

var _playing := false

var _play_until := -1.0  # beim Abspielen einer neuen Aktion: bei dieser Sekunde anhalten

var _speed := 2.0

var _playhead := 0.0

var _play_btn: Button

var _speed_btn: Button

var _slider: HSlider

var _time_lbl: Label

var _active := ""          # ausgewählte Person im Team

var _team_btns := {}

const CREW_COL := GridView.COLORS

const LOUD_HINT_DB := 5.5  # ab diesem Lärm erklärt der Hinweis „Lärm“ (über dem Gehen)

const LEFT_W := 270

const RIGHT_W := 250

const SIDE_W := 200   # Spalte rechts neben dem Grundriss: Ablaufplan und Vorschau

const TEXT_MIN := 10  # kleinste Schriftgröße in Ablaufplan und Vorschau

const TEXT_MAX := 18

var _text_size := 13

var _text_lbl: Label

var _timeline_col: Control

## Etagen des Ziels (leer = eine Etage).
func _floor_list() -> Array:
	return target.get("floors", [])

## Etage eines Feldes (Zeile der Karte). "" wenn das Ziel keine Etagen hat.
func _floor_name_at_row(y: float) -> String:
	for fl in _floor_list():
		if y >= float(fl.rows[0]) and y < float(fl.rows[1]):
			return Texte.t(str(fl.name))
	return ""

## Etage einer Person: an ihrer Stelle im Ablauf (Abspielmarke), sonst am Start.
func _crew_floor(id: String) -> String:
	if _floor_list().is_empty():
		return ""
	var y := -1.0
	var frames: Array = _res.get("frames", [])
	if not frames.is_empty():
		var f := _interp_frame(frames, _playhead)
		if f.has("crew") and f.crew.has(id):
			y = float(f.crew[id][1]) / float(Sim.SUB)
	if y < 0.0:
		for c in Game.team:
			if c.id == id and c.has("start"):
				y = float(Sim._v2i(c.start).y)
	return _floor_name_at_row(y)

## Etagenangabe in den Team-Schaltflächen aktualisieren (beim Abspielen mit).
func _update_team_floors() -> void:
	for id in _team_btns:
		var b: Button = _team_btns[id]
		var base: String = str(b.get_meta("base", b.text))
		var fl := _crew_floor(id)
		b.text = base if fl == "" else "%s  ·  %s" % [base, fl]

func _legend_row(col: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var swatch := ColorRect.new()
	swatch.color = col
	swatch.custom_minimum_size = Vector2(14, 10)
	h.add_child(swatch)
	h.add_child(_l(text, 12, Color(0.8, 0.84, 0.9)))
	return h

## Setzt die Schriftgröße für Schaltflächen, Eingaben und Auswahlfelder unterhalb von node.
func _shrink_text(node: Node, size: int) -> void:
	for c in node.get_children():
		if c is Button or c is LineEdit or c is OptionButton or c is Label or c is CheckBox:
			c.add_theme_font_size_override("font_size", size)
		_shrink_text(c, size)

## Karte mit einheitlichem Stil; optional mit Titel.
func _card(content: Control, title := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.card_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if title != "":
		v.add_child(_l(title.to_upper(), 11, Color(0.89, 0.71, 0.35)))
	v.add_child(content)
	return p

func _l(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	## Einzeilige Beschriftung ohne Umbruch.
	var lbl := UI.label(t, size, col)
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	return lbl

func _w(t: String, size := 14, col := Color(0.92, 0.9, 0.85)) -> Label:
	## Mehrzeilige Beschriftung, darf umbrechen.
	return UI.label(t, size, col)

# ---------------------------------------------------------------- Daten
func _build_options() -> void:
	var points: Array = []
	for id in target.points:
		points.append([GameData.name_von(id), id])
	points.sort_custom(func(x, y): return x[0] < y[0])
	var tools: Array = []
	for tid in GameData.TOOLS:
		if Game.tools_owned.has(tid):
			tools.append([Texte.t(GameData.TOOLS[tid].name), tid])
	var doors: Array = []
	for d in target.doors:
		doors.append([Texte.t(d.name), d.id])
	if target.has("panel"):
		doors.append([Texte.t(target.panel.name), target.panel.id])
	for l in target.loot:
		doors.append([Texte.t(l.name), l.id])
	var loot: Array = []
	for l in target.loot:
		loot.append([Texte.t(l.name), l.id])
	var flags: Array = []
	for f in GameData.FLAGS:
		flags.append([GameData.FLAG_NAMES[f], f])
	var guards: Array = []
	for g in target.guards:
		guards.append([Texte.t(g.name), g.id])
	_options = {"points": points, "tools": tools, "doors": doors, "loot": loot, "flags": flags, "guards": guards}

## Ist die Anlage im Plan abgeschaltet (Elektroset auf das Panel)?
func _alarm_aus_im_plan() -> bool:
	for pid in plans:
		for a in plans[pid]:
			if a.t == "TOOL" and a.get("tool", "") == "bypass" and a.get("on", "") == target.panel.id:
				return true
	return false

## Gesicherte Objekte der Alarmanlage mit Anzeigenamen (Türen direkt, Vitrinen über den Beutenamen).
func _gesichert_namen(t: Dictionary) -> String:
	var namen: Array = []
	for g in t.get("gesichert", []):
		namen.append(Texte.t(GameData.name_von(str(g))))
	return ", ".join(namen) if namen.size() > 0 else Texte.t("plan.alarm_keine")

## Jede neue Aktion merken, damit man sie wieder zurücknehmen kann (Original: Escape = RemLastAction).
var _history: Array = []

## Letzte Aktion zurücknehmen. Die Zeit springt an den Anfang dieser Aktion zurück.
func _has_call_car(id: String) -> bool:
	for a in plans.get(id, []):
		if a.t == "CALL_CAR":
			return true
	return false

var _plan_name: LineEdit

var _saved_opt: OptionButton

func _saved_for_target() -> Array:
	return Game.saved_plans.get(target.id, [])

## Jede Einbrecherin muss den Plan am Fluchtwagen beenden.
func all_at_car() -> bool:
	for c in Game.team:
		var pl: Array = plans[c.id]
		if pl.is_empty() or not (pl[-1].t == "MOVE" and pl[-1].get("to", "") == "fluchtwagen"):
			return false
	return not Game.team.is_empty()

func _crew_name(id: String) -> String:
	for c in Game.team:
		if c.id == id:
			return c.name
	return id

var _problems: Array = []  # Aktionen, die in der Vorschau nicht ausgeführt werden können

func _describe(a: Dictionary) -> String:
	match a.t:
		"MOVE":
			if a.has("fine"):
				return Texte.t("res.geh_nach") % Texte.t(_point_label(Vector2i(int(a.fine[0]), int(a.fine[1]))))
			if a.has("cell"):
				return Texte.t("res.geh_nach") % Texte.t(_name_at(a.cell))
			return Texte.t("res.geh_nach") % Texte.t(GameData.name_von(str(a.get("to", "?"))))
		"TOOL":
			return Texte.t("res.werkzeug_an") % [Texte.t(GameData.TOOLS[a.tool].name), Texte.t(GameData.name_von(a.on))]
		"OPEN":
			return Texte.t("plan.oeffnen_obj") % Texte.t(GameData.name_von(a.on))
		"CLOSE":
			return Texte.t("plan.schliessen_obj") % Texte.t(GameData.name_von(a.on))
		"TAKE":
			return Texte.t("plan.beute_nehmen")
		"WAIT":
			return Texte.t("plan.warten_s") % int(a.sec)
		"TREPPE":
			return Texte.t("plan.treppe")
		"CALL_CAR":
			return Texte.t("plan.wagen_rufen")
		"NEUTRALIZE":
			return Texte.t("plan.wache_aus") % _guard_name(a.guard)
		"FLAG_SET":
			return Texte.t("plan.signal") % GameData.FLAG_NAMES.get(a.flag, a.flag)
		_:
			return Texte.t("plan.warte_signal")

# ---------------------------------------------------------------- Aktionen
func _default_action(kind: String) -> Dictionary:
	match kind:
		"MOVE":
			return {"t": "MOVE", "to": _ort_vorschlag()}
		"TOOL":
			return {"t": "TOOL", "tool": _first_tool(), "on": _tuer_vorschlag()}
		"TAKE":
			return {"t": "TAKE", "loot": target.loot[0].id if not target.loot.is_empty() else ""}
		"OPEN":
			return {"t": "OPEN", "on": _tuer_vorschlag()}
		"WAIT":
			return {"t": "WAIT", "sec": 5.0}
		"NEUTRALIZE":
			return {"t": "NEUTRALIZE", "guard": target.guards[0].id if not target.guards.is_empty() else ""}
		"CALL_CAR":
			return {"t": "CALL_CAR"}
		"FLAG_SET":
			return {"t": "FLAG_SET", "flag": "tuer"}
		_:
			return {"t": "FLAG_WAIT", "flag": "tuer"}

## Vorschläge passen zum gewählten Ziel: erster Ort (außer dem Wagen), erste Tür.
func _ort_vorschlag() -> String:
	if target.points.has("aussen_eingang"):
		return "aussen_eingang"
	for k in target.points:
		if k != "fluchtwagen":
			return k
	return ""


func _tuer_vorschlag() -> String:
	return target.doors[0].id if not target.doors.is_empty() else ""


func _first_tool() -> String:
	for tid in GameData.TOOLS:
		if Game.tools_owned.has(tid):
			return tid
	return "lockpick"

func _config() -> Dictionary:
	var team: Array = []
	for c in Game.team:
		team.append(c)
	var skill := float(Game.driver.get("skills", {}).get("FAHREN", 85))
	var car: Dictionary = GameData.car_now(Game.car_id, skill)  # gewähltes Fahrzeug (gemietet oder gekauft)
	# Eintrittskarte: liegt vor, wenn der Informant für dieses Ziel gesprochen wurde
	var karte := bool(Game.quelle_of(str(target.id)).get("inf", false))
	return {"target": target, "team": team, "plans": plans, "car": car, "karte": karte}

## Werkzeugdauer je Person: Dauer und Fähigkeit, die sie dafür mitbringt.
func _duration_lines(res: Dictionary) -> Array:
	var out: Array = []
	var segs: Dictionary = res.get("segments", {})
	for c in Game.team:
		var parts: Array = []
		for seg in segs.get(c.id, []):
			if str(seg.t) != "TOOL" or str(seg.fail) != "" or float(seg.dur) <= 0.0:
				continue
			var a: Dictionary = plans[c.id][int(seg.i)]
			var tool: Dictionary = GameData.TOOLS[a.tool]
			var skill_name := Texte.t(GameData.TOOL_SKILL_KEY.get(tool.type, "skill.technik"))
			parts.append("%s: %s s (%s %d)" % [_describe(a), ("%.1f" % float(seg.dur)).replace(".", "," if Texte.sprache == "de" else "."), skill_name, int(seg.skill)])
		if not parts.is_empty():
			out.append("[color=gray]%s:[/color] %s" % [c.name.split(" ")[0], " · ".join(parts)])
	if out.is_empty():
		return out
	out.insert(0, Texte.t("plan.dauer_je_person"))
	return out

func _status_text(s: String) -> String:
	match s:
		"ENTKOMMEN":
			return Texte.t("status.entkommen")
		"ENTKOMMEN_HEISS":
			return Texte.t("status.entkommen_heiss")
		"GEFASST":
			return Texte.t("status.festgenommen")
		_:
			return Texte.t("status.abbruch")

func _loot_text(list: Array) -> String:
	if list.is_empty():
		return Texte.t("journal.beute_keine")
	return ", ".join(list)

## Möglichkeiten an einer Tür oder Vitrine, abhängig vom Zustand am Ende der Planung
## (Original: verschlossen -> entriegeln oder aufbrechen; entriegelt -> öffnen; offen -> Beute nehmen).
func _object_entries(cell: Vector2i) -> Array:
	var out: Array = []
	var st: Dictionary = _res.get("states", {}).get("%d,%d" % [cell.x, cell.y], {}) if _res != null else {}
	if st.is_empty():
		return out
	var nm: String = str(st.get("id", ""))
	var what := Texte.t("plan.leg_tuer") if st.kind == "door" else str(st.get("word", Texte.t("obj.vitrine")))
	# Crosscheck wie im Original: Objekt nur in Blickrichtung der Person erreichbar (plGetObjectsList)
	var stand := _stand_after(_active)
	if absi(stand.cell.x - cell.x) + absi(stand.cell.y - cell.y) != 1:
		var nb := _neighbor_of(cell, stand.cell)
		out.append(["%s: zu weit weg" % Texte.t(GameData.name_von(nm)), {}, false])
		if nb != Vector2i(-1, -1):
			out.append([Texte.t("plan.neben_gehen") % Texte.t(GameData.name_von(nm)), {"t": "MOVE", "cell": [nb.x, nb.y]}, true])
			# Offene Tür: schließen geht auch aus der Ferne, die Person geht vorher neben die Tür
			if st.kind == "door" and st.open and not st.get("destroyed", false):
				out.append([Texte.t("plan.tuer_schliessen_weit") % what, {"t": "CLOSE", "on": nm, "approach": [nb.x, nb.y]}, true])
		return out
	if st.locked:
		# Alle Werkzeuge für Schlösser, die man besitzt (Original: Werkzeugliste am Objekt)
		var any := false
		for tid in GameData.TOOLS:
			var t: Dictionary = GameData.TOOLS[tid]
			# Schaufenster: nur Glasschneider; Türen und Vitrinen: Schloss-Werkzeuge
			var needs := str(st.get("needs", "schloss"))
			if t.obj != needs or not Game.tools_owned.has(tid):
				continue
			any = true
			var how := Texte.t("plan.aufbrechen") if t.destroys else Texte.t("plan.entriegeln")
			out.append(["%s %s: %s" % [what, how, Texte.t(t.name)], {"t": "TOOL", "tool": tid, "on": nm}, true])
		if not any:
			out.append([Texte.t("plan.kein_passendes_werkzeug") % what, {}, false])
	elif not st.open:
		out.append([Texte.t("plan.von_hand") % what, {"t": "OPEN", "on": nm}, true])
	elif st.kind == "door" and not st.get("destroyed", false):
		out.append([Texte.t("plan.tuer_schliessen") % what, {"t": "CLOSE", "on": nm}, true])
	if st.kind == "case":
		var lid := ""
		for l in target.loot:
			if l.id == nm:
				lid = l.id
		var kg := 0
		for l in target.loot:
			if l.id == nm:
				kg = int(l.weight)
		out.append([Texte.t("plan.beute_nehmen_kg") % [Texte.t(GameData.name_von(nm)), kg] if st.open else Texte.t("plan.beute_erst_oeffnen") % Texte.t(GameData.name_von(nm)), {"t": "TAKE", "loot": lid}, bool(st.open)])
	return out

## Symbol zu einer Aktion im Menü.
func _menu_icon(a: Dictionary) -> Texture2D:
	var name := ""
	match a.get("t", ""):
		"MOVE":
			name = "walk"
		"OPEN", "CLOSE":
			name = "open"
		"TAKE":
			name = "take"
		"NEUTRALIZE":
			name = "guard"
		"TOOL":
			match a.get("tool", ""):
				"lockpick", "schlosstecher", "bohrmaschine":
					name = "lockpick"
				"crowbar", "hammer", "axt", "glasschneider":
					name = "crowbar"
				"bypass":
					name = "alarm"
				"chloroform":
					name = "guard"
				_:
					name = "unlock"
		"CALL_CAR":
			name = "car"
		"WAIT":
			name = "wait"
	return UI.icon(name) if name != "" else null

## Wo die Person nach ihrem bisherigen Plan steht und wohin sie blickt: aus der Simulation (Endstand).
func _stand_after(id: String) -> Dictionary:
	var ends: Dictionary = _res.get("crew_end", {}) if _res != null else {}
	if ends.has(id):
		var e: Dictionary = ends[id]
		return {"cell": Vector2i(int(e.cell[0]), int(e.cell[1])), "face": Vector2i(int(e.face[0]), int(e.face[1]))}
	return {"cell": Sim._v2i(target.points.fluchtwagen), "face": Vector2i(0, 1)}

func _walkable(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.y >= target.map.size() or c.x >= String(target.map[0]).length():
		return false
	var t := String(target.map[c.y]).substr(c.x, 1)
	if not (t == "o" or t == "."):
		return false
	# Vitrinen blockieren den Weg (Original: Gegenstand mit Kollision)
	for l in target.loot:
		if Sim._v2i(l.pos) == c:
			return false
	return true

## Ein begehbares Feld orthogonal neben dem Objekt, möglichst nahe an der Person.
func _neighbor_of(cell: Vector2i, from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = cell + d
		if _walkable(c) and (best == Vector2i(-1, -1) or absi(c.x - from.x) + absi(c.y - from.y) < absi(best.x - from.x) + absi(best.y - from.y)):
			best = c
	return best

## Name eines benannten Ortes an einer Zelle, sonst die Koordinaten.
func _name_at(cell) -> String:
	var v := Sim._v2i(cell)
	for k in target.points:
		if Sim._v2i(target.points[k]) == v:
			return GameData.name_von(k)
	return Texte.t("plan.feld_pos") % [v.x, v.y]

func _fmt(n: int) -> String:
	return GameData.geld(n)

func _guard_name(id: String) -> String:
	for g in target.guards:
		if g.id == id:
			return Texte.t(g.name)
	return id

## Klick auf den Grundriss: Person geht dorthin oder Menü zum Gegenstand.
var _menu: PopupMenu

var _menu_entries: Array = []

var _click_fine := Vector2i(-1, -1)

## Name eines Ortes in der Nähe eines Unterfeldes, sonst die Position in Feldern.
func _point_label(f: Vector2i) -> String:
	var sb := float(Sim.SUB)
	for k in target.points:
		if Vector2(Sim.center(Sim._v2i(target.points[k]))).distance_to(Vector2(f)) <= sb:
			return GameData.name_von(k)
	return Texte.t("plan.punkt_pos") % [f.x / sb, f.y / sb]

## Zwischen zwei Sekundenbildern: Positionen gleiten gleichmäßig (Laufbewegung).
func _interp_frame(frames: Array, t: float) -> Dictionary:
	var fidx := t / Sim.SNAP
	var idx := clampi(int(floor(fidx)), 0, frames.size() - 1)
	var nxt := mini(idx + 1, frames.size() - 1)
	# Keine Zwischenpositionen: gezeichnet wird die gespeicherte Position (liegt immer auf begehbarem Boden)
	var frac := 0.0
	var a: Dictionary = frames[idx]
	var b: Dictionary = frames[nxt]
	var out := a.duplicate(false)
	out.crew = {}
	for id in a.crew:
		var ca: Array = a.crew[id]
		var cb: Array = b.crew.get(id, ca)
		var p := Vector2(ca[0], ca[1]).lerp(Vector2(cb[0], cb[1]), frac)
		var c := ca.duplicate()
		c[0] = p.x
		c[1] = p.y
		out.crew[id] = c
	return out

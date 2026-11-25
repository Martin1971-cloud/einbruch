extends SceneTree
## Prüft die Stufen der Werkzeuge: Jedes Gebäude bekommt die Werkzeuge, die seine Objekte brauchen,
## bevor es erreichbar ist. Die Anforderungen kommen aus den Gebäudedaten (Türen, Fenster, Vitrinen, Alarm, Wachen).
var _fails := 0

const CATS := {
	"glas": ["glasschneider"],
	"tresor": ["schneidbrenner", "stethoskop", "kernbohrer", "dynamit"],
	"alarm": ["bypass"],
	"wache": ["chloroform"],
	"schloss": ["lockpick", "schlosstecher", "bohrmaschine", "crowbar", "hammer", "axt"],
}


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


## Welche Werkzeug-Gruppen ein Gebäude braucht.
func _needs(t: Dictionary) -> Array:
	var out := ["schloss"]
	for d in t.get("doors", []):
		var k: String = str(d.get("kind", ""))
		if k == "glas" and not out.has("glas"):
			out.append("glas")
		if k == "stahl" and not out.has("tresor"):
			out.append("tresor")
	if t.has("fine"):
		for l in t.loot:
			if Sim.plan_tile(t, Vector2i(int(l.pos[0]) * 16 + 8, int(l.pos[1]) * 16 + 8)) == "C" and not out.has("glas"):
				out.append("glas")  # Glasvitrine
	if bool(t.get("glasvitrinen", false)) and not out.has("glas"):
		out.append("glas")
	if t.has("panel") and not out.has("alarm"):
		out.append("alarm")
	if not t.get("guards", []).is_empty() and not out.has("wache"):
		out.append("wache")
	return out


func _stage_of_group(g: String) -> int:
	var best := 99
	for tid in CATS[g]:
		best = mini(best, int(GameData.TOOLS[tid].get("stufe", 0)))
	return best


func _init() -> void:
	for i in range(GameData.ORDER.size()):
		var tid: String = GameData.ORDER[i]
		var t: Dictionary = GameData.TARGETS[tid]
		for g in _needs(t):
			var st := _stage_of_group(g)
			_check(st <= i, "%s (Gebäude %d): %s ab Stufe %d verfügbar" % [tid, i + 1, g, st])
	_check(int(GameData.CARS.limo.stufe) == 0, "Limousine von Anfang an")
	_check(int(GameData.CARS.kombi.stufe) == 1, "Kombi ab dem ersten Erfolg")
	_check(int(GameData.CARS.sport.stufe) == 2, "Sportwagen ab dem zweiten Erfolg")
	_check(GameData.stufe_hint(1) == "ab „Kiosk „Zum Anker““", "Hinweis nach dem ersten Gebäude")
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

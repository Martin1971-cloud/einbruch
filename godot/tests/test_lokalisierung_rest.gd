extends SceneTree
## Prüft die Texte aus Werkzeugladen, Spielständen, Spielende und Journal: jeder Schlüssel in Deutsch und Englisch vorhanden.
var _fails := 0
const SCHLUESSEL := [
	"shop.titel_laden", "shop.titel_autohaus", "shop.werkzeug_kopf", "shop.tool_btn",
	"shop.gekauft", "shop.tool_tip", "shop.gear_btn", "shop.fahrzeug_kopf", "shop.gewaehlt_status",
	"shop.nehmen", "shop.gewaehlt", "shop.zurueckgegeben", "shop.zu_wenig", "shop.car_gekauft",
	"shop.nicht_dein", "shop.car_gewaehlt",
	"slots.titel_neu", "slots.titel", "slots.zurueck", "slots.hinweis", "slots.einbrueche",
	"slots.loeschen", "slots.loeschen_ok", "slots.fehler_hinweis", "slots.ueberschreiben_titel",
	"slots.ueberschreiben_text", "slots.ueberschreiben_ok", "slots.loeschen_titel", "slots.loeschen_text",
	"gameover.hinweis", "gameover.bilanz", "ui.schliessen", "lexikon.suche",
	"journal.summary", "journal.st_entkommen", "journal.st_heiss", "journal.st_gefasst", "journal.st_abbruch",
	"journal.zeile_kopf", "journal.zeile_zahlen", "journal.beute", "journal.beute_keine", "journal.alarm", "journal.fehler",
]


func _check(ok: bool, n: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + n)
	if not ok:
		_fails += 1


func _init() -> void:
	for sprache in ["de", "en"]:
		Texte.sprache = sprache
		var fehlend := []
		for k in SCHLUESSEL:
			var txt := Texte.t(k)
			if txt == k or txt.strip_edges() == "":
				fehlend.append(k)
		_check(fehlend.is_empty(), "Alle Schlüssel vorhanden (%s) %s" % [sprache, str(fehlend)])
	Texte.sprache = "de"
	print("Ergebnis: %d Fehler" % _fails)
	quit(1 if _fails > 0 else 0)

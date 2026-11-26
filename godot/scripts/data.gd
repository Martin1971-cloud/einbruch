class_name GameData
extends RefCounted
## Spieldaten. Alle Namen, Orte und Werte sind eigene Erfindungen.
## Die Mechanik orientiert sich am Spielablauf der Open-Source-Portierung
## (Planung mit Aktions-Timelines, Wachrouten, Lärm, Spuren, Fahndung).


const TOOLS := {
	# Fähigkeit laut Quelle (tcGetNecessaryAbility): "Schlösser", "Kampf", "Elektronik", "Safes", "Sprengstoff" oder "" (jeder).
	# min = Mindeststufe der Fähigkeit (Vorkenntnisse). obj = was damit geöffnet wird: schloss, alarm, glas, tresor, wache.
	"lockpick": {"name": "werkzeug.lockpick.name", "type": "TECH", "ability": "Schlösser", "min": 25, "obj": "schloss", "max": 60, "time": 15.0, "noise": 5.0, "destroys": false, "evidence": 2.0, "price": 300, "stufe": 0},
	"schlosstecher": {"name": "werkzeug.schlosstecher.name", "type": "TECH", "ability": "Schlösser", "min": 15, "obj": "schloss", "max": 40, "time": 10.0, "noise": 4.0, "destroys": false, "evidence": 2.0, "price": 150, "stufe": 0},
	"bohrmaschine": {"name": "werkzeug.bohrmaschine.name", "type": "TECH", "ability": "Schlösser", "min": 35, "obj": "schloss", "max": 75, "time": 8.0, "noise": 45.0, "destroys": true, "evidence": 6.0, "price": 700, "stufe": 2},
	"crowbar": {"name": "werkzeug.crowbar.name", "type": "FORCE", "ability": "", "min": 0, "obj": "schloss", "max": 75, "time": 4.0, "noise": 65.0, "destroys": true, "evidence": 20.0, "price": 200, "stufe": 0},
	"hammer": {"name": "werkzeug.hammer.name", "type": "FORCE", "ability": "", "min": 0, "obj": "schloss", "max": 70, "time": 5.0, "noise": 60.0, "destroys": true, "evidence": 20.0, "price": 60, "stufe": 0},
	"axt": {"name": "werkzeug.axt.name", "type": "FORCE", "ability": "", "min": 0, "obj": "schloss", "max": 80, "time": 5.0, "noise": 70.0, "destroys": true, "evidence": 25.0, "price": 120, "stufe": 1},
	"glasschneider": {"name": "werkzeug.glasschneider.name", "type": "FORCE", "ability": "", "min": 10, "obj": "glas", "max": 40, "time": 8.0, "noise": 5.0, "destroys": true, "evidence": 3.0, "price": 120, "stufe": 0},
	"chloroform": {"name": "werkzeug.chloroform.name", "type": "FORCE", "ability": "Kampf", "min": 0, "obj": "wache", "max": 100, "time": 4.0, "noise": 0.0, "destroys": false, "evidence": 3.0, "price": 250, "stufe": 3},
	"bypass": {"name": "werkzeug.bypass.name", "type": "ELECTRONICS", "ability": "Elektronik", "min": 30, "obj": "alarm", "max": 85, "time": 12.0, "noise": 2.0, "destroys": false, "evidence": 5.0, "price": 900, "stufe": 2},
	"stethoskop": {"name": "werkzeug.stethoskop.name", "type": "TECH", "ability": "Safes", "min": 40, "obj": "tresor", "max": 100, "time": 20.0, "noise": 1.0, "destroys": false, "evidence": 3.0, "price": 500, "stufe": 2},
	"schneidbrenner": {"name": "werkzeug.schneidbrenner.name", "type": "TECH", "ability": "Safes", "min": 55, "obj": "tresor", "max": 100, "time": 30.0, "noise": 30.0, "destroys": true, "evidence": 8.0, "price": 2500, "stufe": 2},
	"kernbohrer": {"name": "werkzeug.kernbohrer.name", "type": "TECH", "ability": "Safes", "min": 65, "obj": "tresor", "max": 100, "time": 40.0, "noise": 60.0, "destroys": true, "evidence": 10.0, "price": 3000, "stufe": 3},
	"dynamit": {"name": "werkzeug.dynamit.name", "type": "TECH", "ability": "Sprengstoff", "min": 60, "obj": "tresor", "max": 100, "time": 10.0, "noise": 120.0, "destroys": true, "evidence": 40.0, "price": 1500, "stufe": 3},
}

const GEAR := {
	"none": {"name": "ausruestung.none.name", "ev": 1.0, "noise": 1.0, "vis": 1.0, "price": 0},
	"gloves": {"name": "ausruestung.gloves.name", "ev": 0.2, "noise": 1.0, "vis": 1.0, "price": 100},
	"sneakers": {"name": "ausruestung.sneakers.name", "ev": 0.5, "noise": 0.4, "vis": 1.0, "price": 150},
	"darksuit": {"name": "ausruestung.darksuit.name", "ev": 1.0, "noise": 1.0, "vis": 0.7, "price": 400},
}

## Personen. Jede Person hat ein Punktebudget von 150, verteilt auf ihre Fähigkeiten (höchstens 100 je Fähigkeit).
## Erfolgreiche Einbrüche steigern die genutzten Fähigkeiten (siehe Game.apply_result).
const BUDGET := 150
const SKILL_CAP := 100
const CREW := [
	{"id": "mira", "name": "Mira Calder", "role": "rolle.mira.role", "skills": {"TECH": 60, "FORCE": 35, "ELECTRONICS": 55}, "fee": 4000, "start": [0, 4]},
	{"id": "ilja", "name": "Ilja Brandt", "role": "rolle.ilja.role", "skills": {"TECH": 30, "FORCE": 20, "ELECTRONICS": 100}, "fee": 6000, "start": [0, 6]},
	{"id": "teo", "name": "Teodor Vance", "role": "rolle.teo.role", "skills": {"TECH": 65, "FORCE": 40, "ELECTRONICS": 45}, "fee": 5000, "start": [0, 5]},
	{"id": "rosa", "name": "Rosa Wendt", "role": "rolle.rosa.role", "skills": {"TECH": 20, "FORCE": 100, "ELECTRONICS": 30}, "fee": 3500, "start": [0, 7]},
	{"id": "greta", "name": "Greta Lind", "role": "rolle.greta.role", "skills": {"FAHREN": 100, "TECH": 50}, "fee": 2500, "start": [19, 5], "driver": true},
	{"id": "otto", "name": "Otto Brenner", "role": "rolle.otto.role", "skills": {"FAHREN": 60, "TECH": 45, "FORCE": 45}, "fee": 1200, "start": [19, 5], "driver": true},
]


## Lexikon: Begriffe des Spiels, in der Reihenfolge der Anzeige.
const LEXIKON := [
	{"term": "lex.0.term", "text": "lex.0.text"},
	{"term": "lex.1.term", "text": "lex.1.text"},
	{"term": "lex.2.term", "text": "lex.2.text"},
	{"term": "lex.3.term", "text": "lex.3.text"},
	{"term": "lex.4.term", "text": "lex.4.text"},
	{"term": "lex.5.term", "text": "lex.5.text"},
	{"term": "lex.6.term", "text": "lex.6.text"},
	{"term": "lex.7.term", "text": "lex.7.text"},
	{"term": "lex.8.term", "text": "lex.8.text"},
	{"term": "lex.9.term", "text": "lex.9.text"},
	{"term": "lex.10.term", "text": "lex.10.text"},
	{"term": "lex.11.term", "text": "lex.11.text"},
	{"term": "lex.12.term", "text": "lex.12.text"},
	{"term": "lex.13.term", "text": "lex.13.text"},
	{"term": "lex.14.term", "text": "lex.14.text"},
	{"term": "lex.15.term", "text": "lex.15.text"},
	{"term": "lex.16.term", "text": "lex.16.text"},
	{"term": "lex.17.term", "text": "lex.17.text"},
	{"term": "lex.18.term", "text": "lex.18.text"},
	{"term": "lex.19.term", "text": "lex.19.text"},
	{"term": "lex.20.term", "text": "lex.20.text"},
	{"term": "lex.21.term", "text": "lex.21.text"},
	{"term": "lex.22.term", "text": "lex.22.text"},
	{"term": "lex.23.term", "text": "lex.23.text"},
]

## Hinweise beim ersten Auftreten einer Mechanik (Text als Daten, nicht im Code).
const HINTS := {
	"glas": {"title": "hinweis.glas.title", "text": "hinweis.glas.text"},
	"treppe": {"title": "hinweis.treppe.title", "text": "hinweis.treppe.text"},
	"laut": {"title": "hinweis.laut.title", "text": "hinweis.laut.text"},
}

## Reihenfolge der Gebäude: jedes erfolgreiche Gebäude schaltet die Werkzeuge und Autos der nächsten Stufe frei.
const ORDER := ["kiosk", "curiosity", "juwelier", "museum"]

## Fahrzeuge: gemietet (Limousine, Miete je Einbruch) oder gekauft. "stufe" = Anzahl erfolgreicher Gebäude, ab der es zu haben ist.
const CARS := {
	"limo": {"id": "limo", "name": "fahrzeug.limo.name", "bild": "res://assets/art/fz_leihwagen.webp", "seite": "res://assets/art/seite_leihwagen.webp", "rent": 1500, "price": 0, "eta_base": 20.0, "speed": 130.0, "ps": 150.0, "laderaum": "mittel", "stufe": 0,
		"info": "fahrzeug.limo.info"},
	"kombi": {"id": "kombi", "name": "fahrzeug.kombi.name", "bild": "res://assets/art/fz_kombi_modern.webp", "seite": "res://assets/art/seite_kombi.webp", "rent": 0, "price": 15000, "eta_base": 16.0, "speed": 160.0, "ps": 200.0, "laderaum": "gross", "stufe": 1,
		"info": "fahrzeug.kombi.info"},
	"sport": {"id": "sport", "name": "fahrzeug.sport.name", "bild": "res://assets/art/fz_sportwagen.webp", "seite": "res://assets/art/seite_sportwagen.webp", "rent": 0, "price": 42000, "eta_base": 12.0, "speed": 220.0, "ps": 400.0, "laderaum": "klein", "stufe": 2,
		"info": "fahrzeug.sport.info"},
}

## Polizeifahrzeuge: die Szene wählt pro Einbruch zufällig eines.
const POLIZEI_SEITE := ["res://assets/art/seite_polizeiauto.webp", "res://assets/art/seite_polizeivan.webp"]

## Was man für eine Stufe braucht (Hinweis im Laden).
static func stufe_hint(stufe: int) -> String:
	if stufe <= 0:
		return ""
	var idx := clampi(stufe - 1, 0, ORDER.size() - 1)
	return Texte.t("stufe.hint") % Texte.t(TARGETS[ORDER[idx]].name)


## Fahrzeug mit Abholzeit: die Zeit richtet sich nach dem Fahren des Fahrers und dem Fahrzeug.
static func car_now(cid: String, skill: float) -> Dictionary:
	var c: Dictionary = CARS.get(cid, CARS.limo).duplicate(true)
	c["eta"] = car_eta(skill) * float(c.eta_base) / 20.0
	# Fahrleistung für die Verfolgung (wie Original tcCalcCarEscape): Geschwindigkeit stärker gewichtet als PS,
	# der Fahrer holt bis zu ein Viertel mehr heraus (Fahrfähigkeit „Fahren“).
	var kmh_part: float = 0.6 * float(c.speed)
	var ps_part: float = 0.4 * float(c.ps) / 3.0
	c["v"] = (kmh_part + ps_part) * (1.0 + 0.25 * clampf(skill, 0.0, 100.0) / 100.0)
	return c

static func driver_by_id(id: String) -> Dictionary:
	for c in CREW:
		if c.id == id:
			return c
	return {}


static func car_eta(skill: float) -> float:
	return 20.0 + (85.0 - skill) * 0.4


## Hinweise zu den Fähigkeiten (Scroll-over).
## Fähigkeit je Werkzeugart (Anzeige und Prüfung). Die Crew hat genau diese Fähigkeiten.
const TOOL_SKILL_KEY := {"TECH": "skill.technik", "FORCE": "skill.kampf", "ELECTRONICS": "skill.elektronik"}

const SKILL_INFO := {
	"TECH": "faehigkeit.TECH.info",
	"FORCE": "faehigkeit.FORCE.info",
	"ELECTRONICS": "faehigkeit.ELECTRONICS.info",
	"FAHREN": "faehigkeit.FAHREN.info",
}

const FLAGS := ["tuer", "alarm"]
const FLAG_NAMES := {"tuer": "signal.tuer", "alarm": "signal.alarm"}

const ACTION_NAMES := {
	"MOVE": "aktion.MOVE",
	"TOOL": "aktion.TOOL",
	"OPEN": "aktion.OPEN",
	"TAKE": "aktion.TAKE",
	"WAIT": "aktion.WAIT",
	"CALL_CAR": "aktion.CALL_CAR",
	"FLAG_SET": "aktion.FLAG_SET",
	"FLAG_WAIT": "aktion.FLAG_WAIT",
	"NEUTRALIZE": "aktion.NEUTRALIZE",
}

## Zielgebäude: "Museum Varenhafen". Karte 20 x 12 Zellen.
## o = Außen, . = Boden, W = Wand, F = Fenster (blockiert, Sicht durch Glas möglich), D = verschlossene Tür.
## Porträts (2D, Krimi-Stil) je Figur, nach Geschlecht und Rolle (weiblich: Mira, Ilja, Rosa, Greta). Dateien in assets/portraits/.
const PORTRAIT := {
	"mira": "beobachterin", "ilja": "technikerin", "teo": "hacker", "rosa": "einbrecherin",
	"greta": "besucher", "otto": "fahrer",
	"informant": "informant", "hehlerin": "hehlerin", "auftraggeber": "auftraggeber", "polizist": "polizist",
}


static func portrait_path(id: String) -> String:
	var key: String = PORTRAIT.get(id, "")
	return "res://assets/portraits/%s.png" % key if key != "" else ""


## Beutetabelle: ein Eintrag je Beutestück. Name, Gewicht (kg), Größe und Icon stehen nur hier.
## Größe für den Fluchtwagen: klein, mittel, gross. Ein Stück passt in den Wagen, wenn seine Größe nicht über
## dem Laderaum liegt (CARS.laderaum). Icons: assets/icons/loot/.
const SIZE_RANK := {"klein": 0, "mittel": 1, "gross": 2}
const ITEMS := {
	"kasse": {"name": "beute.kasse.name", "gewicht": 0.5, "groesse": "mittel", "icon": "kasse"},
	"safe": {"name": "beute.safe.name", "gewicht": 2.5, "groesse": "mittel", "icon": "tresor"},
	"gemaelde": {"name": "beute.gemaelde.name", "gewicht": 2, "groesse": "gross"},
	"landschaft": {"name": "beute.landschaft.name", "gewicht": 2, "groesse": "gross"},
	"portraet": {"name": "beute.portraet.name", "gewicht": 2, "groesse": "gross"},
	"skulptur": {"name": "beute.skulptur.name", "gewicht": 7, "groesse": "gross", "icon": "bronzestatue"},
	"diamant": {"name": "beute.diamant.name", "gewicht": 1, "groesse": "klein"},
	"diamantring": {"name": "beute.diamantring.name", "gewicht": 1, "groesse": "klein"},
	"perlen": {"name": "beute.perlen.name", "gewicht": 1, "groesse": "klein"},
	"gemmen": {"name": "beute.gemmen.name", "gewicht": 1, "groesse": "klein"},
	"muenzen": {"name": "beute.muenzen.name", "gewicht": 3, "groesse": "mittel", "icon": "muenzsammlung"},
	"muenzen_og": {"name": "beute.muenzen_og.name", "gewicht": 3, "groesse": "mittel"},
	"goldbarren": {"name": "beute.goldbarren.name", "gewicht": 6, "groesse": "mittel"},
	"uhren": {"name": "beute.uhren.name", "gewicht": 3, "groesse": "mittel"},
	"besteck": {"name": "beute.besteck.name", "gewicht": 4, "groesse": "mittel"},
	"kassette": {"name": "beute.kassette.name", "gewicht": 5, "groesse": "mittel"},
	"pergamente": {"name": "beute.pergamente.name", "gewicht": 2, "groesse": "mittel"},
	"tresor": {"name": "beute.tresor.name", "gewicht": 6, "groesse": "mittel"},
}


## Setzt Name, Gewicht, Größe und Icon aus ITEMS in die Beute jedes Ziels ein. Die Ziele enthalten nur ID, Position, Wert.
## Anzeigenamen der Türen, des Alarmpanels und der Orte. Beute steht in ITEMS, Wachen und Figuren bei ihren Listen.
const NAMEN := {
	"eingangstuer": "name.eingangstuer", "stahltuer": "name.stahltuer", "schaufenster": "name.schaufenster", "tresortuer": "name.tresortuer",
	"mitteltuer": "name.mitteltuer", "hintertuer": "name.hintertuer", "alarmpanel": "name.alarmpanel",
	"aussen_eingang": "name.aussen_eingang", "aussen_schaufenster": "name.aussen_schaufenster",
	"fluchtwagen": "name.fluchtwagen", "halle": "name.halle", "mittelraum": "name.mittelraum", "tresorraum": "name.tresorraum",
	"korridor": "name.korridor", "verkauf": "name.verkauf", "verkaufsraum": "name.verkaufsraum", "laden": "name.laden",
	"hinterzimmer": "name.hinterzimmer", "treppe_eg": "name.treppe_eg", "treppe_og": "name.treppe_og", "obergeschoss": "name.obergeschoss",
}


## Fakten der Stadtansicht (Schlüssel -> Anzeigename).
const FAKTEN := {"oeffnung": "fakt.name.oeffnung", "wache": "fakt.name.wache", "ueberwachung": "fakt.name.ueberwachung", "besonderheit": "fakt.name.besonderheit"}

## Anzeigename zu einer Objekt-ID (Tür, Panel, Ort, Beute).
static func name_von(id: String) -> String:
	if NAMEN.has(id):
		return NAMEN[id]
	if ITEMS.has(id):
		return ITEMS[id].name
	return id


static func _mit_beute(ziele: Dictionary) -> Dictionary:
	var out := {}
	for zid in ziele:
		var z: Dictionary = ziele[zid].duplicate(true)
		var liste: Array = []
		for e in z.loot:
			var it: Dictionary = ITEMS[e.id]
			var m: Dictionary = e.duplicate(true)
			m["name"] = it.name
			m["weight"] = float(it.gewicht)
			m["size"] = it.groesse
			liste.append(m)
		z["loot"] = liste
		for d in z.doors:
			d["name"] = name_von(d.id)
		if z.has("panel"):
			z.panel["name"] = name_von(z.panel.id)
		out[zid] = z
	return out


static var TARGETS := _mit_beute(ZIELE_ROH)


const ZIELE_ROH := {
	"museum": {
		"id": "museum",
		"glasvitrinen": true,  # Ausstellungskästen aus Glas: Glasschneider nötig (auch wenn man aufbrechen könnte)
		"name": "ziel.museum.name",
		"guard_rate": 170.0,  # Wachrate (Richtwert nach Original, vergleichbares Museum)
		"escape_km": 38.0,    # Fluchtweg in km (Richtwert nach Original)
		"info": "ziel.museum.info",
		"desc": "ziel.museum.desc",
		"map": [
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWWWWWWWWWWWoo",
			"ooF.....W...W....Woo",
			"ooF.....D...D....Woo",
			"ooD.....W...W....Woo",
			"ooF.....W...WWWWWWoo",
			"ooF..............Woo",
			"ooW..............Woo",
			"ooWWWWWWWWWWWWWWWWoo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
		],
		"doors": [
			{"pos": [8, 4], "id": "mitteltuer", "res": 35, "cplx": 45, "locked": true},
			{"pos": [12, 4], "id": "tresortuer", "res": 70, "cplx": 55, "locked": true},
			{"pos": [2, 5], "id": "eingangstuer", "res": 25, "cplx": 35, "locked": true},
		],
		"points": {
			"aussen_eingang": [1, 5],
			"eingangstuer": [2, 5],
			"halle": [5, 5],
			"mitteltuer": [8, 4],
			"mittelraum": [10, 4],
			"tresortuer": [12, 4],
			"tresorraum": [14, 4],
			"korridor": [10, 7],
			"alarmpanel": [10, 7],
			"gemaelde": [5, 3],
			"skulptur": [4, 8],
			"diamant": [15, 3],
			"muenzen": [14, 5],
			"fluchtwagen": [19, 6],
		},
		"rooms": [
			{"name": "ziel.museum.raum.1.name", "pos": [5, 5]},
			{"name": "ziel.museum.raum.2.name", "pos": [10, 4]},
			{"name": "ziel.museum.raum.3.name", "pos": [14, 4]},
			{"name": "ziel.museum.raum.4.name", "pos": [10, 8]},
			{"name": "ziel.museum.raum.5.name", "pos": [1, 7]},
		],
		 "panel": {"id": "alarmpanel", "pos": [10, 7], "res": 50, "cplx": 45},
		# Gesichert: Türen (Name) und Vitrinen (Objekt-ID). Öffnen bei eingeschalteter Anlage löst Alarm aus.
		"gesichert": ["mitteltuer", "tresortuer", "eingangstuer"],
		"sensors": [
			{"name": "ziel.museum.sensor.1.name", "pos": [13, 8], "threshold": 20.0},
		],
		"loot": [
			{"id": "gemaelde", "pos": [5, 3], "value": 60000},
			{"id": "skulptur", "pos": [4, 8], "value": 90000},
			{"id": "diamant", "pos": [15, 3], "value": 150000},
			{"id": "muenzen", "pos": [14, 5], "value": 90000},
		],
		"guards": [
			{"id": "g_ost", "name": "ziel.museum.wache.g_ost.name", "kampf": 45, "type": "INDOOR", "start": [9, 8], "route": [[9, 8], [15, 8], [15, 7], [9, 7]], "vision": 6.0, "hearing": 15.0, "reaction": 4.0, "dwell": 2.0},
			{"id": "g_gal", "name": "ziel.museum.wache.g_gal.name", "kampf": 60, "type": "INDOOR", "start": [4, 3], "route": [[4, 3], [7, 3], [7, 6], [4, 6]], "vision": 6.0, "hearing": 15.0, "reaction": 4.0, "dwell": 2.0},
			{"id": "streife", "name": "ziel.museum.wache.streife.name", "kampf": 0, "type": "STREET", "start": [19, 0], "route": [[19, 0], [19, 11], [11, 11], [11, 0]], "vision": 8.0, "hearing": 40.0, "reaction": 1.5, "dwell": 1.0},
		],
		"facts": [
			["oeffnung", "ziel.museum.fakt.oeffnung"],
			["wache", "ziel.museum.fakt.wache"],
			["ueberwachung", "ziel.museum.fakt.ueberwachung"],
			["besonderheit", "ziel.museum.fakt.besonderheit"],
		],
		"bedarf": {
			"TECH": {"wert": 45, "grund": "ziel.museum.grund.TECH"},
			"FORCE": {"wert": 60, "grund": "ziel.museum.grund.FORCE"},
			"ELECTRONICS": {"wert": 60, "grund": "ziel.museum.grund.ELECTRONICS"},
			"FAHREN": {"wert": 50, "grund": "ziel.museum.grund.FAHREN"},
		},
		"speaker": "Mira Calder",
		"dialog": "ziel.museum.dialog",
		"fence": 0.6,
		"price_intel": 500,
	},
	"kiosk": {
		"id": "kiosk",
		# Original (TCBUILD.DAT, Nr. 10): Polizeizeit 600 s, Lautstärkegrenze 200, keine Wache
		"guard_rate": 10.0,   # Wachrate (Original GRate): bestimmt das Polizeitempo
		"escape_km": 10.0,    # Fluchtweg in km (Original EscapeRouteLength)
		"max_volume": 200.0,
		"name": "ziel.kiosk.name",
		"info": "ziel.kiosk.info",
		"desc": "ziel.kiosk.desc",
		# Grundriss aus den Originaldaten (tools/make_kiosk_grundriss.py, TOBAETA0.DAT / TCBUILD.DAT).
		# Pixel des Originals = Unterfelder (SUB 16). Ein Feld = 16 Pixel.
		"map": [
			"oooooooooooooooooooo",
			"ooooooWWSSWooooooooo",
			"ooooooW.SSCooooooooo",
			"ooooooW...Kooooooooo",
			"ooooooW...Cooooooooo",
			"ooooooW...Cooooooooo",
			"ooooooW...Cooooooooo",
			"ooooooWWDWCooooooooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
		],
		"fine": {
			"sub": 16, "w": 320, "h": 192, "bg": "o",
			"paint": [
				# Neu entworfen: klare Außenwand (8 Unterfelder = 0,5 m), eine Tür (1 m) in der Südwand, Wertschrank an der Nordwand,
				# Tresen mit Kasse an der Ostwand. Raster: 1 Feld = 16 Unterfelder.
				[96, 16, 176, 128, "."],
				[96, 16, 176, 24, "W"],
				[96, 24, 104, 120, "W"],
				[96, 64, 104, 80, "F"],  # Schaufenster (Glas): mit dem Glasschneider öffnen
				[168, 24, 176, 120, "W"],
				[96, 120, 128, 128, "W"],
				[144, 120, 176, 128, "W"],
				[128, 120, 144, 128, "D"],
				[128, 24, 152, 41, "S"],
				[160, 40, 168, 120, "C"],
				[160, 48, 168, 64, "K"],
			],
		},
		"doors": [
			{"pos": [8, 7], "id": "eingangstuer", "res": 20, "cplx": 20, "locked": true},
			{"pos": [6, 4], "id": "schaufenster", "res": 15, "cplx": 15, "locked": true, "kind": "glas"},
		],
		"points": {
			"aussen_eingang": [8, 8],
			"eingangstuer": [8, 7],
			"verkaufsraum": [7, 4],
			"kasse": [10, 3],
			"safe": [8, 2],
			"fluchtwagen": [5, 7],
		},
		"rooms": [
			{"name": "ziel.kiosk.raum.1.name", "pos": [7, 5]},
		],
		"sensors": [],
		"loot": [
			{"id": "kasse", "pos": [10, 3], "value": 6000},
			# Wertschrank (Original: Geld 500 g und eine Zigarrenkiste 2 kg, im selben Behälter)
			# Aufteilung: Geld 16.000 € (500 g), Zigarrenkiste 6.000 € (2 kg). Im Spiel ein Beutestück.
			{"id": "safe", "pos": [8, 2], "value": 22000, "parts": [["ziel.kiosk.teil.safe.0", 16000], ["ziel.kiosk.teil.safe.1", 6000]]},
		],
		"guards": [],
		"facts": [
			["Lage", "ziel.kiosk.fakt.Lage"],
			["oeffnung", "ziel.kiosk.fakt.oeffnung"],
			["wache", "ziel.kiosk.fakt.wache"],
			["ueberwachung", "ziel.kiosk.fakt.ueberwachung"],
			["besonderheit", "ziel.kiosk.fakt.besonderheit"],
		],
		"bedarf": {
			"TECH": {"wert": 25, "grund": "ziel.kiosk.grund.TECH"},
			"FORCE": {"wert": 25, "grund": "ziel.kiosk.grund.FORCE"},
			"FAHREN": {"wert": 20, "grund": "ziel.kiosk.grund.FAHREN"},
		},
		"speaker": "Mira Calder",
		"dialog": "ziel.kiosk.dialog",
		"fence": 0.6,
		"price_intel": 200,
	},
	# Testgebäude (Prüfstand, nicht auf der Stadtkarte): Stahltür, Alarmpanel, Ausstellungskästen.
	# Dient dazu, Animationen und Abläufe zu prüfen. Im Spiel nicht erreichbar.
	"testhaus": {
		"id": "testhaus",
		"guard_rate": 60.0,
		"escape_km": 15.0,
		"max_volume": 150.0,
		"name": "ziel.testhaus.name",
		"info": "ziel.testhaus.info",
		"desc": "ziel.testhaus.desc",
		"map": [
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWWWWWWWWWWooo",
			"ooW......W......Wooo",
			"ooW.C....W......Wooo",
			"ooW......W..C...Wooo",
			"ooW......D......Wooo",
			"ooW......W......Wooo",
			"ooW.T....W......Wooo",
			"ooW......W......Wooo",
			"ooWWWWDWWWWWWWWWWooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWWWWWWWWWWooo",
			"ooW.............Wooo",
			"ooW.C...........Wooo",
			"ooW.............Wooo",
			"ooW.............Wooo",
			"ooW.............Wooo",
			"ooW.T...........Wooo",
			"ooW.............Wooo",
			"ooWWWWWWWWWWWWWWWooo",
			"oooooooooooooooooooo",
		],
		"fine": {
			"sub": 16, "w": 320, "h": 384, "bg": "o",
			"paint": [
				[40, 40, 264, 168, "."],
				[32, 32, 272, 40, "W"],
				[32, 168, 272, 176, "W"],
				[32, 40, 40, 168, "W"],
				[264, 40, 272, 168, "W"],
				[144, 40, 152, 96, "W"],
				[144, 112, 152, 168, "W"],
				[64, 128, 80, 144, "T"],   # Treppe EG (Halle), führt ins Obergeschoss
				[88, 168, 104, 176, "D"],  # Eingangstür (Schloss)
				[144, 96, 152, 112, "D"],  # Stahltür (Schneidbrenner oder Stethoskop)
				[64, 64, 80, 80, "C"],     # Ausstellungskasten in der Halle
				[192, 80, 208, 96, "C"],   # Ausstellungskasten im Tresorraum
				[40, 232, 264, 360, "."],
				[32, 224, 272, 232, "W"],
				[32, 360, 272, 368, "W"],
				[32, 232, 40, 360, "W"],
				[264, 232, 272, 360, "W"],
				[64, 320, 80, 336, "T"],   # Treppe OG
				[64, 256, 80, 272, "C"],   # Münzvitrine im Obergeschoss
			],
		},
		"doors": [
			{"pos": [6, 10], "id": "eingangstuer", "res": 30, "cplx": 35, "locked": true},
			{"pos": [9, 6], "id": "stahltuer", "res": 80, "cplx": 60, "locked": true, "kind": "stahl"},
		],
		 "panel": {"id": "alarmpanel", "pos": [3, 3], "res": 45, "cplx": 40},
		"gesichert": ["eingangstuer", "stahltuer"],
		"scheinwerfer": [[6, 11]],
		"sirene": [9, 1],
		"points": {
			"aussen_eingang": [6, 11],
			"eingangstuer": [6, 10],
			"halle": [5, 6],
			"stahltuer": [9, 6],
			"tresorraum": [12, 7],
			"alarmpanel": [3, 3],
			"fluchtwagen": [3, 11],
			"treppe_eg": [4, 8],
			"treppe_og": [4, 20],
			"obergeschoss": [6, 18],
		},
		"rooms": [
			{"name": "ziel.testhaus.raum.1.name", "pos": [5, 6]},
			{"name": "ziel.testhaus.raum.2.name", "pos": [12, 7]},
			{"name": "ziel.testhaus.raum.3.name", "pos": [6, 18]},
		],
		# Treppe: EG-Feld [4, 8] und OG-Feld [4, 20] sind verbunden
		"treppen": [[4, 8, 4, 20]],
		# Etagen: Kartenzeilen von bis (ohne Ende). Ohne "floors" gibt es nur einen Grundriss.
		"floors": [{"id": "eg", "name": "EG", "rows": [0, 13]}, {"id": "og", "name": "OG", "rows": [13, 24]}],
		"sensors": [
			{"name": "ziel.testhaus.sensor.1.name", "pos": [5, 8], "threshold": 20.0},
		],
		"loot": [
			{"id": "diamant", "pos": [4, 4], "value": 150000},
			{"id": "goldbarren", "pos": [12, 5], "value": 240000},
			{"id": "muenzen_og", "pos": [4, 16], "value": 80000},
			# Gemälde hängt an der Wand: ohne Werkzeug abnehmbar (open), Bild wird als Wandbild gezeigt
			{"id": "gemaelde", "pos": [3, 6], "value": 60000, "open": true, "wall": true},
		],
		"guards": [
			{"id": "g_tres", "name": "ziel.testhaus.wache.g_tres.name", "kampf": 50, "type": "INDOOR", "start": [11, 8], "route": [[11, 8], [13, 8], [13, 4], [11, 4]], "vision": 6.0, "hearing": 15.0, "reaction": 4.0, "dwell": 2.0},
		],
		"facts": [
			["Lage", "ziel.testhaus.fakt.Lage"],
			["oeffnung", "ziel.testhaus.fakt.oeffnung"],
			["wache", "ziel.testhaus.fakt.wache"],
			["ueberwachung", "ziel.testhaus.fakt.ueberwachung"],
		],
		"bedarf": {
			"TECH": {"wert": 40, "grund": "ziel.testhaus.grund.TECH"},
			"FORCE": {"wert": 50, "grund": "ziel.testhaus.grund.FORCE"},
			"ELECTRONICS": {"wert": 50, "grund": "ziel.testhaus.grund.ELECTRONICS"},
			"FAHREN": {"wert": 40, "grund": "ziel.testhaus.grund.FAHREN"},
		},
		"speaker": "Mira Calder",
		"dialog": "ziel.testhaus.dialog",
		"fence": 0.6,
		"price_intel": 0,
	},
	# Kuriositätenladen (Nr. 16 nach Original „Old Curiosity Shop“, eigene Ausgestaltung): zwei Etagen, Fenster,
	# Holztüren, Vitrinen, Gemälde an der Wand. Keine Wache (Original: Wachstärke 0). Erster Schritt nach dem Kiosk.
	"curiosity": {
		"id": "curiosity",
		"guard_rate": 90.0,
		"escape_km": 20.0,
		"max_volume": 170.0,
		"name": "ziel.curiosity.name",
		"info": "ziel.curiosity.info",
		"desc": "ziel.curiosity.desc",
		"map": [
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWFWWWWWWWWooo",
			"ooW......W......Wooo",
			"ooW.C.C..W......Wooo",
			"ooW......W......Wooo",
			"ooW......D......Wooo",
			"ooW......W......Wooo",
			"ooW.T....W..S...Wooo",
			"ooW......W......Wooo",
			"ooWWWWDWWWWWWWWWWooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWWWWWWWWWWooo",
			"ooW.............Wooo",
			"ooW.C...........Wooo",
			"ooW.............Wooo",
			"ooW.........C...Wooo",
			"ooW.............Wooo",
			"ooW.T...........Wooo",
			"ooW.............Wooo",
			"ooWWWWWWWWWWWWWWWooo",
			"oooooooooooooooooooo",
		],
		"fine": {
			"sub": 16, "w": 320, "h": 384, "bg": "o",
			"paint": [
				[40, 40, 264, 168, "."],
				[32, 168, 272, 176, "W"],
				[32, 32, 272, 40, "W"],
				[32, 40, 40, 168, "W"],
				[264, 40, 272, 168, "W"],
				[144, 40, 152, 96, "W"],
				[144, 112, 152, 168, "W"],
				[128, 32, 144, 40, "F"],   # Schaufenster zur Gasse (Glasschneider)
				[64, 128, 80, 144, "T"],   # Treppe EG -> OG
				[88, 168, 104, 176, "D"],  # Eingangstür (Schloss)
				[144, 96, 152, 112, "D"],  # Hintertür (Holztür, Schloss)
				[64, 64, 80, 80, "C"],     # Vitrine Uhrensammlung
				[96, 64, 112, 80, "C"],    # Vitrine Silberbesteck
				[192, 128, 208, 144, "S"], # Geldkassette im Hinterzimmer
				[40, 232, 264, 360, "."],  # Obergeschoss
				[32, 224, 272, 232, "W"],
				[32, 360, 272, 368, "W"],
				[32, 232, 40, 360, "W"],
				[264, 232, 272, 360, "W"],
				[64, 320, 80, 336, "T"],   # Treppe OG
				[64, 256, 80, 272, "C"],   # Vitrine Gemmensammlung
				[192, 288, 208, 304, "C"], # Vitrine Pergamente
			],
		},
		"doors": [
			{"pos": [6, 10], "id": "eingangstuer", "res": 30, "cplx": 35, "locked": true},
			{"pos": [9, 6], "id": "hintertuer", "res": 25, "cplx": 25, "locked": true},
			{"pos": [8, 2], "id": "schaufenster", "res": 15, "cplx": 15, "locked": true, "kind": "glas"},
		],
		"floors": [{"id": "eg", "name": "EG", "rows": [0, 13]}, {"id": "og", "name": "OG", "rows": [13, 24]}],
		"treppen": [[4, 8, 4, 20]],
		"points": {
			"aussen_eingang": [6, 11],
			"eingangstuer": [6, 10],
			"aussen_schaufenster": [8, 1],
			"schaufenster": [8, 2],
			"laden": [5, 6],
			"hintertuer": [9, 6],
			"hinterzimmer": [12, 6],
			"treppe_eg": [4, 8],
			"treppe_og": [4, 20],
			"obergeschoss": [6, 18],
			"fluchtwagen": [3, 11],
		},
		"rooms": [
			{"name": "ziel.curiosity.raum.1.name", "pos": [5, 6]},
			{"name": "ziel.curiosity.raum.2.name", "pos": [12, 6]},
			{"name": "ziel.curiosity.raum.3.name", "pos": [6, 18]},
		],
		"sensors": [],
		"loot": [
			{"id": "uhren", "pos": [4, 4], "value": 15000},
			{"id": "besteck", "pos": [6, 4], "value": 10000},
			{"id": "landschaft", "pos": [3, 6], "value": 12000, "open": true, "wall": true},
			{"id": "kassette", "pos": [12, 8], "value": 20000},
			{"id": "gemmen", "pos": [4, 16], "value": 25000},
			{"id": "pergamente", "pos": [12, 18], "value": 15000},
			{"id": "portraet", "pos": [3, 18], "value": 18000, "open": true, "wall": true},
		],
		"guards": [],
		"facts": [
			["Lage", "ziel.curiosity.fakt.Lage"],
			["oeffnung", "ziel.curiosity.fakt.oeffnung"],
			["wache", "ziel.curiosity.fakt.wache"],
			["ueberwachung", "ziel.curiosity.fakt.ueberwachung"],
			["besonderheit", "ziel.curiosity.fakt.besonderheit"],
		],
		"bedarf": {
			"TECH": {"wert": 40, "grund": "ziel.curiosity.grund.TECH"},
			"FORCE": {"wert": 25, "grund": "ziel.curiosity.grund.FORCE"},
			"FAHREN": {"wert": 30, "grund": "ziel.curiosity.grund.FAHREN"},
		},
		"speaker": "Mira Calder",
		"dialog": "ziel.curiosity.dialog",
		"fence": 0.6,
		"price_intel": 300,
	},
	# Juwelier (Nr. 14 nach Original, eigene Ausgestaltung): ein Geschoss, Schaufenster, Alarmpanel, Mikrofon,
	# Stahltür zum Tresorraum. Keine Wache (Original: Wachstärke 0), aber Alarm. Gebäude 3 nach dem Laden.
	"juwelier": {
		"id": "juwelier",
		"guard_rate": 100.0,
		"escape_km": 13.0,
		"max_volume": 150.0,
		"name": "ziel.juwelier.name",
		"info": "ziel.juwelier.info",
		"desc": "ziel.juwelier.desc",
		"map": [
			"oooooooooooooooooooo",
			"oooooooooooooooooooo",
			"ooWWWWWWFWWWWWWWWooo",
			"ooW......W......Wooo",
			"ooW.C.C..W......Wooo",
			"ooW......W......Wooo",
			"ooW......D......Wooo",
			"ooW......W......Wooo",
			"ooW......W..S...Wooo",
			"ooW......W......Wooo",
			"ooWWWWDWWWWWWWWWWooo",
			"oooooooooooooooooooo",
		],
		"fine": {
			"sub": 16, "w": 320, "h": 192, "bg": "o",
			"paint": [
				[40, 40, 264, 168, "."],
				[32, 32, 272, 40, "W"],
				[32, 168, 272, 176, "W"],
				[32, 40, 40, 168, "W"],
				[264, 40, 272, 168, "W"],
				[144, 40, 152, 96, "W"],
				[144, 112, 152, 168, "W"],
				[128, 32, 144, 40, "F"],   # Schaufenster zum Markt (Glasschneider)
				[88, 168, 104, 176, "D"],  # Eingangstür (Schloss)
				[144, 96, 152, 112, "D"],  # Stahltür zum Tresorraum
				[64, 64, 80, 80, "C"],     # Vitrine Diamantring
				[96, 64, 112, 80, "C"],    # Vitrine Perlenkette
				[192, 128, 208, 144, "S"], # Tresor im Tresorraum
			],
		},
		"doors": [
			{"pos": [6, 10], "id": "eingangstuer", "res": 35, "cplx": 40, "locked": true},
			{"pos": [9, 6], "id": "stahltuer", "res": 80, "cplx": 60, "locked": true, "kind": "stahl"},
			{"pos": [8, 2], "id": "schaufenster", "res": 20, "cplx": 20, "locked": true, "kind": "glas"},
		],
		 "panel": {"id": "alarmpanel", "pos": [3, 3], "res": 50, "cplx": 45},
		"gesichert": ["eingangstuer", "stahltuer", "schaufenster", "diamantring", "perlen", "tresor"],
		"sensors": [
			{"name": "ziel.juwelier.sensor.1.name", "pos": [5, 8], "threshold": 25.0},
			# Glasbruchmelder: reagiert schon auf ein zerbrochenes Schaufenster (niedrige Schwelle)
			{"name": "ziel.juwelier.sensor.2.name", "pos": [8, 3], "threshold": 15.0},
		],
		"points": {
			"aussen_eingang": [6, 11],
			"eingangstuer": [6, 10],
			"aussen_schaufenster": [8, 1],
			"schaufenster": [8, 2],
			"verkauf": [5, 6],
			"alarmpanel": [3, 3],
			"stahltuer": [9, 6],
			"tresorraum": [12, 6],
			"fluchtwagen": [3, 11],
		},
		"rooms": [
			{"name": "ziel.juwelier.raum.1.name", "pos": [5, 6]},
			{"name": "ziel.juwelier.raum.2.name", "pos": [12, 6]},
		],
		"loot": [
			{"id": "diamantring", "pos": [4, 4], "value": 50000},
			{"id": "perlen", "pos": [6, 4], "value": 35000},
			{"id": "tresor", "pos": [12, 8], "value": 95000},
		],
		"guards": [],
		"facts": [
			["Lage", "ziel.juwelier.fakt.Lage"],
			["oeffnung", "ziel.juwelier.fakt.oeffnung"],
			["wache", "ziel.juwelier.fakt.wache"],
			["ueberwachung", "ziel.juwelier.fakt.ueberwachung"],
			["besonderheit", "ziel.juwelier.fakt.besonderheit"],
		],
		"bedarf": {
			"TECH": {"wert": 45, "grund": "ziel.juwelier.grund.TECH"},
			"ELECTRONICS": {"wert": 50, "grund": "ziel.juwelier.grund.ELECTRONICS"},
			"FORCE": {"wert": 40, "grund": "ziel.juwelier.grund.FORCE"},
			"FAHREN": {"wert": 35, "grund": "ziel.juwelier.grund.FAHREN"},
		},
		"speaker": "Mira Calder",
		"dialog": "ziel.juwelier.dialog",
		"fence": 0.6,
		"price_intel": 400,
	},
}

## Beutewert-Spanne: Abweichung je Stufe (0 = genau)
const STAGE_LOOT_SPREAD := {0: 0.4, 1: 0.15, 2: 0.0}


## Beutewert als Text, je nach Ermittlungsstufe. Stufe 2 ist genau.
static func loot_text(target: Dictionary, lvl: int) -> String:
	var total := 0
	for l in target.loot:
		total += int(l.value)
	var spread: float = float(STAGE_LOOT_SPREAD.get(lvl, 0.4))
	if spread <= 0.0:
		return "%s €" % _grp(total)
	var lo := int(round(total * (1.0 - spread) / 1000.0)) * 1000
	var hi := int(round(total * (1.0 + spread) / 1000.0)) * 1000
	return "%s – %s €" % [_grp(lo), _grp(hi)]


## Polizeizeit nach Alarm = Reaktionszeit + Fahrzeit vom Revier.
## Fahrzeit (Minuten) = Luftlinie (km) x 2,4 + 3 (Umweg durch das Straßennetz, Verkehr, Ausrücken).
## Tabelle POLIZEI: reaktion = Minuten bis die Streife ausrückt, km = Luftlinie vom Polizeirevier (Karte ~3 km breit).
## Die Spanne gilt nur für die Fahrt (FAHRT_SPANNE). Mit Informant steht der genaue Wert da.
const FAHRT_FAKTOR := 2.4
const FAHRT_PUFFER := 3.0
const FAHRT_SPANNE := 0.2
## Lauter Alarm (Mikrofon, Glasbruch, Lärm, Wache): die Streife ist in der Nähe, Eintreffen in dieser Spanne (Sekunden).
const LAUT_MIN_S := 120.0
const LAUT_MAX_S := 240.0
const POLIZEI := {
	"kiosk": {"reaktion": 5.0, "km": 0.84},
	"testhaus": {"reaktion": 5.0, "km": 0.8},  # Prüfgebäude, nicht auf der Karte
	"curiosity": {"reaktion": 5.0, "km": 0.85},
	"juwelier": {"reaktion": 5.0, "km": 0.86},
	"museum": {"reaktion": 5.0, "km": 0.6},
}


## Polizeizeit eines Gebäudes: zeit in Sekunden (Simulation), lo/hi in Minuten (Spanne ohne Informant).
static func polizei(id: String) -> Dictionary:
	if not POLIZEI.has(id):
		return {"zeit": 60.0, "reaktion_s": 60.0, "fahrt_s": 0.0, "lo": 1.0, "hi": 1.0}  # ohne Eintrag: Standard von 60 s, wie bisher
	var p: Dictionary = POLIZEI[id]
	var fahrt: float = float(p.km) * FAHRT_FAKTOR + FAHRT_PUFFER
	var min_: float = float(p.reaktion) + fahrt
	return {"zeit": min_ * 60.0, "reaktion_s": float(p.reaktion) * 60.0, "fahrt_s": fahrt * 60.0, "lo": float(p.reaktion) + fahrt * (1.0 - FAHRT_SPANNE), "hi": float(p.reaktion) + fahrt * (1.0 + FAHRT_SPANNE)}


## Polizeizeit nach Alarm als Text: genau mit Informant, sonst als Spanne in Minuten.
static func police_text(target: Dictionary, exakt: bool) -> String:
	var p := polizei(str(target.get("id", "")))
	if exakt:
		return "%d Min." % maxi(1, roundi(float(p.zeit) / 60.0))
	var lo := maxi(1, roundi(float(p.lo)))
	var hi := maxi(lo, roundi(float(p.hi)))
	return "%d–%d Min." % [lo, hi]


static func _grp(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Weitere Orte der Stadt (auf dem Stadtplan, noch nicht spielbar).
const OTHER_PLACES := [
	{"id": "villa", "name": "ort.villa.name", "pos": [0.913, 0.284], "info": "ort.villa.info"},
	{"id": "bank", "name": "ort.bank.name", "pos": [0.513, 0.273], "info": "ort.bank.info"},
	{"id": "auktion", "name": "ort.auktion.name", "pos": [0.700, 0.420], "info": "ort.auktion.info"},
	{"id": "theater", "name": "ort.theater.name", "pos": [0.373, 0.462], "info": "ort.theater.info"},
	{"id": "hafen", "name": "ort.hafen.name", "pos": [0.833, 0.569], "info": "ort.hafen.info"},
	{"id": "bahnhof", "name": "ort.bahnhof.name", "pos": [0.143, 0.237], "info": "ort.bahnhof.info"},
	{"id": "schloss", "name": "ort.schloss.name", "pos": [0.837, 0.083], "info": "ort.schloss.info"},
	{"id": "buero", "name": "ort.buero.name", "pos": [0.900, 0.840], "info": "ort.buero.info"},
	{"id": "archiv", "name": "ort.archiv.name", "pos": [0.180, 0.830], "info": "ort.archiv.info"},
	{"id": "labor", "name": "ort.labor.name", "pos": [0.280, 0.900], "info": "ort.labor.info"},
]


## Bedarf des Ziels nach Sicherungsstufe: je Stufe +5 auf jede Anforderung.
static func bedarf_now(stufe: int, id := "museum") -> Dictionary:
	var out := {}
	for k in TARGETS[id].bedarf:
		var b: Dictionary = TARGETS[id].bedarf[k].duplicate(true)
		b.wert = mini(SKILL_CAP, int(b.wert) + 5 * stufe)
		out[k] = b
	return out


## Ziel nach Sicherungsstufe: Schlösser und Alarmpanel schwerer, Mikrofone empfindlicher.
static func target_now(stufe: int, id := "museum") -> Dictionary:
	var t: Dictionary = TARGETS[id].duplicate(true)
	for d in t.doors:
		d.cplx = float(d.cplx) + 5.0 * stufe
	if t.has("panel"):
		t.panel.cplx = float(t.panel.cplx) + 5.0 * stufe
	for sn in t.sensors:
		sn.threshold = float(sn.threshold) - 2.0 * stufe
	t.bedarf = bedarf_now(stufe, id)
	t.stufe = stufe
	return t


## Einrichtung ohne Beute (Deko): nur zur Ansicht, nicht anklickbar, blockiert keine Wege.
## rect in Unterfeldern (1 Feld = 16), kind: tisch, stuhl, regal, bild, pflanze, kiste.
const DEKO := {
	"kiosk": [
		{"kind": "regal", "rect": [104, 24, 120, 40]},
		{"kind": "tisch", "rect": [108, 84, 124, 100]},
		{"kind": "stuhl", "rect": [108, 102, 116, 110]},
		{"kind": "pflanze", "rect": [154, 24, 162, 34]},
		{"kind": "bild", "rect": [104, 96, 107, 112]},
	],
	"curiosity": [
		{"kind": "regal", "rect": [48, 40, 72, 52]},
		{"kind": "tisch", "rect": [200, 96, 232, 120]},
		{"kind": "stuhl", "rect": [204, 122, 212, 130]},
		{"kind": "stuhl", "rect": [220, 122, 228, 130]},
		{"kind": "pflanze", "rect": [246, 140, 256, 150]},
		{"kind": "bild", "rect": [256, 72, 259, 96]},
	],
	"juwelier": [
		{"kind": "regal", "rect": [200, 40, 240, 52]},
		{"kind": "kiste", "rect": [44, 124, 68, 134]},
		{"kind": "bild", "rect": [100, 40, 124, 43]},
		{"kind": "pflanze", "rect": [246, 140, 256, 150]},
		{"kind": "bild", "rect": [256, 60, 259, 90]},
	],
}

class_name Texte
extends RefCounted
## Texte des Spiels nach Sprache. Ein Schlüssel, je Sprache ein Text. Fehlt ein Text, bleibt der Schlüssel sichtbar.
## Neue Texte kommen hierher statt in den Code. Die Sprache wird über Texte.sprache gesetzt (Standard: de).

static var sprache := "de"

const TABELLE := {
	"de": {
		"app.titel": "DER EINBRUCH",
		"app.untertitel": "EINE HEIST-SIMULATION",
		"menue.neu": "Neues Spiel",
		"menue.fortsetzen": "Fortsetzen",
		"menue.staende": "Spielstände",
		"menue.beenden": "Beenden",
		"app.hinweis_fiktiv": "Privates Projekt · Alle Namen, Orte und Figuren sind frei erfunden.",
		"nav.stadt": "Stadt",
		"nav.organisation": "Organisation",
		"nav.planung": "Planung",
		"nav.ausfuehrung": "Ausführung",
		"nav.journal": "Journal (J)",
		"nav.optionen": "Optionen (O)",
		"nav.lexikon": "Lexikon (L)",
		"stadt.fahndung": "Fahndung",
		"stadt.stadtplan": "STADTPLAN VARENHAFEN",
		"stadt.ort": "ORT",
		"stadt.umsehen": "Umsehen (1 Std.)",
		"stadt.sprechen": "Sprechen (Informant, 500 €)",
		"stadt.nachdenken": "Nachdenken",
		"stadt.gehen": "Gehen … (Planung)",
		"stadt.warten": "Warten … (bis morgen früh)",
		"stadt.ereignisse": "Ereignisse",
		"stadt.braucht": "Was der Einbruch braucht",
		"stadt.polizeizeit": "Polizeizeit",
		"stadt.polizeizeit_wert": "etwa 1 Minute nach Alarm",
		"ort.laden": "Werkzeugladen „Stahlmann“",
		"ort.autohaus": "Autohaus „Kaiser“",
		"ort.laden_info": "Werkzeug und Kleidung kaufen.",
		"ort.autohaus_info": "Fahrzeuge kaufen oder mieten.",
		"spielende.titel": "Das Spiel ist vorbei",
		"spielende.fahndung": "Die Fahndung hat dich eingeholt. Die Polizei kennt dein Gesicht und deine Methode.",
		"spielende.pleite.titel": "Pleite",
		"spielende.pleite": "Du hast nicht mehr genug Geld, um einen Einbruch mit dem günstigsten Team zu finanzieren.",
		"spielende.neu": "Neues Spiel",
		"spielende.titelbild": "Zum Titelbild",
		"spielstaende.titel": "Spielstände",
		"optionen.titel": "Optionen",
		"optionen.musik": "Musik",
		"optionen.schliessen": "Schließen (Esc)",
		"journal.titel": "Journal",
		"journal.leer": "Noch kein Einbruch. Nach dem ersten Einbruch erscheint hier das Ergebnis.",
		"fehler.allgemein": "Etwas ist schiefgelaufen. Das Spiel läuft weiter. Der Stand wurde nicht verändert.",
	},
	"en": {
		"app.titel": "THE HEIST",
		"app.untertitel": "A HEIST SIMULATION",
		"menue.neu": "New game",
		"menue.fortsetzen": "Continue",
		"menue.staende": "Save slots",
		"menue.beenden": "Quit",
		"app.hinweis_fiktiv": "Private project · All names, places and characters are fictional.",
		"nav.stadt": "Town",
		"nav.organisation": "Organisation",
		"nav.planung": "Planning",
		"nav.ausfuehrung": "Execution",
		"nav.journal": "Journal (J)",
		"nav.optionen": "Options (O)",
		"nav.lexikon": "Glossary (L)",
		"stadt.fahndung": "Manhunt",
		"stadt.stadtplan": "CITY MAP VARENHAFEN",
		"stadt.ort": "PLACE",
		"stadt.umsehen": "Look around (1 h)",
		"stadt.sprechen": "Talk to informant (500 €)",
		"stadt.nachdenken": "Think",
		"stadt.gehen": "Go … (planning)",
		"stadt.warten": "Wait … (until morning)",
		"stadt.ereignisse": "Events",
		"stadt.braucht": "What the heist needs",
		"stadt.polizeizeit": "Police time",
		"stadt.polizeizeit_wert": "about 1 minute after the alarm",
		"ort.laden": "Tool shop „Stahlmann“",
		"ort.autohaus": "Car dealer „Kaiser“",
		"ort.laden_info": "Buy tools and clothing.",
		"ort.autohaus_info": "Buy or rent vehicles.",
		"spielende.titel": "Game over",
		"spielende.fahndung": "The manhunt caught up with you. The police know your face and your method.",
		"spielende.pleite.titel": "Bankrupt",
		"spielende.pleite": "You no longer have enough money to finance a heist with the cheapest team.",
		"spielende.neu": "New game",
		"spielende.titelbild": "Title screen",
		"optionen.titel": "Options",
		"optionen.musik": "Music",
		"optionen.schliessen": "Close (Esc)",
		"journal.titel": "Journal",
		"journal.leer": "No heist yet. The result appears here after the first one.",
	},
}


## Text zu einem Schlüssel in der eingestellten Sprache.
static func t(schluessel: String) -> String:
	var tab: Dictionary = TABELLE.get(sprache, TABELLE["de"])
	if tab.has(schluessel):
		return str(tab[schluessel])
	if TABELLE["de"].has(schluessel):
		return str(TABELLE["de"][schluessel])
	return schluessel

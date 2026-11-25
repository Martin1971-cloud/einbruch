class_name Texte
extends RefCounted
## Texte des Spiels nach Sprache. Ein Schlüssel, je Sprache ein Text. Fehlt ein Text, bleibt der Schlüssel sichtbar.
## Neue Texte kommen hierher statt in den Code. Die Sprache wird über Texte.sprache gesetzt (Standard: de).

static var sprache := "de"

const TABELLE := {
	"de": {
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

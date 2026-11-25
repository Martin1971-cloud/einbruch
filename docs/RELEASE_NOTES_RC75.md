# Release Candidate RC75 – Der Einbruch

## Animationen
- Personen zeigen im Grundriss (Vorschau und Abspielen) und in 3D, was sie tun: Werkzeug am Schloss (Funken), Öffnen (Bogen), Aufnehmen (Bücken, Punkt steigt auf).

## Ansicht folgt der Person
- Auswahl einer Person gleitet die Ansicht auf sie (Stufe 2).
- Beim Abspielen folgt die Ansicht der Person. Verschieben beendet das Folgen, erneutes Wählen stellt es wieder her.

## Beute
- Ohne Maus: goldener Markierungspunkt mit Wertschild. Mit Maus: zusätzlich das Bild.

## Schrift
- Der Schrift-Regler (A−/A+) wirkt auf Team, Ablaufplan, Vorschau, Knöpfe der Zeitleiste und die Zeitachse. Die Namensspalte der Zeitachse wächst mit.

## Verfolgung und Fahrzeuge (wie RC74)
- Limousine und Sportwagen mit Geschwindigkeit und PS. Die Polizei holt den Wagen auf der Fluchtstrecke ein oder nicht, abhängig von Wachrate und Strecke. Werte sind Richtwerte.

## Laden und Autohaus (wie RC74)
- Werkzeugladen „Stahlmann“ und Autohaus „Kaiser“ auf der Stadtkarte.

## Tests
- Alle 27 Tests in `tests/` bestehen.

## Bekannte Abweichungen vom Original
- Gebäudewert: Original 380, im Spiel 20.000 € (siehe `docs/BALANCING_TODO.md`).
- Tresen: Original zwei, im Spiel einer.
- Grundriss: eigener Entwurf.
- Fahrzeugwerte und Verfolgung: Richtwerte.

## Offen
- Balancing aller Gebäude.
- Kleine Anzeigefehler: Zeitanzeige am Abspielkopf und Namensfeld oben bei großer Schrift.
- Ortsmarken auf der Stadtkarte sind Schätzungen. Nur Kiosk und Museum sind spielbar.

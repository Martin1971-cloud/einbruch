# Release Candidate RC74 – Der Einbruch

## Ansicht folgt der Person
- Wählt man eine Person, gleitet die Ansicht auf sie (Stufe 2) und zentriert sie.
- Beim Abspielen folgt die Ansicht der Position der gewählten Person aus der Simulation.
- Verschieben mit der Maus beendet das Folgen. Wählt man die Person erneut, folgt die Ansicht wieder.
- „Alles“ und Doppelklick zeigen weiter die ganze Karte.

## Verfolgung und Fahrzeuge
- Fahrzeuge mit Geschwindigkeit und PS (Limousine 130 km/h / 150 PS, Sportwagen 220 km/h / 400 PS). Der Fahrer holt über seine Fahrfähigkeit bis zu 25 % mehr heraus.
- Polizeitempo: 140 km/h + 0,25 × Wachrate des Ziels (Kiosk 10, Museum 170).
- Fluchtstrecke: Kiosk 10 km, Museum 38 km.
- Holt die Polizei den Wagen auf der Strecke ein, endet der Einbruch mit „GEFASST“. Knapp entkommen bleibt „ENTKOMMEN“ mit Hinweis.
- Werte sind Richtwerte, orientiert an realen Fahrzeugen, nicht aus dem Original übernommen.

## Laden und Autohaus (vorheriger Stand)
- Werkzeugladen „Stahlmann“ und Autohaus „Kaiser“ auf der Stadtkarte, mit Bildern.
- Organisation zeigt nur noch den Besitz. Auswahl (Team, Kleidung) bleibt beim Zurückkehren erhalten.

## Beute und Türen
- Alle Beutestücke sind dauerhaft sichtbar, mit Ring und Wertschild.
- Türblatt in 3D ohne Streifenmuster.

## Tests
- Alle Tests in `tests/` bestehen, u.a. test_fokus, test_verfolgung, test_autohaus, test_kauf, test_kleidung, test_zoom, test_durchlauf.

## Bekannte Abweichungen vom Original
- Gebäudewert: Original 380, im Spiel 20.000 € (Kasse 4.000 €, Wertschrank 16.000 €). Siehe `docs/BALANCING_TODO.md`.
- Tresen: Original zwei, im Spiel einer.
- Grundriss: eigener Entwurf.
- Fahrzeugwerte und Verfolgung: Richtwerte, nicht gegen das Original geprüft.

## Offen
- Balancing aller Gebäude.
- Ortsmarken auf der Stadtkarte sind Schätzungen.
- Nur Kiosk und Museum sind spielbar.

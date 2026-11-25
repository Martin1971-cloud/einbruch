# Release Candidate RC71 – Der Einbruch

## Kiosk-Grundriss neu entworfen
- Eigener Entwurf statt der Kollisionsrechtecke aus den Originaldaten: Außenwand (0,5 m), eine Tür (1 m) in der Südwand, Wertschrank an der Nordwand, Tresen mit Kasse an der Ostwand.
- Die Spielpunkte bleiben: Eingangstür (8,7), Außen (8,8), Kassenlade (10,3), Wertschrank (8,2). Standfelder: Kasse (9,3), Wertschrank (8,3).
- Grobe Karte und 3D-Wände daraus neu erzeugt. Wände in 3D sind durchgehend, ohne Blöcke an den Übergängen.

## Figuren und Beute in 3D
- Teodor und Otto sind im neuen Grundriss bei Kasse und Wertschrank sichtbar (Tiefentest bleibt aktiv).
- Der Beutesack sitzt auf dem Rücken des Trägers. Die Position wurde mit der Kamera geprüft.

## Texte und Bilder
- Beschreibungen der Schauplätze: Kurztext im Ort-Panel und auf den Karten-Marken.
- Schauplatz-Bilder für Kiosk, Museum und die weiteren Orte in `assets/art/location_<id>.png` (zugeschnitten).
- Kiosk-Bedarf und Ortsbeschreibung nennen nur noch die Eingangstür (eine Tür im Grundriss).

## Simulation
- Körperkreis, Wegsuche mit Körperbreite, Reichweite mit Sichtlinie (Wand und geschlossene Tür blockieren, Tresen nicht), Blickrichtung zum Objekt.
- Kiosk-Plan: Entkommen mit Kasse und Wertschrank, Auszahlung 12.000 € (Tests siehe RC70).

## Tests
- Alle Headless-Tests in `tests/` bestehen. `test_frei` und `test_durchlauf` angepasst bzw. stabil.
- Visuelle Prüfung der 3D-Ausführung: `tests/pruef_3d_kiosk.gd` mit `--rendering-driver opengl3`.

## Bekannte Abweichungen vom Original
- **Gebäudewert:** Original 380, nicht übernommen (Einheit unbekannt). Kiosk bei 20.000 € Beute (Kasse 4.000 €, Wertschrank 16.000 €). Siehe `docs/BALANCING_TODO.md`.
- **Tresen:** Original zwei Tresen, im Spiel einer.
- **Grundriss:** Eigener Entwurf, keine Übernahme der Originalgeometrie.
- **Wagen und Fluchtweg:** Position (5,7) und Fluchtweglänge nicht gegen das Original geprüft.

## Offen
- Balancing aller Gebäude (eigene Aufgabe nach dem Kiosk).
- Ortsmarken auf der Stadtkarte sind Schätzungen.
- Nur Kiosk und Museum sind spielbar.

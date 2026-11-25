# Release Candidate RC72 – Der Einbruch

## Grundriss: Zoom und Verschieben
- Mausrad zoomt um die Mausposition. Ziehen mit der Maus (auch mittlere Taste) verschiebt die Ansicht.
- Zoomknöpfe „+“ und „−“ am rechten Rand, Knopf „Alles“ zeigt wieder die ganze Karte.
- Doppelklick setzt die Ansicht zurück. Klicks auf Felder, Personen und den Fluchtwagen funktionieren im gezoomten Zustand.

## Figuren im Grundriss
- Die Person im 2D-Grundriss ist das Sprite aus der 3D-Ansicht, auf ungefähr ein Feld Höhe verkleinert. Sie bleibt im Feld und ragt nicht über Wände.

## Planung
- Das Foto des Zielgebäudes in der Vorhaben-Karte zeigt das ganze Bild, nichts wird abgeschnitten.

## Kiosk-Grundriss (aus RC71, unverändert)
- Eigener Entwurf: klare Außenwand, eine Tür in der Südwand, Wertschrank an der Nordwand, Tresen mit Kasse an der Ostwand.

## Tests
- Neu: `tests/test_zoom.gd` (Zoom um die Mausposition, Klick nach Zoom, Verschieben, Zurücksetzen, Knöpfe).
- Bestanden (headless bzw. mit Anzeige): test_kollision, test_startposition, test_sim, test_zoom, test_frei, test_reichweite, test_wache, test_kiosk, test_pruefung, test_planung_klick, test_plan_speichern, test_durchlauf.
- Testlauf mit Wänden und Möbeln im Zoom (Tür, Kasse, Wertschrank, Rückweg): Figuren und Gebäude sind sichtbar.

## Bekannte Abweichungen vom Original (wie RC71)
- Gebäudewert: Original 380, im Spiel 20.000 € (Kasse 4.000 €, Wertschrank 16.000 €). Siehe `docs/BALANCING_TODO.md`.
- Tresen: Original zwei, im Spiel einer.
- Grundriss: eigener Entwurf.
- Wagenposition und Fluchtweg nicht gegen das Original geprüft.

## Offen
- Balancing aller Gebäude (eigene Aufgabe nach dem Kiosk).
- Ortsmarken auf der Stadtkarte sind Schätzungen.
- Nur Kiosk und Museum sind spielbar.

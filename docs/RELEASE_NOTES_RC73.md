# Release Candidate RC73 – Der Einbruch

## Grundriss
- Zoom mit Mausrad, Ziehen zum Verschieben, Knöpfe „+“, „−“ und „Alles“ am rechten Rand, Doppelklick zum Zurücksetzen.
- Verschieben und Zoomen lassen das Gebäude nicht aus dem Bild laufen. Bei der kleinsten Stufe ist das ganze Gebäude zentriert zu sehen, bei größeren Stufen bleiben mindestens 160 Pixel davon im Bild.
- Die Person im Grundriss ist das Sprite aus der 3D-Ansicht, etwa ein Feld hoch.
- Beutebilder erscheinen in der Planung nur beim Darüberfahren.
- Laufwege sind entfernt, die nummerierten Aktionsmarken bleiben. Die Marken der gewählten Person sind größer, die der anderen abgeschwächt.

## Team und Planung
- Jede Person hat eine Tickbox und einen Farbpunkt in ihrer Grundrissfarbe. Die gewählte Person ist farblich markiert, Zahlentasten 1 bis 9 wählen ebenfalls aus.
- Ablaufplan und Vorschau stehen in einer schmalen Spalte rechts neben dem Grundriss. Die Schrift lässt sich mit A− und A+ einstellen (10 bis 18).
- Die Kopfleiste ist in der Reihenfolge des Ablaufs: Stadt, Organisation, Planung, Beispielplan (Test), Vorschau, Ausführung.
- „Vorschau“ spielt den ganzen Einbruch von vorn ab. Eine Planänderung startet keine Animation.
- „Ausführung“ fragt bei mehreren gespeicherten Plänen, mit welchem Plan der Einbruch laufen soll.
- Die Planung füllt das ganze Fenster aus. Der Hintergrund ist neutral.
- Speichern und Laden stehen oben in der Zeitplan-Leiste, die Zeitleiste nutzt die frei werdende Höhe. Platz für mindestens vier Personen.

## Stadt
- Die Stadtkarte ist breiter, das Ortsbild schmaler.
- Beim Darüberfahren über eine Ortsmarke erscheint ein Hinweis mit Namen und „noch nicht auswählbar“. Der Tooltip mit Kurztext bleibt.

## Kiosk (wie RC72)
- Eigener Grundriss mit klarer Außenwand, einer Tür, Wertschrank an der Nordwand, Tresen mit Kasse an der Ostwand.

## Tests
- Bestanden: test_kollision, test_startposition, test_sim, test_zoom, test_frei, test_reichweite, test_wache, test_kiosk, test_pruefung, test_planung_klick, test_plan_speichern, test_durchlauf, test_auswahl, test_klick_pfad, test_wahl_plan.

## Bekannte Abweichungen vom Original
- Gebäudewert: Original 380, im Spiel 20.000 € (Kasse 4.000 €, Wertschrank 16.000 €). Siehe `docs/BALANCING_TODO.md`.
- Tresen: Original zwei, im Spiel einer.
- Grundriss: eigener Entwurf.
- Wagenposition und Fluchtweg nicht gegen das Original geprüft.

## Offen
- Balancing aller Gebäude.
- Ortsmarken auf der Stadtkarte sind Schätzungen.
- Nur Kiosk und Museum sind spielbar.

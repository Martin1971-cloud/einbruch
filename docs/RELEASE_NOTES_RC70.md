# Release Candidate RC70 – Der Einbruch

## Kollision und Wege
- Personen haben einen Körperkreis (4,5 Unterfelder ≈ 0,28 m). Die Simulation prüft jeden Schritt, nicht nur die Mitte.
- Die Wegsuche plant nur Wege, auf denen der Körper hindurchpasst. Trifft die Person auf ein Hindernis, bricht die Aktion mit Meldung ab.
- Steht der Feldmittelpunkt zu nah an einer Wand, nimmt die Person den nächsten freien Punkt im selben Feld.

## Reichweite, Sicht und Blickrichtung
- Eine Aktion an einem Objekt braucht Reichweite (ein Feld, zur Mitte oder zum nächsten Teil des Objekts) und freie Sicht.
- Wände, Fenster, geschlossene Türen blockieren die Sicht. Der Tresen blockiert sie nicht (man greift darüber, die Kasse liegt auf dem Tresen). Eigene Teile von Vitrine und Kasse zählen nicht als Hindernis.
- Beim Öffnen, Aufbrechen und Nehmen schaut die Person zum Objekt. In 3D übernimmt die Figur die Richtung der Simulation, wenn sie steht.

## Grundriss Kiosk (aus den Originaldaten, TOBAETA0.DAT)
- Tür: Öffnung 1 m (16 Unterfelder), mittig in der Originalfläche. Die Wand schließt den Rest. Vorher war eine Lücke durch die Wand begehbar.
- Wandlinien enden an der Außenkante des Gebäudes, keine Überstände an den Ecken.
- Tresen, Wertschrank und Kasse auf die Originalmaße korrigiert. Kasse: Feld (10,3), Standfeld (9,3). Wertschrank: Feld (8,1), Standfeld (8,2).
- Grobe Karte des Kiosks aus den neuen Rechtecken neu berechnet.

## Stadtplan Königsbrück
- Stadtbild als Hintergrund (`assets/map/koenigsbrueck.webp`).
- Ortsmarken auf den Landmarken: Hauptbahnhof, Stadtmuseum Varenhafen, Stadttheater, Bankhaus Brandt, Villa Lindemann, Auktionshaus Roth, Hafen, Schloss Königstein, Bürogebäude, Stadtarchiv, Forschungsinstitut, Kiosk „Zum Anker“.
- Positionen sind geschätzt und können nachgeschoben werden.
- Tooltip auf den Marken zeigt den Kurztext des Ortes.

## Schauplätze
- Zuschnitt der Schauplatz-Bilder: `assets/places/` und `assets/art/location_<id>.png`. Das Ortsbild nutzt das Bild, sobald die Datei existiert.
- Kurztexte je Ort (`info` in den Daten), im Ort-Panel und auf der Karte.

## Planung
- Speicherleiste in eigener Zeile unter dem Zeitplan (vorher über den Rand hinaus).
- Planung scrollt vertikal, wenn das Fenster zu klein ist.
- Beispielplan an die neue Kassenposition angepasst.

## Beute in 3D
- Der Beutesack auf dem Träger sitzt auf dem Rücken, nicht über dem Kopf.

## Tests
- Neu: `tests/test_startposition.gd` (Start der Objektaktionen, Sichtlinie, Blickrichtung).
- Angepasst: Testpläne an die neuen Standfelder von Kasse und Wertschrank.
- Bestanden (headless): test_kollision, test_startposition, test_sperre, test_warnung, test_pruefung, test_kiosk, test_reichweite, test_wache, test_frei, test_sim (16/16), test_plan_speichern, test_speichern, test_werkzeug, test_kauf, test_laerm, test_lernen, test_abbruch.
- Bestanden mit Anzeige (xvfb): test_durchlauf, spieldurchlauf_kiosk_klein (Entkommen, Auszahlung 12.000 €, Differenz +4.300 €).

## Offen
- 3D-Ansicht nicht visuell geprüft (in dieser Umgebung kein Vulkan).
- Ortsmarken und Standorte auf der Karte sind Schätzungen.
- Schauplätze außer Kiosk und Museum sind noch nicht spielbar.

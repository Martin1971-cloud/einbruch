# Etagen: Befund aus dem Original und Umsetzungsplan

## Befund aus den Originaldaten (DATA/*.DAT, *.REL, *.LFD)
- Jedes Gebäude hat eine oder mehrere **Bereiche** (Areas): `XXXETA0.DAT` (Erdgeschoss), `XXXETA1.DAT`, `XXXETA2.DAT`.
- Mehrere Bereiche haben 8 von 38 Gebäuden, z.B. Turm von London (3), Kaserne (3), British Museum (2), Buckingham Palace (2), Bank (1), Villa (1), Baker Street (2), Tranquility/Tranetta (2).
- Jeder Bereich hat eigene Objekte (`.DAT`), eigene Beziehungen (`.REL`) und eine eigene Bodendatei (`.LFD`, Floor-Data).
- Die Verbindung zwischen Bereichen ist die Beziehung **Relation_StairConnects** (Nr. 3, `data/tcdata.h`). Eine Treppe ist ein Objekt (`Item_Treppe` 9238). Sie verbindet zwei Treppen-Objekte in verschiedenen Bereichen.
- Im Planer (`planing/planer.c`, Aktion „Treppe benutzen“): Die Person wird in den anderen Bereich gesetzt (`livLivesInArea`), der Bereich wird gewechselt (`lsInitActivArea`), und die Zeit kostet `PLANING_TIME_USE_STAIRS` (8 Zeiteinheiten).
- Der Fluchtwagen steht nur im Startbereich (`lsGetStartArea() == lsGetActivAreaID()`). Die Polizei und die Wachen gehören zum Bereich.

## Umsetzungsplan (in dieser Reihenfolge)
1. **Datenmodell:** Ein Ziel bekommt `floors`: Liste mit `id`, `name`, `fine`, `map`, `doors`, `points`, `loot`, `stairs`. Ohne `floors` gilt der bisherige Grundriss als einziger Bereich, damit bestehende Ziele gleich bleiben.
2. **Simulation:** Jede Person hat einen Bereich (`floor`). Begehbarkeit, Sicht, Türen, Beute und Wachen werden je Bereich geprüft. Die Aktion `TREPPE` wechselt den Bereich, wenn die Person an einer Treppe steht. Die Zeit ist 8 Sekunden wie im Original.
3. **Planung:** Reiter oben im Grundriss für die Etagen. Rechts in der Teamliste steht bei jeder Person die Etage (z.B. „EG“, „OG“). Ein Klick auf die Person wechselt die Etage und zentriert die Ansicht. Beim Abspielen folgt die Etage der gewählten Person, die übrigen Etagen werden abgedunkelt.
4. **3D:** Eine Etage wird gezeigt, die andere ausgeblendet oder als Schnitt gezeigt. Die Figur wechselt die Etage an der Treppe.
5. **Prüfung:** Ein Ziel mit zwei Etagen (z.B. Museum, Obergeschoss mit Galerie) durchspielen. Alle Tests bleiben grün.

## Was der Anwender erwartet
- Auf einen Blick: auf welcher Etage ist welche Person.
- Ein Klick auf die Person bringt die richtige Etage.
- Die Treppe ist sichtbar und ist eine Aktion wie jede andere.
- Die Ansicht springt nicht unerwartet, sie folgt der gewählten Person.

## Stand
- Schritt 1 (Daten): Das Testgebäude hat ein Obergeschoss. Der Grundriss ist gestapelt: Erdgeschoss oben, Obergeschoss darunter (24 Zeilen Karte, Grundriss 384 Unterfelder hoch). Verbunden durch `treppen` (Feldpaare), Treppenfeld im Grundriss ist `T`.
- Schritt 2 (Simulation): Aktion `TREPPE` (8 s, Original PLANING_TIME_USE_STAIRS). Die Etage ergibt sich aus der Position, Wände und Türen trennen die Etagen. Test: `tests/test_testhaus.gd`.
- Schritt 3 (Planung): Etagen-Reiter (EG, OG) im Kopf des Grundrisses, Trennlinie und Etagenname im Grundriss, Etage je Person in der Teamliste (an der Abspielmarke), Menü „Treppe steigen (8 s)“ auf Treppenfeldern. Prüfbild: tests/pruef_planung_etagen.gd.
- Schritt 4 (3D): Schalter EG, OG, Alle in der Kopfleiste. Die Ansicht zeigt nur die gewählte Etage (Zuordnung über die Höhe der Karte), die Kamera fährt auf die Etage. Figuren verschwinden mit ihrer Etage und erscheinen auf der anderen Etage, sobald sie die Treppe genommen haben. Außenobjekte (Laternen, Straße) bleiben immer sichtbar. Prüfbilder: tests/pruef_etagen_3d.gd.
- Abspielansicht (Standard „Folgen“): zeigt die Etage der Person, die gerade läuft. Schalter EG, OG und Alle.
- Höhe: Die obere Etage wird in 3D um eine Etagenhöhe angehoben (LEVEL_H) und auf die Grundrissfläche des EG gelegt. Figuren, Wachen, Beute, Lampen und Sichtlinien nutzen dieselbe Höhe.
- Erster Gebäude-Schritt nach dem Kiosk: Kuriositätenladen „Alte Gasse 7“ (zwei Etagen, Schaufenster, Holztüren, Vitrinen, Gemälde, Treppe, keine Wache). Schaltet das Museum erst nach dem Laden frei.

## Original: Etagenlogik und was wir übernehmen
- Im Original ist jede Etage ein eigener Bereich mit eigenen Objekten, Beziehungen und Bodendaten. Wachen, Polizei und der Fluchtwagen gehören zu einem Bereich. Der Fluchtwagen steht nur im Startbereich.
- Die Verbindung ist die Beziehung „Treppe“: sie koppelt zwei Treppenobjekte in verschiedenen Bereichen, Zeitkosten 8 s.
- Übernommen: Treppe als Paar mit 8 s, Fluchtwagen nur auf der Startetage (durch die Geometrie gegeben, weil die Treppe der einzige Weg ist), Etage je Person in der Planung und 3D.
- Noch nicht übernommen: Wachen und Polizei pro Etage (heute global), eigene Bodendaten je Etage (heute ein gestapelter Grundriss).

## Vorschlag für die Steigerung (von Gebäude zu Gebäude)
- Einführung je Gebäude eine neue Mechanik: Laden = Schloss und Fenster, Kuriositätenladen = Treppe und Gemälde, Museum = Alarm und Stahltür, danach Wachen.
- Schwierigkeit steigt über: Schlösser (Komplexität), Anzahl und Route der Wachen, Alarmstufen, Polizeizeit, Fluchtweg, Gewicht der Beute.
- Freischaltung nach Erfolg (wie bisher Kiosk → Laden → Museum) und zusätzlich nach Ermittlung (Ermittlungsstufe 2).
- Hinweise beim ersten Auftreten einer Mechanik (einmalig, im Planer).
- Balancing je Gebäude: Beutewert gegen Aufwand (Zeit, Lärm, Fähigkeiten); Fähigkeiten steigen durch Einsatz (bereits vorhanden).

## Reihenfolge der Gebäude (Stand)
1. Kiosk „Zum Anker“ (vorhanden)
2. Kuriositätenladen „Alte Gasse 7“ (vorhanden, Grafik fehlt)
3. noch offen (bitte festlegen)
4. Stadtmuseum Varenhafen (Grafik vorhanden)
- Gebäude 3: Juwelier „Silberstern“ (Alarm, Mikrofon, Stahltür, Schaufenster). Freischaltung nach dem Laden. Museum nach dem Juwelier.
- Grafiken: location_curiosity.jpg und location_juwelier.jpg wurden flach gezeichnet (Nachtszene, Stil nicht identisch mit den gemalten Vorlagen). Ersetzbar durch gemalte Fassungen im gleichen Stil wie kiosk/museum.
- Ortsbilder ersetzt: location_curiosity.jpg (links) und location_juwelier.jpg (rechts) aus dem gemeinsamen Bild, gleicher Stil wie die Vorlagen.

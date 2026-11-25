# Referenz aus den Originaldaten (Der Clou!)

Quelle: die hochgeladenen DOS-Daten (DATA/*.DAT, *.REL, TEXTS) und der Quellcode (cosp-0.8, database.c, relation.c, dataappl.c, presenta.c).
Die Dekodierer liegen in `tools/`: `decode_dat.py` (Datensätze), `decode_rel.py` (Beziehungen), `referenz_gebaeude.py` (Tabelle).

## Gebäudewerte (alle 28 Orte)

Erklärung der Spalten (laut Quellcode):
- **Polizeizeit**: Die Polizei kommt so viele Sekunden nach dem Alarm (planing/player.c, `PoliceTime`).
- **Wachrate**: Grundlage für Streifgänge und Wachverhalten (`GRate`).
- **Wachstärke**: Kampfkraft der Wachen (`GuardStrength`).
- **Lautstärkegrenze**: Über diesem Wert löst der Lärm Alarm aus (`MaxVolume`, dataappl.c).
- **Wert**: Gebäudewert, Anzeige in der Vorschau (`tcGetBuildValues`, presenta.c).
- **Fluchtweg**: Länge in der Auswertung (`EscapeRouteLength`).

| Ort (Nr.) | Name | Polizeizeit s | Wachrate | Wachstärke | Lautstärkegrenze | Wert (Original) | Fluchtweg | Wagen (x,y) |
|---|---|---|---|---|---|---|---|---|
| 10 | Kiosk | 600 | 10 | 0 | 200 | 380 | 10 | 35,175 |
| 12 | Tante Emma Laden | 700 | 30 | 0 | 120 | 630 | 20 | 95,175 |
| 14 | Juwelier | 900 | 100 | 0 | 150 | 3150 | 13 | 95,209 |
| 16 | Old Curiosity Shop | 880 | 90 | 0 | 170 | 900 | 20 | 95,205 |
| 18 | Pink Villa | 700 | 10 | 0 | 220 | 430 | 19 | 95,235 |
| 20 | Seniorenheim | 600 | 20 | 0 | 100 | 1700 | 31 | 95,235 |
| 23 | Highgate, Highgate Cemetery | 400 | 70 | 40 | 200 | 1300 | 40 | 95,239 |
| 25 | Villa | 900 | 70 | 120 | 220 | 17000 | 30 | 95,239 |
| 27 | Kenwood House | 1000 | 190 | 130 | 240 | 50000 | 79 | 95,239 |
| 29 | Ham House | 800 | 160 | 80 | 240 | 34000 | 63 | 95,239 |
| 31 | Osterly Park House | 700 | 180 | 100 | 230 | 25000 | 68 | 155,209 |
| 33 | Chiswick House | 860 | 140 | 120 | 210 | 16500 | 55 | 95,239 |
| 35 | Suterby's | 240 | 211 | 90 | 180 | 8300 | 30 | 95,244 |
| 37 | British Museum | 180 | 200 | 210 | 160 | 100000 | 32 | 95,239 |
| 39 | Natural Museum | 220 | 170 | 50 | 170 | 34000 | 38 | 95,239 |
| 41 | National Galery | 180 | 194 | 170 | 160 | 170000 | 13 | 95,239 |
| 43 | Victoria & Albert Museum | 300 | 204 | 140 | 150 | 65000 | 7 | 95,239 |
| 45 | Bank of England | 120 | 220 | 230 | 160 | 330000 | 29 | 95,230 |
| 47 | Tower of London | 90 | 230 | 250 | 150 | 1000000 | 13 | 95,239 |
| 66 | Starford Kaserne | 180 | 230 | 170 | 250 | 0 | 51 | 284,257 |
| 68 | 221 B Baker Street | 820 | 28 | 0 | 180 | 4000 | 25 | 40,195 |
| 70 | Madame Tussaud | 743 | 76 | 60 | 160 | 8000 | 22 | 40,240 |
| 72 | Westminster Abbey | 555 | 85 | 110 | 170 | 18000 | 5 | 475,60 |
| 74 | Downing Street 10 | 250 | 130 | 250 | 140 | 5000 | 15 | 25,200 |
| 75 | Downing Street 10, Whitehall | 0 | 10 | 60 | 250 | 35000 | 80 | 140,155 |
| 77 | Tate Gallery | 420 | 180 | 200 | 180 | 80000 | 17 | 10,60 |
| 79 | Buckingham Palace | 190 | 210 | 210 | 140 | 350000 | 22 | 40,235 |
| 81 | Bulstrode Chemestry Ltd | 320 | 230 | 220 | 150 | 500000 | 35 | 550,185 |

## Kiosk „Zum Anker“ (Nr. 10) im Vergleich zu unserem Spiel

| Merkmal | Original | Unser Spiel | Abweichung |
|---|---|---|---|
| Polizeizeit | 600 s | 60 s + Reaktionszeit | Original ist zehnmal so lang |
| Wache | keine (Wachstärke 0) | keine | übereinstimmend |
| Lautstärkegrenze | 200 | 30 (Standard, nicht gesetzt) | andere Skala, muss angeglichen werden |
| Wert des Gebäudes | 380 | 20.000 (Summe der Beute) | Faktor etwa 50, Einheit prüfen |
| Türen | 1 Holztür, Schloss Typ 1 | 2 Türen (Eingang, Hinter) | Original hat nur eine Tür |
| Wertschrank | 1 (mit Geld und Zigarrenkiste) | keiner | fehlt bei uns |
| Kasse | 1, mit Geld | 1 Kassenlade (4.000 €) | übereinstimmend |
| Tresen | 2 | keiner | Dekoration, kein Ziel |
| Schmuckkasten | keiner | 1 (12.000 €) | nicht im Original |
| Zigarettenkartons | keiner (Zigarrenkiste im Wertschrank) | 1 (4.000 €) | anders eingeordnet |
| Gewicht Kasse | 500 g (Geld) | 8 kg | Faktor 16 zu hoch |
| Volumen Kasse | 1.000 cm³ | nicht vorhanden | fehlt bei uns |
| Gewicht Zigarrenkiste | 2 kg (Delikatessen) | 5 kg (Zigarettenkartons) | zu hoch |
| Fluchtweg | 10 | Wagen 20 s Fahrt | nicht direkt vergleichbar |

### Was sich daraus ableiten lässt
1. **Gewichte** sind bei uns zu hoch. Das Original nennt Geld mit 500 g, bei uns sind es 8 kg. Das ändert die Tragkraft-Rechnung. Mit Originalgewichten trägt eine Person die ganze Kiosk-Beute.
2. **Polizeizeit** ist zu kurz: 600 s im Original für den Kiosk. Bei uns 60 s. Im Original bleibt beim Kiosk also viel Zeit zwischen Alarm und Polizei. Das passt zur Einstufung als einfaches Ziel. Die Zahl sollten wir bewusst festlegen.
3. **Lautstärkegrenze**: Original 200 für den Kiosk, bei uns 30. Die Skalen sind verschieden. Ohne den Originalwert der Werkzeuge kann ich das nicht sauber umrechnen.
4. **Wertbasis**: Der Original-Wert 380 für den Kiosk ist klein. Unsere 20.000 € sind etwa 50-mal so hoch. Bevor wir umrechnen, sollten wir die Einheit klären. Der Originalwert wird als Anzeige ausgegeben (`PRESENT_AS_NUMBER`), die Einheit steht nicht im Code.
5. **Wertschrank**: Das Original hat im Kiosk einen Wertschrank mit Geld und Zigarrenkiste. Unsere Vorgabe sagt aber: nur Brecheisen oder Dietrich. Der Quellcode verlangt für Safes Werkzeuge wie Kernbohrer oder Schneidbrenner. Hier müssen wir entscheiden, ob der Kiosk einen Wertschrank bekommt.
6. **Beute**: Das Original hat im Kiosk kein Schmuckstück. Unsere 12.000 € Schmuckkasten stammen nicht aus dem Original.

### Noch offen
- Die Zuordnung Schloss → Werkzeug ist aus den Relationen nicht vollständig auflösbar: Die Relation „toolRequires“ (Nr. 15) verweist auf Werkzeugobjekte, deren Format ich noch nicht dekodiert habe (Werkzeugsatz in cosp, Object_Tool). Die Werkzeugwerte (Lautstärke, Dauer) stammen daraus.
- Die Ortsbeute ist im Original über Relation „has“ (Nr. 4) und Relation 14 zu den Wertschränken verbunden. Die Zuordnung der Kiosk-Beute ist für den Kiosk belegt, für andere Orte noch nicht geprüft.

## Empfehlung
Wir ändern noch nichts. Die Entscheidungen sind Balance-Entscheidungen:
- Gewichte auf Originalwerte (Gramm) umstellen. Das ist eine klare Korrektur.
- Polizeizeit für den Kiosk festlegen (600 s original, oder bewusst kürzer).
- Gebäudewert und Lautstärkegrenze als Original-Parameter übernehmen, sobald die Einheit klar ist.
- Entscheidung zum Wertschrank treffen.

## Stand der offenen Punkte

### Erledigt
- **Gewichte** (Kiosk): Kassenlade 8 kg → 0,5 kg (Geld laut Original, 500 g). Zigarettenkartons 5 kg → 2 kg (Zigarrenkiste, 2 kg).
- **Polizeizeit** (Kiosk): 600 s wie im Original. Neues Feld `police_time` je Ziel, Standard bleibt 60 s.
- **Lautstärkegrenze** (Kiosk): 200 wie im Original. Neues Feld `max_volume` je Ziel. Die Werkzeug-Lautstärke ist vergleichbar: Brecheisen an der Kasse 70 im Original, bei uns 65 dB.
- **Werkzeugdaten** dekodiert (Object_Tool: Wert, Gefahr, Volumen, Wirkung). Die Beziehungen Schloss–Werkzeug (`opens`, `sound`, `hurt`, `break`) stehen im Original je Objekt und Werkzeug.

### Werkzeuge gegen Kiosk-Objekte (Original, Relationen)
| Objekt | Werkzeug (Original) | Lärm | Schaden | Bruchwert |
|---|---|---|---|---|
| Holztür | Hand (öffnet) | 70 | 150 | – |
| Holztür | Dietrich | 10 | 10 | 18 |
| Holztür | Brecheisen | 50 | 30 | 15 |
| Wertschrank | Brecheisen | 72 | 40 | 8 |
| Wertschrank | Hand (öffnet) | – | – | – |
| Kasse | Brecheisen | 70 | 36 | 10 |
| Kasse | Elektrohammer | 80 | 40 | 15 |

Die Relationen sagen: Der Wertschrank und die Kasse lassen sich mit dem Brecheisen öffnen. Die Vorgabe „nur Brecheisen oder Dietrich“ passt also auch zum Wertschrank im Original.

### Noch offen
- **Schloss → Fähigkeit:** Die Relation „toolRequires“ widerspricht dem Quellcode (der Dynamit der Sprengstoff-Fähigkeit zuordnet, die Datei verbindet es mit einer anderen Nummer). Die Mindeststufen (Dietrich 100 in der Datei, bei uns 25) bleiben ungeklärt.
- **Wertbasis:** Die Einheit des Gebäudewerts ist nicht im Code festgelegt. Wir behalten unsere 20.000 € bei.
- **Wertschrank im Kiosk:** Der Wertschrank mit Geld und Zigarrenkiste fehlt bei uns. Das ist eine Inhaltsentscheidung.

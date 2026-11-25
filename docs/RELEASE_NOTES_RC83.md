# Release Notes RC 83

Stand: Testversion für den Spieler-Test auf dem PC.

## Neu seit RC 82
- Tür-Flimmern behoben (Ursache gefunden und beseitigt): Die Wandstücke neben einer Tür ragten in die Öffnung hinein, und die dunklen Umrisse der Wände lagen in der Ebene der Türblattkante. Dadurch entstanden die gezackten Striche. Wandenden an Türöffnungen werden nicht mehr verlängert, das Türblatt ist auf 80 % der Öffnung verkleinert, und der dunkle Türrahmen sitzt in der Lücke.
- Prüfskript `godot/tests/pruef_tuer_geometrie.gd`: listet alle Körper, die ein Türblatt berühren oder überlappen.

## Bekannt offen
- Musik Planung und Ausführung: Schleifen neu geschnitten, nur gemessen, nicht gehört. Bitte auf Sprünge achten.
- Ruckler in der 3D-Ausführung: Ursache außerhalb des Spielcodes, noch nicht geklärt.
- Museum (Gebäude 4) nicht bewertet.
- Balance der ersten drei Gebäude: durch Spielen zu prüfen.
- Pixabay-Lizenz: Zusammenfassung geprüft, vollständige Lizenz noch nicht.

## Prüfung
- Alle Tests und Texttabelle: 58 Tests, 0 Fehler.
- Türprüfung per Bild: Die Streifen auf dem Türblatt sind im Testbild nicht mehr sichtbar.
- Das Paket enthält den vorbereiteten Import-Cache, damit der Start ohne `--import` funktioniert.

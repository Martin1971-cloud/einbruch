# Release Notes RC 82

Stand: Testversion für den Spieler-Test auf dem PC.

## Neu seit RC 81
- Tür in der 3D-Ausführung: Dunkler fester Türrahmen in den Spalten neben dem Türblatt, damit dort nicht mehr der Boden durchscheint. Gilt für die Haupteingangstür und die übrigen Türen mit feinem Grundriss.
- Prüfskript `godot/tests/pruef_tuer_otto.gd`: Otto allein an der Eingangstür, Bilder in mehreren Zeitpunkten.

## Bekannt offen
- Tür-Flimmern: Die waagerechten Striche auf dem Türblatt bleiben im Prüfbild sichtbar. Der Rahmen hat sie nicht beseitigt. Der Mondschatten ist als Ursache ausgeschlossen. Bitte beim Test melden, ob und wo es noch flimmert.
- Musik Planung und Ausführung: Schleifen neu geschnitten, nur gemessen, nicht gehört. Bitte auf Sprünge achten.
- Ruckler in der 3D-Ausführung: Ursache außerhalb des Spielcodes, noch nicht geklärt.
- Museum (Gebäude 4) nicht bewertet.
- Balance der ersten drei Gebäude: durch Spielen zu prüfen.
- Pixabay-Lizenz: Zusammenfassung geprüft, vollständige Lizenz noch nicht.

## Prüfung
- Alle Tests und Texttabelle: 58 Tests, 0 Fehler.
- Das Paket enthält den vorbereiteten Import-Cache, damit der Start ohne `--import` funktioniert.

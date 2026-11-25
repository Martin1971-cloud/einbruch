# Release Notes RC 84

Stand: Testversion für den Spieler-Test auf dem PC.

## Neu seit RC 83
- 3D-Ausführung, Wände: Außenseiten aus Ziegel, Innenseiten aus Bruchstein. Die Außenseiten werden über den Grundriss erkannt (vom Rand aus erreichbar).
- 3D-Ausführung, Deko: Regal, Tisch mit Stühlen, Pflanze, Bilder an den Wänden und Kisten. Die Deko gehört nicht zur Beute, ist nicht anklickbar und verändert weder Wege noch Ablauf.
- Deko ist für Kiosk, Kuriositätenladen und Juwelier angelegt. Im Kiosk ist sie geprüft. Für Kuriositätenladen und Juwelier ist die Platzierung noch nicht im Bild geprüft.

## Bekannt offen
- Zackenmuster an Schattenkanten des Mondlichts (Wände im Prüfgebäude): Ursache Schatten-Aliasing, nicht behoben. Mögliche Abhilfe: Mondschatten abschalten (Look ändert sich).
- Musik Planung und Ausführung: Schleifen neu geschnitten, nur gemessen, nicht gehört. Bitte auf Sprünge achten.
- Ruckler in der 3D-Ausführung: Ursache außerhalb des Spielcodes, noch nicht geklärt.
- Museum (Gebäude 4) nicht bewertet.
- Balance der ersten drei Gebäude: durch Spielen zu prüfen.
- Pixabay-Lizenz: Zusammenfassung geprüft, vollständige Lizenz noch nicht.

## Prüfung
- Alle Tests und Texttabelle: 58 Tests, 0 Fehler.
- Das Paket enthält den vorbereiteten Import-Cache, damit der Start ohne `--import` funktioniert.

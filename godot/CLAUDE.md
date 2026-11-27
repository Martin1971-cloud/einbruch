# Hinweise für die Arbeit am Projekt

## Gebäude und Dekoobjekte
- Bei jedem neuen Gebäude (und bei Änderungen an Grundrissen) Dekoobjekte ohne Beute so setzen, dass sie Platz haben:
  - Die Anlaufseite jedes Dekoobjekts ist frei und vom Eingang aus erreichbar.
  - Das Objekt ist nicht eingeschlossen (mindestens zwei freie Nachbarfelder).
  - Kein anderes Objekt (Beute, Tür, Alarmpanel) liegt auf einem der vier Nachbarfelder. Diagonal ist erlaubt, Wände dürfen sein.
- `tests/test_deko_abstand.gd` prüft das für alle Ziele mit Dekoobjekten. Vor dem Commit laufen lassen.
- Dekoobjekte nutzen dieselben Grundrisskacheln wie die Beute (C, S, K) oder die Dekotypen R, Z, P, damit Kollision und Sichtregel gleich sind.

## Code
- Sauber heißt: keine toten Funktionen, Variablen, Schlüssel oder Dateien; keine auskommentierten Blöcke; keine Debug-Reste.
- Eine Quelle der Wahrheit: Spielwerte in `scripts/data.gd`, Texte in `scripts/texte.gd`. Keine Zahl oder Text doppelt im Code.
- Keine Sonderfälle über einzelne IDs im Code (also kein `if id == "deko_vitrine"`). Verhalten kommt aus Eigenschaften wie `leer` oder dem Kachel-Typ.
- Kleine Funktionen mit klaren Namen. Kommentare erklären das Warum, nicht das Was.
- Godot-Log ohne Fehler und Parse-Warnungen. Warnungen gelten als Fehler.
- Neue Funktion oder neues Verhalten: passender Test dazu.

## IDs und Bezüge
- IDs sind klein geschrieben, ASCII, mit Unterstrich (`deko_vitrine`). Eine ID ist pro Kategorie eindeutig.
- Umbenennen einer ID nur mit Suche über alle Dateien (Daten, Pläne, Texte, Tests). Anzeigetexte stehen nie in der ID.
- Jeder Bezug muss auf etwas Vorhandenes zeigen: Beute, Tür, Punkt, Kachel, Textschlüssel. Ein Bezug auf eine fehlende ID ist ein Fehler.
- Koordinaten liegen innerhalb des Grundrisses und auf einem begehbaren Feld, wenn dort ein Objekt oder ein Punkt steht.

## Daten und Tabellen
- Jeder Eintrag eines Typs hat dieselben Pflichtfelder in derselben Reihenfolge.
- Zahlen mit Einheit im Namen oder im Kommentar (`gewicht` in kg, `time` in Sekunden).
- Schlüssel für Texte beginnen mit der Kategorie (`deko.`, `fail.`, `sim.`), Deutsch und Englisch stehen paarweise.

## Prozess
- Kleine Commits mit verständlicher Nachricht. Nicht mehrere Themen in einem Commit mischen.
- Vor jedem Commit: `tools/pruefe_alles.sh` (mit `GODOT=<Pfad zum Godot-Binary>` aufrufen).
- Änderungen am Spielstand-Format nur mit Versionsnummer und Hinweis im Commit.

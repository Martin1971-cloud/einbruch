# Spielprinzip – Arbeitsdokument (zur Bestätigung)

Grundlage: Quellcode der Open-Source-Portierung 0.7 (Dateien `planing/`, `scenes/evidence.c`, `organisa/`) und deine Angaben.
Status: **bestätigt (Stand: nach Rückfrage).**

## 1. Ablauf eines Coups
1. **Stadt:** Ziel wählen, Informationen sammeln (Umsehen, Informant). Ermittlungsstand bestimmt, was in der Planung sichtbar ist.
2. **Organisation:** Team zusammenstellen. Mindestens ein Einbrecher und ein Fahrer. Werkzeug und Kleidung kaufen.
3. **Planung:** Jede Einbrecherin hat eine eigene Aktions-Zeitleiste. **Alle starten am Fluchtwagen.** Die Planung endet erst, wenn jede Einbrecherin den Plan **am Fluchtwagen** abgeschlossen hat (Quelle: `planing/planer.c`, Menüs mit Rückkehr-Aktion).
4. **Ausführung:** Alle Zeitleisten laufen gleichzeitig ab. Wachen folgen ihren aufgezeichneten Routen.
5. **Flucht:** Erst wenn **alle** Einbrecherinnen wieder im Wagen sitzen, fährt der Wagen los.
6. **Auswertung:** Beute, Spuren, Fahndung.

## 2. Abbruch
- Jederzeit auslösbar. Alle Einbrecherinnen gehen sofort zurück zum Wagen.
- Im Quellcode habe ich das Wort „Abbruch“ nicht gefunden. Die Funktion heißt dort **Funk** (`planing/planer.c`, `PLANING_ACTION_RADIO`). Der Name im Spiel kann „Abbruch“ sein, wenn du das so willst.

## 3. Fluchtlogik (nach Original)
- Zeit bis zur Polizei: Polizeizeit minus Zeit seit Alarm (`evidence.c`, `tcEscapeFromBuilding`).
- Die Fluchtzeit der Einbrecherinnen zieht davon ab. Wer rechtzeitig am Wagen ist, entkommt.
- Die Fahrt selbst ist eine Verfolgung: Geschwindigkeit und PS des Wagens, Fahrkönnen des Fahrers, Polizeigeschwindigkeit und Streckenlänge (`tcCalcCarEscape`).
- **Offen:** Ob und wie die Verfolgung in unserem Spiel nachgebildet wird. Aktuell ist sie vereinfacht (feste Fahrzeit aus dem Fahrkönnen).

## 4. Bisher umgesetzt (Stand dieser Datei)
- Start am Fluchtwagen, Wagen fährt erst bei allen an Bord los, Abbruch per Funk-Knopf.
- Ohne Beute gilt der Coup als gescheitert.
- Fahrer ist Pflicht, Fahrkönnen bestimmt die Fahrzeit.
- Personen: festes Budget von 150 Punkten, Lernen nach Erfolg, Sicherungsstufe des Gebäudes steigt.

## 5. Entscheidungen (bestätigt)
1. **Abbruch heißt „Funk: alle zurück“.** Alle Einbrecherinnen gehen sofort zum Wagen.
2. **Flucht:** Keine echte Verfolgungssimulation. Es reicht eine 2D-Szene, in der ein Fahrzeug vor der Polizei flieht. Ob die Flucht gelingt, entscheidet die Zeit bis zur Polizei und die Abfahrt des Wagens.
3. **Wachen dürfen ausgeschaltet werden.** Das geschieht mit Werkzeug oder Kraft, nicht über die Kleidung allein.
4. **Pflicht zur Rückkehr:** Am Ende jedes Plans müssen alle Einbrecherinnen wieder am Fluchtwagen sein. Erst dann kann er abfahren.

## 6. Umsetzungsreihenfolge
1. Abbruch heißt „Funk: alle zurück“ (Name).
2. Wache ausschalten als Aktion in der Planung und Ausführung.
3. 2D-Fluchtszene nach dem Ergebnis.
4. Danach: Drop-down und Scroll-over für die Oberfläche.

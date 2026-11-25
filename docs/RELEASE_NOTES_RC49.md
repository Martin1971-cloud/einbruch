# Release Candidate RC49 – Der Einbruch

## Freie Bewegung in der Planung
- Ein Klick auf eine freie Stelle im Grundriss erzeugt „Hierher gehen“ zu genau diesem Punkt (in Unterfeldern). Die Wegsuche umgeht Wände, Fenster und Vitrinen.
- Wände, Fenster und Vitrinen sind kein Ziel. Die Planung bietet dafür keinen Weg an, die Simulation meldet „kann dort nicht stehen“, falls doch.
- Gegenstände (Tür, Vitrine, Beute) bleiben über ihr Menü.
- Der Weg im Grundriss, der Ablaufplan und die Beschreibung zeigen den Punkt, nahe Orte werden mit ihrem Namen genannt.

## Tests
- Neuer Test `test_frei.gd`: Ziel im Raum wird angefahren, Wand als Ziel wird abgelehnt, Grundriss-Abfrage.
- Alle schnellen Tests bestehen. Ablauf und Kiosk mit kleinem Team: unverändert (Entkommen, +4.300 €).

## Offen
- Die Auflösung ist noch 8 Unterfelder je Feld. Eine Erhöhung auf 16 kommt als nächster Schritt, mit Leistungsprüfung.
- Der Zielpunkt wird nicht auf den Ablauf am Wagen geprüft: Wer nach dem Plan nicht am Wagen steht, bekommt weiter die Warnung der Vorschau.

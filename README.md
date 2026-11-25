# Der Einbruch (Arbeitstitel)

Privates, nicht-kommerzielles Projekt. Eigenständiges Spiel in Godot 4.7.2 (PC).
Die Originalquellen dienen nur als Referenz für Spielprinzip und Daten.
Keine Musik, Grafiken, Namen oder Texte aus dem Original werden übernommen.

Das Spiel ist auf Deutsch und Englisch spielbar.

## Projekt starten

Benötigt: Godot 4.7.2 (Standard-Version, nicht .NET).

    godot --path godot

Oder in der Godot-Oberfläche „Projekt importieren“ und `godot/project.godot` öffnen, dann F5.

## Prüfung

Alle Tests und die Texttabellen-Prüfung auf einmal:

    GODOT=godot bash godot/tools/pruefe_alles.sh

Die Zusammenfassung liegt danach unter `/tmp/einbruch_pruefung/zusammenfassung.txt`.

Einzelne Tests laufen mit:

    godot --headless --path godot --script res://tests/test_sim.gd

`test_sim.gd`: Regeln der Simulation. `smoke_flow.gd`: kompletter Ablauf Stadt → Organisation → Planung → Ausführung → Auswertung.

Die Texttabelle prüft `python3 godot/tools/texte_pruefen.py`: fehlende englische Fassungen (Fehler) und deutsche Texte, die fest im Code stehen (Warnung).

## Struktur

- `godot/scripts/data.gd` – Spieldaten (Gebäude, Crew, Werkzeuge, Fahrzeuge, Lexikon)
- `godot/scripts/sim.gd` – Simulation (Wege, Lärm, Sicht, Alarm, Flucht, Ereignisse)
- `godot/scripts/game.gd` – Spielstand, Speicherplätze, Lernen der Fähigkeiten, Fahndung
- `godot/scripts/texte.gd` – alle Texte, Deutsch und Englisch (Schlüssel und Übersetzung)
- `godot/scripts/screens/` – Titel, Stadt, Laden, Autohaus, Organisation, Planung, Ausführung (3D), Auswertung, Spielende
- `godot/scripts/ui/` – Grundriss, Zeitplan, Lexikon, Journal, Optionen, Stadtkarte
- `godot/assets/` – Bilder, Porträts, Musik
- `godot/tools/` – Prüfung (`pruefe_alles.sh`, `texte_pruefen.py`) und Erzeuger für Musik, Figuren, Bilder

## Spielstand

- Drei Speicherplätze mit Sicherung (`.bak`). Eine ältere oder beschädigte Datei wird wiederhergestellt, wenn möglich.
- Optionen: Musik, Textgröße, Hinweise, Vollbild, einfache Darstellung. Telemetrie nur in Entwicklungsbuilds.

## Bekannte Grenzen

- Vier Gebäude (Kiosk, Kuriositätenladen, Juwelier, Stadtmuseum) und ein Testgebäude zum Ausprobieren.
- Das Museum (Gebäude 4) und der Grundriss sind noch nicht ausbalanciert.
- Die Balance insgesamt ist noch nicht durch Spielen abgeschlossen. Dafür gibt es die Telemetrie in Entwicklungsbuilds.
- Keine Sprachausgabe.
- Die Profiling-Werte stammen aus einer Testumgebung, die GPU-Last im echten Spielablauf ist noch offen.

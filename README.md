# Der Einbruch (Arbeitstitel)

Privates, nicht-kommerzielles Projekt. Eigenständiges Spiel in Godot 4.4 (PC).
Die Originalquellen dienen nur als Referenz für Spielprinzip und Daten.
Keine Musik, Grafiken, Namen oder Texte aus dem Original werden übernommen.

## Projekt starten

Benötigt: Godot 4.7.2 (Standard-Version, nicht .NET). Getestet mit 4.7.2.

    godot --path godot

Oder in der Godot-Oberfläche „Projekt importieren“ und `godot/project.godot` öffnen, dann F5.

## Tests

    godot --headless --path godot --script res://tests/test_sim.gd
    godot --headless --path godot --script res://tests/smoke_flow.gd

`test_sim.gd`: Regeln der Simulation (16 Prüfungen).
`smoke_flow.gd`: kompletter Ablauf Stadt → Organisation → Planung → Ausführung → Auswertung.

## Struktur

- `godot/scripts/data.gd` – Spieldaten (Gebäude, Crew, Werkzeuge, Wachen, Beute)
- `godot/scripts/sim.gd` – Simulation (Wege, Lärm, Sicht, Alarm, Flucht)
- `godot/scripts/screens/` – Stadt, Organisation, Planung, Ausführung (3D), Auswertung
- `godot/scripts/ui/` – Grundriss, Zeitplan, Oberflächen-Helfer
- `godot/tools/make_music.py` – erzeugt die Hintergrundmusik selbst
- `godot/tools/make_sprites.py` – erzeugt die Pixelfiguren selbst

## Bekannte Grenzen

- Ein Ziel (Stadtmuseum Varenhafen).
- Kein Speichern, kein Hauptmenü, keine Einstellungen.
- Balance noch nicht getestet.
- Keine Sprachausgabe.

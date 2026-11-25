# Prüf-Pipeline

- `pruefe_alles.sh`: führt alle Tests in `tests/` headless aus und schreibt eine Zusammenfassung.
  - Aufruf: `GODOT=/pfad/zu/godot tools/pruefe_alles.sh /tmp/pruefung`
  - Vor dem ersten Lauf einmal den Import ausführen: `godot --headless --path . --import`.
  - Rückgabe 0 bei grün, 1 bei Fehlern. Damit lässt sie sich in CI oder vor jedem Release einhängen.
- `balance_lauf.gd`, `kiosk_team.gd`, `kiosk_laerm.gd`: Balancing-Läufe mit Ausgabe (keine Pass/Fail-Prüfung).

# Hinweise für die Arbeit am Projekt

## Gebäude und Dekoobjekte
- Bei jedem neuen Gebäude (und bei Änderungen an Grundrissen) Dekoobjekte ohne Beute so setzen, dass sie Platz haben:
  - Die Anlaufseite jedes Dekoobjekts ist frei und vom Eingang aus erreichbar.
  - Das Objekt ist nicht eingeschlossen (mindestens zwei freie Nachbarfelder).
  - Kein anderes Objekt (Beute, Tür, Alarmpanel) liegt auf einem der vier Nachbarfelder. Diagonal ist erlaubt, Wände dürfen sein.
- `tests/test_deko_abstand.gd` prüft das für alle Ziele mit Dekoobjekten. Vor dem Commit laufen lassen.
- Dekoobjekte nutzen dieselben Grundrisskacheln wie die Beute (C, S, K) oder die Dekotypen R, Z, P, damit Kollision und Sichtregel gleich sind.

## Prüfung
- Vor jedem Commit: `tools/pruefe_alles.sh` (mit `GODOT=<Pfad zum Godot-Binary>` aufrufen).

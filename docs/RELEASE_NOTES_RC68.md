# Release Candidate RC68 – Der Einbruch

## Planung speichern
- Neuer Bereich in der Planer-Kopfleiste: Name eingeben, „Planung speichern“. Gleicher Name überschreibt.
- Auswahl „gespeicherte Planungen“ und „Laden“. Geladen werden nur die Pläne der Personen, die im Team sind.
- Gespeicherte Planungen stehen je Ziel im Spielstand und bleiben nach dem Neustart erhalten.

## Tests
- Neuer Test `test_plan_speichern.gd`: Speichern und Laden des Spielstands.
- Speichern-Tests, Planung, Klick, Sperre, Warnung und Einsteigen bestehen.

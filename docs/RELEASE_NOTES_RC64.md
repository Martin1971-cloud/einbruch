# Release Candidate RC64 – Der Einbruch

## Objektsperre
- An einem Objekt (Tür, Vitrine, Wertschrank, Wache, Beute) arbeitet immer nur eine Person. Die zweite wartet, bis die erste fertig ist, und das Log sagt es.
- Beute, die schon genommen ist, kann niemand noch einmal nehmen (Anzeige: „genommen“, kein Hinweis mehr im Grundriss).
- Abbruch über Funk gibt alle Sperren frei.

## Tests
- Neuer Test `test_sperre.gd`: zwei Personen am selben Schloss, die zweite wartet, die Kasse wird nur einmal genommen.
- Alle schnellen Tests und der Kioskdurchlauf (Entkommen, +4.300 €) bestehen.

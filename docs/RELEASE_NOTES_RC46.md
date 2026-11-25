# Release Candidate RC46 – Der Einbruch

## Weg 3, Schritt A: feineres Raster in der Simulation
- Bewegung, Sicht und Lärm rechnen jetzt in Unterfeldern. Ein Feld hat 8 × 8 Unterfelder (`SUB = 8` in `sim.gd`).
- Reichweite: Die Person muss höchstens ein Feld Abstand zur Mitte des Objekts haben (orthogonal).
- Sichtweite und Lärm: Abstände in Feldern als Dezimalzahl, Wände werden über die Unterfelder gezählt.
- Wachen, Figuren und Wege bewegen sich in Unterfeldern. Zeit, die am Ende eines Schrittes übrig bleibt, läuft auf dem nächsten Weg weiter.
- Die 3D-Szene und die Planung bekommen die Positionen weiterhin in Feldkoordinaten umgerechnet.

## Bewusst noch nicht geändert
- Die Karte besteht weiterhin aus ganzen Feldern. Wände, Türen und Vitrinen sind also nicht feiner gezeichnet. Das kommt in Schritt B.
- Grundriss und 3D-Ansicht sehen deshalb noch gleich aus.

## Tests
- Alle Tests bestehen, außer den Testdurchläufen mit `--headless` (durchlauf und klein). Die laufen nur mit Anzeige (`xvfb-run` ohne `--headless`) sauber durch. Das gilt auch für den unveränderten Stand.
- Kiosk mit kleinem Team (Teodor + Otto): Entkommen, Auszahlung 12.000 €, Differenz +4.300 €. Das Ergebnis ist gegenüber RC45 unverändert.
- Test mit `SUB = 4` ebenfalls grün, Kiosk-Ergebnis identisch.

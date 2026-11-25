# Release Candidate RC45 – Der Einbruch

## Fehlerbehebung (Punkt 2, 3D-Sichtbarkeit)
- Ursache: Für Otto und Greta (Fahrer) gab es keine Figurenbilder. Eine Person mit Namensschild, aber ohne Bild, ist also ohne Sprite gezeichnet worden.
- Behoben: Figuren für Otto und Greta in `tools/make_figures.py` ergänzt und die Sprites neu erzeugt.
- Sicherheitsnetz: Fehlt ein Sprite, wird eine Ersatzfigur gezeichnet, statt die Person unsichtbar zu lassen. Dazu gibt es eine Warnung in der Konsole.

## Vorher (RC44)
- Großer Bodenblock entfernt, Figuren größer.

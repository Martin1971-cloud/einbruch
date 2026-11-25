# Release Candidate RC51 – Der Einbruch

## Kiosk-Grundriss aus den Originaldaten
- Der Grundriss kommt aus den Objektdaten des Originals (TOBAETA0.DAT, Kiosk Nr. 10). Pixel des Originals = Unterfelder (Auflösung 16, ein Feld = 16 Pixel).
- Erzeugt von `tools/make_kiosk_grundriss.py`: Mauern, Holztür, Wertschrank, Tresen und Kasse als Rechtecke.
- Auflösung bleibt bei 16 Unterfeldern je Feld.

## Änderungen am Kiosk (aus dem Original)
- Eine Tür (Holztür im Süden), die zweite Tür (Hintertür) entfällt.
- Beute: Kassenlade (Kasse), **Wertschrank** (vorher „Schmuckkasten“, an der Stelle des Wertschranks), Zigarettenkartons (am Tresen).
- Die Holztür reicht über mehr als ein Feld. Jedes Türunterfeld gehört zur nächsten Tür, damit sich die Tür als Ganzes öffnet.
- Polizeizeit 600 s, Lautstärkegrenze 200, Gewichte nach Original (aus RC50).

## Tests
- Alle schnellen Tests bestehen, außer den Stellen, die auf die alte Kartenstruktur zeigten. Die sind angepasst.
- Kioskdurchlauf mit kleinem Team (Teodor + Otto): Entkommen, +4.300 €, drei Beutestücke.

## Bekannt offen
- Die 3D-Kamera ist noch auf den alten Ausschnitt eingestellt, das Gebäude erscheint nicht zentriert.
- Die Wände in 3D wirken dicker als im Grundriss (Rechtecke werden auf ganze Felder abgerundet).
- Die Figur der Wache entfällt im Kiosk (keine Wache im Original).
- Der Tresen ist Hindernis, aber nicht Beute.

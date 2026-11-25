# Release Candidate RC50 – Der Einbruch

## Referenzdaten aus dem Original
- Kiosk: Polizeizeit 600 s, Lautstärkegrenze 200 (neue Felder `police_time` und `max_volume` je Ziel).
- Kiosk-Gewichte: Kassenlade 0,5 kg (Geld, 500 g im Original), Zigarettenkartons 2 kg (Zigarrenkiste).
- Werkzeug-Gefahr, Lautstärke, Schaden und Bruch je Objekt sind dekodiert (Referenz in `docs/REFERENZ_ORIGINALDATEN.md`).
- Die Dekodierer liegen in `tools/`: `decode_dat.py`, `decode_rel.py`, `referenz_gebaeude.py`.

## Weg 3: Auflösung 16 Unterfelder je Feld
- `SUB = 16`. Der feine Grundriss wird über `Sim.fine_spec` auf die aktuelle Auflösung umgerechnet (Daten geben `sub: 8` an).
- Bewegung, Sicht, Lärm und Reichweite arbeiten in Unterfeldern wie vorher.

## Tests (bei Auflösung 16)
- Alle schnellen Tests bestehen (inklusive `test_frei`, dessen Koordinaten jetzt umgerechnet werden).
- Kiosk mit kleinem Team und Ablauf-Test (Stadt bis Auswertung) mit Anzeige bestanden. Ergebnis: Entkommen, +4.300 €.
- 3D-Ausführung: Gebäude, Türen, Vitrinen und Figuren unverändert dargestellt.

## Offen
- Schloss → Fähigkeit und Mindeststufen (Dietrich: Datei 100, bei uns 25) sind nicht geklärt.
- Die Einheit des Gebäudewerts ist unklar (Original 380, bei uns 20.000 €).
- Der Wertschrank mit Geld fehlt im Kiosk. Die Originaldaten zeigen, dass er mit Brecheisen zu öffnen ist.

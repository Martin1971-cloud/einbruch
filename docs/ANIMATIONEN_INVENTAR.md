# Animationen: Inventar (Stand RC75) und Bedarf aus dem Original

## Vorhanden
**Person (2D und 3D):**
- Gehen (Schrittfolge, Blickrichtung), Atmen im Stehen.
- Werkzeug am Schloss: Funken an der Hand (2D), Zittern (3D).
- Öffnen: Bogen (2D), leichtes Schwanken (3D).
- Aufnehmen: Bücken, Punkt steigt auf (2D und 3D).

**Objekte (3D):**
- Tür: schwingt um die Angel auf und zu.
- Wertschrank: Tür schwingt auf, sobald der Wertschrank geöffnet ist.
- Kassenschublade: gleitet heraus, sobald die Kasse geöffnet ist.
- Beute am Objekt: pulsiert, solange daran gearbeitet wird.
- Stahltür: grau in 3D, nur mit Schneidbrenner oder Stethoskop (Testgebäude).
- Alarmpanel: Lampe blinkt rot bei Alarm, grün wenn überbrückt (Testgebäude).
- Ausstellungskasten: Glasdeckel hebt sich, sobald die Vitrine offen ist (Testgebäude).
- Gemälde an der Wand: verschwindet, wenn es abgenommen ist (Testgebäude, ohne Werkzeug).
- Steuerkasten (Klappe): die Klappe am Alarmpanel öffnet sich, sobald das Panel überbrückt ist (Testgebäude).
- Scheinwerfer: leuchten bei Alarm (Testgebäude, am Eingang).
- Alarmanlage Sirene: blinkt und dreht sich bei Alarm (Testgebäude, auf dem Dach).

**Objekte (2D):**
- Tür: Öffnungsbogen.
- Beute: Markierungspunkt (ohne Maus), Bild bei Mausberührung.
- Fluchtwagen: Position und Kennzeichnung.

## Fehlt (nach Häufigkeit in den Originaldaten)
| Objekt (Original-Typ) | Anzahl in Gebäuden | Animation |
|---|---|---|
| Mauer (9208) / Mauerecke (9209) | 5620 / 479 | keine nötig |
| Holztür (9201) / Stahltür (9202) | 183 / 72 | Öffnen auch in 2D |
| Fenster (9234) | 165 | Aufbrechen: Riss, Scherben, Glas fällt |
| Sessel, Sofa, Tisch, Bett, Sitzbank | über 150 | keine (Dekoration) |
| Scheinwerfer (9269) | 106 | Licht an/aus bei Alarm |
| Ausstellungskasten (9243) | 74 | Glas: Riss, Öffnen |
| Gemälde (9206) / Bild (9265) | 65 / 66 | Abnehmen: Bild verschwindet vom Haken |
| Steuerkasten (9213) | 47 | Klappe öffnen (Strom) |
| Sockel (9261) | 46 | keine |
| Tresen (9223) | 46 | keine |
| Statue (9233) | 45 | Verschieben beim Tragen |
| Fass (9289) | 41 | Rollen (optional) |
| Alarmanlage (9210, 9211, 9212) | 33 + 21 + 7 | Blinklicht, Sirene |
| Spiegel (9231) | 30 | Zerbrechen (optional) |
| Wertschrank (9204) | 27 | Tür (vorhanden) |
| Bücherregal (9241) | 27 | keine |
| Kasten (9203) | 25 | Tür öffnen |
| Mikrophon (9264) | 24 | Erkennung (Lauschen), Anzeige |
| Treppe (9238) | 24 | Hoch- und Runtergehen (Etagen) |
| Stahlschrank (9228), Panzerschrank (9205) | 14 + 8 | Tür wie Wertschrank |
| Kasse (9262) | 7 | Schublade (vorhanden) |
| Stechuhr (9266) | 11 | keine |
| Kiste (9288), Holzkiste (9304) | 17 + 6 | Deckel öffnen (optional) |
| Postsack (9306) | 5 | Tragen (wie Beutesack) |

**Personen-Animationen des Originals (14 Typen, `data/tcdata.h`):**
- `ANM_WORK_UP/DOWN/LEFT/RIGHT`: arbeiten an einem Objekt in vier Richtungen (wir haben das pauschal).
- `ANM_ELEKTRO`: Arbeit an Elektronik (Alarmanlage, Steuerkasten).
- `ANM_DUSEL` und `ANM_DUSEL_POLICE`: sich verstecken / Wache bekämpft.
- `ANM_MAKE_CALL`: Telefon (Alarm melden).
- `ANM_MOVE_*` und `ANM_STAND`: gehen und stehen.

**Fahrzeuge:** 27 Automodelle (Jaguar XK 1950, Bentley Continental 1952, Morris Minor, Fiat Topolino, Pontiac Streamliner u.a.). Heute gibt es nur die Limousine im Spiel. Fahren, Einparken und Ein-/Aussteigen sind nicht animiert.

**Bilder:** Gemälde werden abgenommen, die Position an der Wand ist sichtbar.

## Empfehlung für die Umsetzung (nach Aufwand)
1. **Fenster aufbrechen** (165 Objekte): Riss im Grundriss, in 3D Scherben und Glas. Braucht eine Aktion in der Simulation.
2. **Tresore und Stahlschränke** (49 Objekte): Tür-Animation wie Wertschrank, dafür ein Modell mit Tür.
3. **Bilder abnehmen** (131): Bild verschwindet vom Haken, Animation kurz.
4. **Alarmanlage** (61): Blinklicht und Sirene bei Auslösung.
5. **Treppe** (24): gehört zur Etagen-Arbeit.
6. **Fahrzeuge** (27 Modelle): erst relevant, wenn es mehrere Fluchtwagen gibt.

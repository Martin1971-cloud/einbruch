# Der Einbruch – Game Design Document, RC1

Arbeitstitel. Privates, nicht-kommerzielles Projekt. Ziel-Engine: Godot 4.x, Plattform PC.

Dieses Dokument beschreibt das Systemmodell des RC1. Die Simulationslogik liegt in
`engine/heist_sim.py`, die Ausgangsdaten in `data/heist_rc1.json`.

---

## 1. Grundprinzip

Ein Coup ist ein **Wettlauf zwischen Planung und Wahrnehmung**. Der Spieler plant
Aktionen von Komplizen auf einer Zeitleiste. In der Ausführung entscheiden
Werkzeuge, Lärm, Spuren und Sichtlinien, ob Wachen und Streifen misstrauisch werden.
Jeder Fehler startet eine Alarm-Kette mit Polizei-Countdown. Gewonnen ist, wer
mit der Beute vor Ablauf des Countdowns den Fluchtwagen erreicht.

Zwei Darstellungen, ein Grundriss:

- **Planung (2D, Draufsicht):** Zeitleiste, Wegelinien, Sichtkegel und Lärmradien
  werden sichtbar gemacht. Der Spieler sieht Risiken und Zeiten vor der Ausführung.
- **Ausführung (3D):** Dieselbe Geometrie, aber mit Bewegung, Licht und Geräuschen.
  Die Logik ist identisch, nur die Darstellung unterscheidet sich.

## 2. Der Systemkreislauf

### Phase 1 – Planung
1. Der Spieler weist jedem Komplizen Aktionen auf einer Timeline zu
   (`USE_TOOL`, `CLOSE_DOOR`, `SET_FLAG`, `WAIT_FOR_FLAG`, `CALL_DRIVER` …).
2. Synchronisation erfolgt über Flags. `WAIT_FOR_FLAG` blockiert, bis ein anderer
   Komplize `SET_FLAG` gesetzt hat.

### Phase 2 – Ausführung (Tick-Loop, noch nicht implementiert, siehe Abschnitt 7)
1. **Werkzeuge & Sabotage:** Dauer, Lärm und Spuren aus Objektwerten und Skills.
   Sabotage verändert das Sicherheitsnetz (Strom, Alarmanlage, Telefon, Sensoren).
2. **Event-Bus:** Lärm und sichtbare Schäden (`is_destroyed`) gehen an Sensoren
   und KI-Entitäten.
3. **KI-Wahrnehmung:** Wachen und Streifen berechnen Verdacht (0–100) aus
   Sichtkegel und gedämpftem Lärm und wechseln zwischen vier Zuständen.
4. **Eskalation & Flucht:** Erreicht eine KI Stufe `ALARMED` oder löst ein Sensor
   aus, startet der Polizei-Countdown. Der Fluchtwagen muss vorher gerufen
   werden und rechtzeitig ankommen.

## 3. Formeln

Alle Formeln stammen aus der Spezifikation und sind in `engine/heist_sim.py` umgesetzt.

**Werkzeug-Dauer (s):**
`T = base_time · (1 + obj / 100) · (1 − skill / 150)`

**Werkzeug-Lärm (dB):**
`L = base_noise · (1 + obj / 200) · (1 − skill / 200) · Π noise_mult(gear)`

**Spuren (Beweise):**
`E = evidence · Π evidence_mult(gear)`

`obj` ist die **Komplexität** bei TECH/ELECTRONICS-Werkzeugen und der **Widerstand**
bei FORCE. Ist `obj > max_level`, verweigert das Werkzeug den Einsatz.

**Lärmdämpfung am Ziel (dB):**
`L_an = L − Abstand · distance_damping − Wände · wall_damping`
Sensor oder KI reagiert, wenn `L_an > Schwelle`.

**Verdachts-Zuwachs durch Lärm:**
`Δ = (L_an − Schwelle_KI) · 2.5`

**Sichtrate (pro Sekunde):**
`V = 40 · (1 − d / vision) · Licht · Tür_Mult · Kleidungs_Mult`
- Licht: 0.2 im Dunkeln, sonst 1.0
- Tür_Mult: 2.5, wenn die Tür zerstört ist
- Kleidungs_Mult: kleinster `vis_mult` der getragenen Kleidung

**Verdachtsstufen:**

| Verdacht | Zustand       | Verhalten                          |
|---------:|---------------|------------------------------------|
| 0        | `PATROL`      | normaler Rundgang                  |
| < 40     | `ALERT`       | bleibt stehen, lauscht             |
| < 80     | `INVESTIGATE` | läuft zur Lärmquelle / offenen Tür |
| ≥ 80     | `ALARMED`     | startet Alarm-Kette                |

Ein ausgelöster Alarm wird nicht mehr zurückgenommen. Verdacht sinkt sonst mit
`suspicion_decay_per_sec`.

**Polizei-Countdown:**
- Wache (`INDOOR_GUARD`): `district_police_response_sec` + Reaktionszeit der KI
- Streife (`STREET_PATROL`): 12 s + Reaktionszeit
- Sensor (Mikrofon): `district_police_response_sec`
- Telefonleitung gekappt: +20 s Reaktionszeit für Wachen (sie müssen nach draußen)

**Flucht:** Gelingt, wenn der Fluchtwagen (Ankunft `pickup_eta_sec`) vor Ablauf
des Countdowns eintrifft.

## 4. Figuren, Werkzeuge, Ausrüstung

- **Komplizen:** Rolle, Position, Skills (TECH, FORCE, ELECTRONICS), Ausrüstung,
  Zeitleiste.
- **Werkzeuge:** Typ, Maximallevel, Basisdauer, Basislärm, ob das Objekt zerstört
  wird, Spuren, Gewicht.
- **Ausrüstung:** Handschuhe, Sneakers, dunkler Anzug. Jede Ausrüstung modifiziert
  Spuren, Lärm und Sichtbarkeit.

## 5. Sicherheitsnetz

- **Knoten** (Telefonleitung, Alarmanlage, Tür, Safe) mit Widerstand, Komplexität
  und Zustand.
- **Sensoren** (Mikrofone) mit Schwelle, Position und Status. Die Alarmanlage
  steuert Sensoren und kann sie abschalten.

## 6. Designregeln für das Spiel

- Jeder Fehler ist sichtbar. Es gibt kein unsichtbares Würfeln im Hintergrund.
- Planung zeigt Risiken vorher an: Lärmradien, Sichtkegel, Zeitbedarf.
- Der Spieler gewinnt durch Vorausdenken, nicht durch Reaktion auf Zufall.
- Brachiale Wege sind möglich, kosten aber Spuren und Zeit.

## 7. Nicht in RC1 enthalten

- Tick-Loop, der alle Timelines parallel sekundengenau abspielt.
- Zeitleisten-Parser und Flag-Synchronisation (`WAIT_FOR_FLAG`, `SET_FLAG`).
- UI für Planung (Drag & Drop, Risiko-Anzeige).
- 3D-Ausführung in Godot.

## 8. Offene Balancing-Fragen

Siehe `docs/RELEASE_NOTES_RC1.md`, Abschnitt "Befunde".

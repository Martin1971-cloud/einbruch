# Release Candidate RC1 – Der Einbruch (Arbeitstitel)

## Inhalt
- `data/heist_rc1.json` – Balancing-Konfiguration und Laufzeit-Startzustand
- `engine/heist_sim.py` – Simulations-Engine (Werkzeuge, Lärm, KI, Alarm, Flucht)
- `tests/test_heist_sim.py` – 20 Unit-Tests
- `docs/GDD_RC1.md` – Systemmodell und Formeln

## Status
- Alle 20 Tests bestanden (`python3 -m unittest discover -s tests`).
- Engine ist eine reine Logik-Schicht ohne Abhängigkeit von Godot. Sie soll
  später über ein Godot-Skript oder eine Portierung eingebunden werden.

## Korrekturen gegenüber der Spezifikation
1. **`guard_01.pos` war ungültiges JSON** (`"pos":,`). Gesetzt auf `[4, 2]`.
   Das ist eine Annahme und sollte geprüft werden.
2. **Streifen-Bonus** erkannte Streifen über den Text `"patrol" in source`.
   Jetzt wird der KI-Typ `STREET_PATROL` ausgewertet.
3. **Verdachtsabbau** (`suspicion_decay_per_sec`) war konfiguriert, aber nicht
   verwendet. Jetzt in `decay(dt)` umgesetzt. Ein ausgelöster Alarm wird nicht
   zurückgenommen.
4. **Kleidung** (`vis_mult`) war konfiguriert, aber nicht verwendet. Jetzt in die
   Sichtrate eingerechnet (kleinster Wert der getragenen Kleidung).
5. **Polizei-Countdown** hatte keinen Ablauf. `tick_police(dt)` setzt ihn herunter
   und meldet das Eintreffen der Polizei.
6. **Schreibweise** im Event-Log bleibt ASCII (ohne Umlaute), damit das Protokoll
   auch in Konsolen und Godot-Debug-Ausgaben sauber lesbar ist.

## Befunde (Balancing, bitte entscheiden)
Die Beispielwerte im Text der Spezifikation stimmen nicht mit den Formeln überein.
Die Formeln wurden nicht geändert. Die Beispiele sollten angepasst werden.

| Fall | Text der Spezifikation | Formel (RC1) |
|---|---|---|
| Lockpick an der Tür (Matt, mit Sneakers) | 13 s, 5 dB | 11,47 s, 1,6 dB |
| Lockpick an der Tür (ohne Sneakers) | – | 11,47 s, 4,0 dB |
| Brecheisen an der Tür (ohne Ausrüstung) | 3,2 s, 65 dB | 3,67 s, 58,5 dB |
| Brecheisen an der Tür (Matt, mit Sneakers) | 65 dB, löst Mikrofon aus | **23,4 dB, Mikrofon bleibt still** |

**Wichtigster Befund:** Matts Sneakers machen das Brecheisen leise genug, dass das
Mikrofon nicht anschlägt. Das ist eine Designentscheidung:
- Option A: Brecheisen als Laut-Werkzeug festlegen, unabhängig von der Ausrüstung.
- Option B: Der leise Weg mit Sneakers ist gewollt. Dann braucht das Brecheisen
  einen anderen Nachteil (z. B. mehr Spuren oder Zeit).

## Bekannte Grenzen von RC1
- Kein Tick-Loop: Timelines werden nicht sekundengenau parallel abgespielt.
- Keine Flag-Synchronisation durch Zeitleisten (`WAIT_FOR_FLAG` wird noch nicht ausgewertet).
- Keine Positionsbewegung der KI. Positionen sind statisch.
- `evaluate_vision` ist ein Einzelschritt. Die Wahrnehmung über Zeit muss der
  Tick-Loop liefern.

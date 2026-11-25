# Release Candidate RC2 – Der Einbruch (Arbeitstitel)

Erster vollständig durchspielbarer Ablauf in Godot 4.4 (PC).
Ein Ziel (Stadtmuseum Varenhafen), vier Crew-Mitglieder, ein Fluchtwagen.

## Spielablauf
1. **Stadt:** Umsehen (1 Std.) und Informant (500 DM) erhöhen den Ermittlungsstand (0–2).
   Stand 1 zeigt die Wachrouten, Stand 2 zusätzlich Alarmpanel und Mikrofone.
2. **Organisation:** Team (2–4 Personen), Kleidung pro Person, Werkzeug und Fluchtwagen kaufen.
3. **Planung (2D):** Aktionen per Drag & Drop auf die Zeitleisten ziehen
   (Gehen, Werkzeug, Beute nehmen, Warten, Fluchtwagen rufen, Signal setzen/warten).
   Die Vorschau zeigt Ergebnis, Beute, Auszahlung und Fahndung.
4. **Ausführung (3D):** Dieselbe Simulation in Echtzeit, Geschwindigkeit 1x/4x/16x, Pause.
5. **Auswertung:** Auszahlung (60 % des Beutewerts), Fahndungsstand, Zeit. Bei 100 % Fahndung ist das Spiel vorbei.

## Regeln (Auszug, aus dem Original abgeleitet)
- **Streife rückt erst nach einem Alarm aus.** Auslöser sind Lärm am Mikrofon oder eine Wache,
  die Verdacht schöpft und Alarm schlägt. Die Streife fährt dann zum Eingang und sucht das Gebäude ab.
- **Wachen** sehen (Sichtkegel, Wände blockieren) und hören (Lärm mit Dämpfung). Verdacht 0–100:
  Stufe ALERT (<40), INVESTIGATE (<80), ALARMED (≥80, Alarm).
- **Polizei:** 60 s nach Wachenalarm (+ Reaktionszeit), 12 s nach Streifenalarm. Wer bis dahin nicht am Fluchtwagen ist, wird festgenommen.
- **Werkzeug:** Dauer, Lärm und Spuren nach den RC1-Formeln. Zu stabile Objekte werden verweigert.
- **Tragelast:** 3 + Gewalt/25 pro Person. Zu schwere Beute kann nicht genommen werden.
- **Abbruch:** Alle Aktionen fertig, aber nicht am Fluchtwagen, gilt als gescheitert.

## Änderungen gegenüber RC1
- Tick-Loop, Zeitleisten und Synchronisation über Signale sind implementiert.
- Die Streife ist ereignisabhängig (siehe oben), vorher war sie ein Dauerbeobachter.
- Eigene Musik (drei Loops, mit Python selbst erzeugt, `tools/make_music.py`).
- Alle Namen, Orte und Gegenstände sind neu. Die Karte ist eine eigene Erfindung.

## Tests
- `tests/test_sim.gd`: 16 Prüfungen (Karte, Wegfindung, Formeln, Mikrofon, Wachen, Abbruch, Flucht).
- `tests/smoke_flow.gd`: durchläuft Stadt → Organisation → Planung → Ausführung → Auswertung.
- `tests/screenshots.gd`: Bildschirmfotos (mit `xvfb-run`).

## Bekannte Grenzen
- Nur ein Ziel. Weitere Ziele folgen über `GameData.TARGETS`.
- Keine Stimmen, nur Text. Keine Sprachausgabe.
- Die Wache lässt sich nicht ausschalten, nur umgehen. Das ist der nächste Schritt.
- Die Balance ist nicht getestet. Die Vorschau zeigt die Ergebnisse, Feintuning steht aus.
- Die Ausführung läuft ohne Kamerasteuerung (feste Vogelperspektive).

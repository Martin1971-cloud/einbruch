# Balancing: offene Aufgabe (nach Fertigstellung des Kiosks)

- Ziel: Beutewerte, Kosten, Polizeizeit und Schwierigkeit für alle Gebäude gegeneinander prüfen und festlegen.
- Ausgangspunkt: Kiosk „Zum Anker“ mit 20.000 € Beute (Kasse 4.000 €, Wertschrank 16.000 €). Der Originalwert 380 wird nicht übernommen, weil die Einheit unbekannt ist.
- Original-Relation (Referenz, `docs/REFERENZ_ORIGINALDATEN.md`) nur als Ordnung nutzen, nicht als Geldbetrag.
- Prüfen je Gebäude: Beute, Teamkosten, Fahrt, Polizeizeit, Schwierigkeit der Schlösser und Wachen, Ergebnis der Testdurchläufe.
- Testdurchläufe mit Teams unterschiedlicher Größe, bevor die Werte festgelegt werden.

## Stand: Balancing der ersten drei Gebäude
Auszahlung = 60 % der mitgenommenen Beute (sim.gd). Kosten: Honorare, Wagenmiete, Ermittlung, Werkzeug.

| Gebäude | Beute gesamt | Polizeizeit | Schlösser (Komplexität) | Sicherung |
|---|---|---|---|---|
| 1 Kiosk „Zum Anker“ | 20.000 € | 600 s (Original) | Eingang 20 | keine |
| 2 Kuriositätenladen „Alte Gasse 7“ | 115.000 € | 880 s (Original) | Eingang 35, Hintertür 25, Vitrinen 40 | keine Alarm, keine Wache |
| 3 Juwelier „Silberstern“ | 180.000 € | 600 s (kürzer als Original 900: Alarm wird direkt aufgeschaltet) | Eingang 40, Stahltür 60, Alarmpanel 45 | Alarmpanel, Mikrofon, Glasbruchmelder am Schaufenster |

Realistische Sicherungen, die eingebaut wurden:
- Glasbruchmelder am Schaufenster: reagiert schon auf kleinen Lärm (Schwelle 15). Der Glasschneider ist leise genug, das Brecheisen nicht.
- Mikrofon im Verkauf (Schwelle 25).
- Alarmpanel mit Überbrückung über Elektronik-Werkzeug.
- Stahltür zum Tresor: nur Schneidbrenner oder Stethoskop.

Offen: Werte im Testdurchlauf mit verschiedenen Teamgrößen prüfen (siehe oben), Museum ist noch nicht bewertet.

## Testdurchläufe (tests/balance_lauf.gd, ohne Grafik)
Team = Teodor allein macht den Einbruch, die anderen gehen zum Wagen. Kosten = Honorare + Wagenmiete 1.500 €.

| Gebäude | Team 1 (Teo + Otto) | Team 2 (+ Ilja) | Team 3 (+ Rosa) |
|---|---|---|---|
| Kiosk | +4.300 € | −1.700 € | −5.200 € |
| Kuriositätenladen | +29.500 € | +23.500 € | +20.000 € |
| Juwelier | +100.300 € | +94.300 € | +90.800 € |

Befunde:
- Der Kiosk ist mit mehr als einer Person unrentabel. Der Wert von 20.000 € wurde früher bestätigt und ist nicht geändert. Offene Entscheidung: Honorare für kleine Orte senken, oder Warnung im Planer, dass ein großes Team sich nicht lohnt.
- Im Juwelier hat der Schneidbrenner an der Stahltür keinen Alarm ausgelöst. Der Alarm ist also mit dieser Vorgehensweise nicht gefährlich. Das muss im Test mit lauterem Vorgehen oder mit dem Glasbruchmelder geprüft werden.
- Der Kuriositätenladen ist mit allen Teamgrößen profitabel.

## Komplette Testreihe (nach dem Balancing)
- 31 Tests: 30 bestanden. `test_durchlauf` scheitert weiter am Frame-Budget (4000 Frames). Ein Lauf mit 40000 Frames war in dieser Umgebung nicht in angemessener Zeit fertig und wurde abgebrochen. Ursache ist die Geschwindigkeit der Rendering-Umgebung, nicht die Logik.
- Testdurchläufe ohne Grafik (`tests/balance_lauf.gd`): Ergebnisse siehe oben.
- Ungültiger Versuch verworfen: Brecheisen an der Stahltür ist nach den Regeln nicht zulässig (nur Schneidbrenner oder Stethoskop).

## Kiosk mit mehreren Personen (tests/kiosk_team.gd, Arbeitsteilung über Signal „tuer“)
| Team | Zeit | Auszahlung | Kosten | Ergebnis |
|---|---|---|---|---|
| Teo allein | 71 s | 12.000 € | 7.700 € | +4.300 € |
| Teo + Ilja (Ilja öffnet den Wertschrank) | 55 s | 12.000 € | 13.700 € | −1.700 € |
| Teo + Ilja + Rosa (Rosa wartet, dann Tresor-Beute) | 75 s | 12.000 € | 17.200 € | −5.200 € |

Befund: Die Beute des Kiosks ist klein und passt in die Hände einer Person. Mehr Personen sparen Zeit, bringen aber keine Beute und kosten Honorar. Ergebnis mit Team von zwei Personen ist negativ.
Entscheidung offen: Honorar für kleine Orte senken, oder Warnung im Planer, oder den Kiosk bewusst als Einzel-Einstieg lassen.

## Entscheidung: Teamgröße ist Spielerwahl
- Der Spieler entscheidet die Teamgröße. Größeres Team = mehr Honorar, dafür schneller. Kleines Team = mehr Gewinn, dafür langsamer.
- Keine Pflicht-Änderung der Werte für kleine Orte. Der Kiosk bleibt, wie er ist (20.000 €).
- Zeit wird bei schweren Gebäuden ein Faktor: Die Polizeizeit (`police_time`) ist schon ein Zeitdruck je Gebäude (Kiosk 600 s, Laden 880 s, Juwelier 600 s). Künftig kann die Zeit zusätzlich die Lage verschärfen, etwa über Wachrundgänge oder Schichtwechsel, die nach einer bestimmten Zeit kommen.
- Für die Planung: Die Teamgröße soll im Planer sichtbar sein mit Kosten und voraussichtlicher Zeit, damit die Entscheidung bewusst fällt (offen, nicht umgesetzt).

## Stufen für Werkzeuge und Autos (Laden und Autohaus)
Stufe = Anzahl erfolgreich abgeschlossener Gebäude. Gesperrte Artikel stehen im Laden mit dem Hinweis „gesperrt, ab „…““ und sind nicht kaufbar. Der Startbetrag ist 80.000 €.

| Stufe (ab) | Werkzeuge | Autos |
|---|---|---|
| 0 (Anfang) | Dietrich-Set 300 €, Schlosstecher 150 €, Brecheisen 200 €, Hammer 60 €, Glasschneider 120 € | Limousine (Miete 1.500 € je Einbruch) |
| 1 (nach Kiosk) | Axt 120 € | Kombi Grau 15.000 € |
| 2 (nach Kuriositätenladen) | Bohrmaschine 700 €, Elektroset 900 €, Stethoskop 500 €, Schneidbrenner 2.500 € | Sportwagen 42.000 € |
| 3 (nach Juwelier) | Chloroform 250 €, Kernbohrer 3.000 €, Dynamit 1.500 € | – |

Prüfung je Gebäude (tests/test_stufen.gd):
- Kiosk: Dietrich-Set (Stufe 0). Ausreichend.
- Kuriositätenladen: Dietrich-Set, Glasschneider für das Schaufenster (Stufe 1, nach dem Kiosk verfügbar).
- Juwelier: Stahltür braucht Schneidbrenner oder Stethoskop (Stufe 2, nach dem Laden verfügbar), Alarmpanel Elektroset (Stufe 2).
- Museum: Wache braucht Chloroform (Stufe 3, nach dem Juwelier verfügbar).
Die Geldlage passt: Der Start mit 80.000 € deckt Stufe 0 und 1 ab, der Sportwagen ist nach dem Laden mit 115.000 € Beute erreichbar.

### Regel: Werkzeug nach Objekt
Sobald ein Objekt im Gebäude vorkommt, ist sein Werkzeug ab dem ersten Gebäude mit diesem Objekt verfügbar, auch wenn man es mit einem anderen Werkzeug aufbrechen könnte:
- Fenster oder Glasvitrine: Glasschneider (Stufe 0, weil der Kiosk schon ein Schaufenster hat). Das Museum hat Glasvitrinen (Flag `glasvitrinen`).
- Stahltür oder Tresor: Schneidbrenner, Stethoskop, Kernbohrer oder Dynamit (Stufe 2, Juwelier).
- Alarmpanel: Elektroset (Stufe 2, Juwelier).
- Wache: Chloroform (Stufe 3, Museum).
- Schloss: Dietrich-Set (Stufe 0).
Geprüft in `tests/test_stufen.gd`, das die Anforderungen aus den Gebäudedaten liest.

## Umgesetzt: Ablauf, Logik, Grafik (Punkte aus dem letzten Schritt)
- Planer: Vorschau zeigt oben Teamgröße, Kosten (Honorar, Wagen), Gewinn und Dauer. Alarme nennen den auslösenden Melder.
- Testdurchlauf (`test_durchlauf`): treibt die Simulation direkt voran statt auf Bilder zu warten. Läuft jetzt in wenigen Sekunden und besteht.
- Laden und Autohaus: Sperre mit Hinweis geprüft (`test_laden_sperre`).
- Glasbruchmelder: Alarm mit Namen im Protokoll und in der Planer-Vorschau (`test_melder`).
- Ortsbilder: in der Stadtkarte geprüft (Juwelier und Kuriositätenladen).
- Komplette Testreihe: 35 Tests, alle bestanden.

## Lautstärke im Planer
- Die Simulation merkt sich die lauteste Lautstärke des Einbruchs (`peak_loud`) und die Grenze des Gebäudes (`max_volume`).
- Die Vorschau zeigt direkt unter dem Team: Lautstärke in dB und die Grenze. Grün bis 70 % der Grenze, gelb bis zur Grenze, rot darüber (dann wird Alarm ausgelöst).
- Geprüft mit `test_laerm`, `test_sim`, `test_planung_klick`, `test_juwelier`, `test_melder`.
- Lautstärke je Aktion: Jeder Ablaufschritt speichert seine Lautstärke. Im Zeitplan steht bei lauten Schritten (über 5 dB) die Zahl am Balken und im Tooltip „Lärm: x dB“. Geprüft mit `test_laerm_aktion` (Gehen 5 dB, Brecheisen 57 dB).
- Zeitplan mit Brecheisen-Plan geprüft (`tests/pruef_brecheisen.gd`): roter Schild „22 dB“ am Brecheisen-Balken, auch bei kurzer Dauer. Der Wert ist niedriger als die 57 dB ohne Kleidung, weil Teodor im Planer mit seiner Ausrüstung antritt (Kleidung dämpft den Lärm).
- Kiosk-Plan geprüft (`tests/kiosk_laerm.gd`): Dietrich-Set ohne Kleidung 3,7 bis 4,1 dB, Spitze 5 dB (Gehen), also leise und ohne Schild im Zeitplan. Brecheisen mit Gummisohlen (Dämpfung 0,4) 22,9 dB, mit Schild. Ohne Kleidung wären es 57 dB. Die Gummisohlen dämpfen also den Brecheisen-Lärm deutlich.

## Hinweissystem (erste drei Hinweise)
- Texte liegen in `GameData.HINTS` (Schlüssel: glas, treppe, laut).
- Jeder Hinweis erscheint nur einmal. Gesehene Hinweise stehen im Spielstand (`hints_seen`) und werden beim Neustart zurückgesetzt.
- Auslöser: „Glas“ beim ersten Klick auf ein Schaufenster, „Treppe“ beim ersten Klick auf ein Treppenfeld, „Lärm“ wenn eine Aktion lauter als 5,5 dB ist.
- Geprüft mit `test_hinweise` (Text vorhanden, einmalig, Auslösung über den Grundriss) und den Planer-Tests. Sichtbild: `pruef_hinweis.gd`.
- Noch offen: geführte erste Mission, Lexikon, Optionen zum Abschalten der Hinweise.

## Lexikon
- 22 Einträge in `GameData.LEXIKON` (Ermittlung, Honorar, Fluchtwagen, Auszahlung, Gewinn, Dauer, Lautstärke, Alarm, Polizeizeit, Wachrate, Fahndung, Werkzeug, Freischaltung, Tür, Vitrine, Schaufenster, Treppe, Etage, Beute, Mikrofon, Glasbruchmelder, Wache).
- Öffnen mit L von jedem Bildschirm aus oder über „Lexikon (L)“ im Stadtkopf. Esc oder ein zweites L schließt es.
- Suchfeld: filtert nach Begriff und Text (Suche „Lärm“ findet „Lautstärke“).
- Geprüft mit `test_lexikon` (Einträge, Suche, Öffnen und Schließen) und den Screen-Tests. Sichtbild: `pruef_lexikon.gd`.
- Noch offen: geführte erste Mission, Option zum Abschalten der Hinweise.
- Hinweise abschalten: Schalter „Hinweise: an/aus“ im Lexikon, Einstellung im Spielstand (`hints_enabled`). „Alle Hinweise wieder zeigen“ setzt die gesehenen Hinweise zurück. Geprüft mit `test_hinweise`.

## Optionen
- Öffnen mit O von jedem Bildschirm aus oder über „Optionen (O)“ im Stadtkopf. Esc schließt.
- Musik: 0 bis 100 % in 10er-Schritten, sofort wirksam.
- Textgröße in der Planung: 10 bis 18 (nur die Planung, andere Bildschirme haben feste Größen).
- Hinweise an/aus (gleicher Schalter wie im Lexikon).
- Vollbild: sofort wirksam, auf dem Desktop.
- Speicherung in einer eigenen Datei (`user://einbruch_optionen.cfg`), getrennt vom Spielstand.
- Geprüft mit `test_optionen` (speichern, laden, Grenzen, Öffnen) und den Planer-, Hinweis- und Lexikon-Tests. Sichtbild: `pruef_optionen.gd`.
- Noch offen: Farbmodus für Farbenblinde, Schriftgröße außerhalb der Planung.

## Rückblick: Journal
- Öffnen mit J oder „Journal (J)“ im Stadtkopf. Esc schließt.
- Je Einbruch ein Eintrag: Tag und Uhrzeit, Ziel, Ergebnis (mit Symbol und Wort), Auszahlung, Kosten, Gewinn, Dauer, Beute, ausgelöster Alarm (mit Melder), fehlgeschlagene Aktionen (die ersten drei).
- Zusammenfassung oben: Einbrüche, erfolgreiche, festgenommene, Summen.
- Gespeichert im Spielstand (höchstens 200 Einträge), neues Spiel leert es.
- Geprüft mit `test_journal`. Sichtbild: `pruef_journal.gd`. Dabei einen Parse-Fehler behoben (Typangabe).

## Spielende und Speicherplätze
- Spielende: Fahndung 100 oder Pleite (Geld unter den günstigsten Kosten eines Einbruchs, derzeit 6.200 €). Danach der Bildschirm „Spielende“ mit Grund, Bilanz aus dem Journal und den Wegen „Neues Spiel“ oder „Zum Titelbild“. Festnahme beendet das Spiel nicht, sie kostet Auszahlung und erhöht die Fahndung.
- Speicherplätze: drei Plätze, Übersicht mit Tag, Geld und Einbrüchen. Neues Spiel auf belegtem Platz fragt vorher nach. Vor jedem Überschreiben oder Löschen bleibt eine Sicherung (.bak). „Fortsetzen“ lädt den zuletzt benutzten Platz. Der alte Einzelstand wird auf Platz 1 übernommen.
- Geprüft mit `test_spielende` und `test_spielstaende`. Sichtbilder: `pruef_spielende.gd`, `pruef_spielstaende.gd`.

## Tastatur, Bedienung und Barrierefreiheit
- Planung: Leertaste (abspielen oder Pause), Tab und Shift+Tab (Person wechseln), Entf (letzte Aktion zurück), dazu Strg+Z und Esc. Die Kürzel stehen im Lexikon unter „Tastenkürzel“. F1 öffnet das Lexikon.
- Tooltips auf den wichtigsten Planer-Knöpfen (Abspielen, Rückgängig, Speichern, Laden, Vorschau). Noch nicht auf allen Knöpfen.
- Barrierefreiheit: Die Lautstärke-Zeile nennt das Ergebnis mit Wort (leise, hörbar, Alarm), das Journal nutzt Symbole (✔, ✖, ⚠, ✗) und Wörter. Die Farben allein tragen die Bedeutung dort nicht mehr.
- Noch offen: Farben auf der Karte und in der 3D-Ansicht (Sichtfelder, Wachen, Sicherheitsstufen) brauchen Muster oder Symbole, und ein Farbmodus für Farbenblinde wäre sinnvoll.
- Geprüft mit `test_tastatur`, `test_laerm`, `test_planung_klick`, `test_hinweise`.

## Entwickler-Punkte
- Telemetrie (lokal, nur wenn eingeschaltet): Optionen → „Telemetrie (nur lokal)“. Je Einbruch eine Zeile in `user://einbruch_telemetrie.jsonl` (Ziel, Stufe, Teamgröße, Ergebnis, Auszahlung, Kosten, Dauer, Alarmquelle, Fehler, letzte Aktion, Spitzen-dB). Keine Namen. Geprüft mit `test_telemetrie`.
- Prüf-Pipeline: `tools/pruefe_alles.sh` führt alle 47 Tests aus, schreibt eine Zusammenfassung und endet mit 1 bei Fehlern. Letzter Lauf: 47 Tests, 0 Fehler.
- Lokalisierung: Texttabelle `scripts/texte.gd` (Deutsch und Englisch). Umgestellt sind Spielende, Optionen und Journal. Der Rest liegt noch im Code.
- Versionsnummer und Migration: Spielstand trägt `version` (aktuell 2). Ältere Stände werden beim Laden ergänzt. Neuere Versionen werden abgelehnt mit Hinweis. Geprüft mit `test_spielstand_version`.
- Fehlerbericht: Bei einem nicht ladbaren Platz erscheint eine Meldung mit Hinweis. Liegt eine Sicherung vor, wird sie automatisch wiederhergestellt und der Spieler wird informiert. Fehler stehen zusätzlich in `user://einbruch_fehler.log`. Geprüft mit `test_fehlerbericht`.
- Profiling der 3D-Ansicht (`tests/profil_3d.gd`, Software-Rendering): Sichtkegel der Wachen ca. 3,7 ms je Aufruf (der größte Posten), Zustand 0,07 ms, Etagen 0,16 ms. Die Zeit der Grafikkarte ist nicht gemessen; dafür braucht es Messungen auf echter Hardware.
- Noch offen: Lokalisierung der übrigen Texte, Profiling mit echter Grafikkarte, Sichtkegel-Optimierung (Aktualisierung seltener oder nur bei sichtbaren Wachen), Schalter für einfachere Darstellung.

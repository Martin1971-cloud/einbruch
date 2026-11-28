# Oberflächen (Quelle der Wahrheit)

Jede Kachel liegt als PNG in `assets/tiles/`. Die Tabelle steht in `scripts/data.gd` (`OBERFLAECHEN`).
Gebäude verweisen nur auf diese IDs (`oberflaeche` je Ziel). Der Test `tests/test_oberflaechen.gd` prüft die Bezüge.

| ID | Art | Datei | Status |
|---|---|---|---|
| parkett | boden | parkett.png | Standard im Grundriss |
| teppich | boden | teppich.png | im Spiel (Museum) |
| laeufer | boden | laeufer.png | vorhanden, noch nicht genutzt |
| boden_dielen | boden | boden_dielen.png | im Spiel (Kiosk) |
| boden_eiche | boden | boden_eiche.png | im Spiel (Kuriositätenladen) |
| boden_schachbrett | boden | boden_schachbrett.png | im Spiel (Juwelier) |
| boden_marmor | boden | boden_marmor.png | vorhanden, noch nicht genutzt |
| wand_putz | wand | wand_putz.png | im Spiel (Innenwände) |
| vertaefelung | wand | vertaefelung.png | im Spiel (Kuriositätenladen) |
| wand_streifen | wand | wand_streifen.png | Tapete, nicht genutzt |
| wand_damast_gruen | wand | wand_damast_gruen.png | Tapete, nicht genutzt |
| wand_damast_rot | wand | wand_damast_rot.png | Tapete, nicht genutzt |
| mauer | wand | mauer.png | Standard im Grundriss |
| fenster | fenster | fenster.png | Standard im Grundriss |
| rasen | aussen | rasen.png | Standard im Grundriss (außen) |

**Offen:** Außenwand-Kacheln (Backstein, Quaderstein, Naturstein). Erst nach Bildlieferung eintragen.

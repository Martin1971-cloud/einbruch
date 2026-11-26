#!/usr/bin/env python3
"""Prüft die Übersetzungen: gleiche Schlüssel in Deutsch und Englisch, und deutsche Texte direkt im Code.
Aufruf: python3 tools/pruef_texte.py   (Rückgabe 0 = in Ordnung, 1 = Auffälligkeiten)"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTE = ROOT / "scripts" / "texte.gd"
DE_UMLAUT = re.compile(r'"[^"\n]*(?:[äöüÄÖÜß]|\b(?:und|oder|nicht|kein|keine|mit|für|ist|sind|wird|werden|Team|Geld|Wagen|Tür|Stadt|Wache|Einbruch)\b)[^"\n]*"')


def schluessel(part: str) -> set:
    keys = set(re.findall(r'^\s*"([^"]+)":', part, re.M))
    return {k for k in keys if k not in ("de", "en")}


def main() -> int:
    s = TEXTE.read_text(encoding="utf-8")
    de_start, en_start = s.index('"de"'), s.index('"en"')
    de, en = schluessel(s[de_start:en_start]), schluessel(s[en_start:])
    fehler = 0
    # Schlüssel ohne Punkt sind deutsche Begriffe aus den Daten (z. B. „Tür“); sie werden direkt nachgeschlagen.
    fehlt_en = sorted(k for k in de - en if "." in k)
    fehlt_de = sorted(k for k in en - de if "." in k)
    if fehlt_en:
        fehler += 1
        print(f"Auf Englisch fehlen {len(fehlt_en)} Schlüssel:")
        for k in fehlt_en:
            print("  ", k)
    if fehlt_de:
        fehler += 1
        print(f"Nur auf Englisch vorhanden ({len(fehlt_de)}):")
        for k in fehlt_de:
            print("  ", k)
    # Deutsche Texte direkt im Code (ohne texte.gd, ohne Kommentare)
    treffer = []
    for f in sorted((ROOT / "scripts").rglob("*.gd")):
        if f == TEXTE:
            continue
        # Werkzeug-Fähigkeiten in den Daten sind Übersetzungsschlüssel (Texte.t beim Anzeigen)
        if f.name == "data.gd":
            ohne = [z for z in f.read_text(encoding="utf-8").splitlines() if '"ability":' not in z]
        else:
            ohne = f.read_text(encoding="utf-8").splitlines()
        for n, zeile in enumerate(ohne, 1):
            code = zeile.split("#", 1)[0]
            if "Texte.t(" in code:
                continue
            for m in DE_UMLAUT.finditer(code):
                treffer.append(f"{f.relative_to(ROOT)}:{n}: {m.group(0)}")
    if treffer:
        fehler += 1
        print(f"Deutsche Texte direkt im Code ({len(treffer)}):")
        for t in treffer:
            print("  ", t)
    if not fehler:
        print("Übersetzungen in Ordnung.")
    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main())

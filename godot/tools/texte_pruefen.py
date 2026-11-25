#!/usr/bin/env python3
"""Prüft die Texttabelle (scripts/texte.gd) und den Code auf deutsche Texte außerhalb der Tabelle.

Meldet:
- Fehler: Schlüssel, die im Deutschen stehen, im Englischen aber fehlen (Exit-Code 1)
- Hinweis: Einträge im Englischen ohne deutsches Gegenstück (verwaiste Schlüssel)
- Warnung: deutsche Texte, die im Code fest stehen statt über Texte.t / Texte.d laufen

Aufruf:  python3 tools/texte_pruefen.py
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TEXTE = os.path.join(ROOT, "scripts", "texte.gd")
SKRIPTE = os.path.join(ROOT, "scripts")
UI_SCHLUESSEL = re.compile(r"^[a-z][a-z0-9_]*\.[a-z0-9_.]+$")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
ENTRY = re.compile(r'^\t\t("(?:[^"\\]|\\.)*"):\s*("(?:[^"\\]|\\.)*"),?\s*$', re.M)
# Ortsnamen, die die Simulation und die Planung als Schlüssel nutzen (keine Anzeigetexte)
ORTSSCHLUESSEL = {"Außen vor dem Eingang", "Eingangstür", "Gemälde „Hafen bei Nacht“"}
GERMAN_HINT = re.compile(r"[äöüÄÖÜß]|\b(und|der|die|das|ist|nicht|mit|für|von|oder|ein|eine|wird|sind|bei)\b")


def lade_tabelle():
    text = open(TEXTE, encoding="utf-8").read()
    de_teil = text[text.index('\t"de": {'): text.index('\t"en": {')]
    en_teil = text[text.index('\t"en": {'): text.rindex("\t},\n}")]
    de = {json.loads(k, strict=False): json.loads(v, strict=False) for k, v in ENTRY.findall(de_teil)}
    en = {json.loads(k, strict=False): json.loads(v, strict=False) for k, v in ENTRY.findall(en_teil)}
    return de, en


def zeilen_mit_text(pfad):
    for nr, zeile in enumerate(open(pfad, encoding="utf-8"), start=1):
        yield nr, zeile.rstrip("\n")


def fest_stehende_texte():
    """Deutsche Texte in Literalen der Skripte, die nicht über die Texttabelle laufen."""
    treffer = []
    for wurzel, _, dateien in os.walk(SKRIPTE):
        for name in dateien:
            if not name.endswith(".gd") or name in ("texte.gd", "data.gd"):
                continue
            pfad = os.path.join(wurzel, name)
            for nr, zeile in zeilen_mit_text(pfad):
                code = zeile.split("#")[0] if '"#' not in zeile else zeile
                if "Texte." in code:
                    continue
                for m in STRING.finditer(code):
                    t = m.group(1)
                    if t in ORTSSCHLUESSEL or t.startswith("res://") or re.fullmatch(r"[A-Za-z0-9_.:%/\- ]*", t) and not GERMAN_HINT.search(t):
                        continue
                    if GERMAN_HINT.search(t) and re.search(r"[A-Za-zÄÖÜäöüß]{3,}", t):
                        treffer.append((os.path.relpath(pfad, ROOT), nr, t))
    return treffer


def main():
    de, en = lade_tabelle()
    fehlend = sorted(k for k in de if UI_SCHLUESSEL.match(k) and k not in en)
    verwaist = sorted(k for k in en if UI_SCHLUESSEL.match(k) and k not in de)
    warnungen = fest_stehende_texte()
    print("Texttabelle: %d deutsche, %d englische Einträge" % (len(de), len(en)))
    print("Fehler: %d Schlüssel ohne englische Fassung" % len(fehlend))
    for k in fehlend:
        print("  - %s  (de: %s)" % (k, de[k][:70]))
    print("Hinweis: %d englische Schlüssel ohne deutsches Gegenstück" % len(verwaist))
    for k in verwaist:
        print("  - %s" % k)
    print("Warnung: %d deutsche Texte stehen fest im Code (data.gd wird über tests/test_lokalisierung_daten.gd geprüft)" % len(warnungen))
    for datei, nr, t in warnungen:
        print("  - %s:%d  %s" % (datei, nr, t[:80]))
    return 1 if fehlend else 0


if __name__ == "__main__":
    sys.exit(main())

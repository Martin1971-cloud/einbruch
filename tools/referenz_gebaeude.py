#!/usr/bin/env python3
"""Erstellt eine Referenztabelle der Gebäude aus den Originaldaten von Der Clou!.

Quellen (im Datenordner): TCBUILD.DAT (Gebäude, Flächen, Polizei), TEXTS/LOCATION.LST (Ortsnamen,
Zeile n = LocationNr n), TOBAETA0 usw. (Objekte je Fläche). Ausgabe: Markdown auf der Konsole.

Aufruf: python3 referenz_gebaeude.py <Datenordner>   (Ordner mit DATA/ und TEXTS/)
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def dat(path):
    out = subprocess.run([sys.executable, os.path.join(HERE, "decode_dat.py"), path, "--json"],
                         capture_output=True, text=True).stdout
    return json.loads(out)


def main():
    root = sys.argv[1]
    data = os.path.join(root, "DATA")
    names = open(os.path.join(root, "TEXTS", "LOCATION.LST"), encoding="cp1252", errors="replace").read().splitlines()
    recs = dat(os.path.join(data, "TCBUILD.DAT"))
    buildings = [r["fields"] | {"nr": r["nr"]} for r in recs if r["type"] == "Building" and "fields" in r]
    print("| Ort (Nr.) | Name | Polizeizeit s | Wachrate | Wachstärke | Lautstärkegrenze | Wert (Original) | Fluchtweg | Wagen (x,y) |")
    print("|---|---|---|---|---|---|---|---|---|")
    for b in sorted(buildings, key=lambda b: b["LocationNr"]):
        n = b["LocationNr"]
        name = names[n - 1] if 0 < n <= len(names) else "?"
        print(f"| {n} | {name} | {b['PoliceTime']} | {b['GRate']} | {b['GuardStrength']} | {b['MaxVolume']} | {b['Values']} | {b['EscapeRouteLength']} | {b['CarXPos']},{b['CarYPos']} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())

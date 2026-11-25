#!/usr/bin/env python3
"""Liest die REL-Dateien (Beziehungen) von Der Clou!.

Aufbau (relation.c, LoadRelations): Kopfzeile "RELF", danach Blöcke:
  "RTAB" / Relationsnummer / (linker Schlüssel, rechter Schlüssel, Parameter) je Zeile-Tripel.
Schlüssel sind Objektnummern (dbEncode -> dbGetObject(atol)).
Aufruf: python3 decode_rel.py <Datei.REL>
"""
import sys


def decode(path):
    lines = [l.strip() for l in open(path, "rb").read().decode("cp1252", "replace").splitlines()]
    if not lines or lines[0] != "RELF":
        raise ValueError("Keine RELF-Datei")
    rels = []
    rel = None
    i = 1
    while i < len(lines):
        if lines[i] == "RTAB":
            rel = int(lines[i + 1])
            i += 2
            continue
        if rel is not None and i + 2 < len(lines):
            left, right, param = lines[i], lines[i + 1], lines[i + 2]
            if left == "" and right == "":
                i += 1
                continue
            try:
                rels.append((rel, int(left), int(right), int(param)))
            except ValueError:
                pass
            i += 3
            continue
        i += 1
    return rels


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    rs = decode(sys.argv[1])
    print("Beziehungen:", len(rs))
    for r in rs:
        print(r)

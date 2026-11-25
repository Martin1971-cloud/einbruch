#!/usr/bin/env python3
"""Erzeugt den Kiosk-Grundriss aus den Originaldaten (TOBAETA0.DAT, TCBUILD.DAT, TCMAIN.DAT).

Pixel des Originals = Einheiten des feinen Rasters bei SUB = 16 (ein Feld = 16 Pixel, wie PLANING_AREA_CAR).
Ausgabe: GDScript-Block für data.gd (zwischen den Markierungen KIOSK_BEGIN / KIOSK_END).

Aufruf: python3 make_kiosk_grundriss.py <Datenordner>
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SUB = 16
OX, OY = -32, -48          # Versatz Pixel -> Grundriss (Gebäude liegt im Ausschnitt)
COLS, ROWS = 20, 12        # Ausschnitt in Feldern


def dat(path):
    out = subprocess.run([sys.executable, os.path.join(HERE, "decode_dat.py"), path, "--json"],
                         capture_output=True, text=True).stdout
    return json.loads(out)


def fine(px):
    return (px[0] + OX, px[1] + OY)


def box(f):
    """Kollisionsrechteck eines Objekts in Pixeln (Ursprung + Versatz, Breite, Höhe)."""
    x0 = f["DestX"] + f["ExactX"]
    y0 = f["DestY"] + f["ExactY"]
    return x0, y0, x0 + f["ExactX1"], y0 + f["ExactY1"]


def main():
    data = os.path.join(sys.argv[1], "DATA")
    objs = [r["fields"] | {"nr": r["nr"]} for r in dat(os.path.join(data, "TOBAETA0.DAT")) if "fields" in r]
    walls, doors, counters, safe, till = [], [], [], None, None
    for o in objs:
        b = box(o)
        t = o["Type"]
        if t == 9208:
            walls.append(b)
        elif t == 9201:
            doors.append(b)
        elif t == 9223:
            counters.append(b)
        elif t == 9204:
            safe = b
        elif t == 9262:
            till = b
    # Gebäudefläche: Außenkante der Mauern
    allb = walls + doors + counters + [safe, till]
    minx = min(b[0] for b in allb)
    maxx = max(b[2] for b in allb)
    miny = min(b[1] for b in allb)
    maxy = max(b[3] for b in allb)

    paint = []
    # Innenraum (Boden), dann Mauern, Tür, Tresen, Wertschrank, Kasse
    paint.append([minx, miny, maxx, maxy, "."])
    for b in walls:
        paint.append([b[0], b[1], b[2], b[3], "W"])
    for b in doors:
        paint.append([b[0], b[1], b[2], b[3], "D"])
    for b in counters:
        paint.append([b[0], b[1], b[2], b[3], "C"])
    if safe:
        paint.append([safe[0], safe[1], safe[2], safe[3], "C"])
    if till:
        paint.append([till[0], till[1], till[2], till[3], "C"])

    fine_paint = []
    for r in paint:
        x0, y0 = fine((r[0], r[1]))
        x1, y1 = fine((r[2], r[3]))
        fine_paint.append([x0, y0, x1, y1, r[4]])

    def cell_of_px(px):
        f = fine(px)
        return (int(f[0] // SUB), int(f[1] // SUB))

    # Felder: Tür, Wertschrank, Kasse, Tresen, Fluchtwagen, Außenpunkte
    door = doors[0]
    dcx = (door[0] + door[2]) / 2
    dcy = (door[1] + door[3]) / 2
    door_cell = cell_of_px((dcx, dcy))
    till_cell = cell_of_px(((till[0] + till[2]) / 2, (till[1] + till[3]) / 2))
    safe_cell = cell_of_px(((safe[0] + safe[2]) / 2, (safe[1] + safe[3]) / 2))
    counter_cell = cell_of_px(((counters[0][0] + counters[0][2]) / 2, (counters[0][1] + counters[0][3]) / 2))
    out_front = cell_of_px((dcx, maxy + 8))     # vor der Tür, draußen
    inside_front = cell_of_px((dcx, miny + 30))  # vor der Tür, drinnen
    car = cell_of_px((35, 175))

    # Grobe Karte (Felder): Zeichen aus der Mitte jedes Feldes, letzte passende Farbe gewinnt (wie in der Simulation)
    def sample(fx, fy):
        ch = "o"
        for x0, y0, x1, y1, c in fine_paint:
            if x0 <= fx < x1 and y0 <= fy < y1:
                ch = c
        return ch
    grid = [[sample(x * SUB + SUB // 2, y * SUB + SUB // 2) for x in range(COLS)] for y in range(ROWS)]
    # Fenster, Vitrinen usw. blockieren; Boden bleibt Boden

    names = {
        "coarse": ["".join(row) for row in grid],
        "paint": fine_paint,
        "w": COLS * SUB, "h": ROWS * SUB,
        "door": door_cell, "out": out_front, "inside": inside_front,
        "safe": safe_cell, "till": till_cell, "counter": counter_cell, "car": car,
    }
    print(json.dumps(names, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

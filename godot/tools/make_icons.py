"""Erzeugt die Symbole für Menüs, Aktionsleiste und Stadtkarte (eigene Zeichnung, Goldlinien).
48 x 48 Pixel, mit Umriss gezeichnet und geglättet. Aufruf:  python3 tools/make_icons.py
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "icons")
S = 4
N = 48
GOLD = (236, 192, 98, 255)
GOLD_DARK = (150, 110, 50, 255)


def canvas():
    img = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def s(v):
    return v * S


def stroke(d, pts, w=3.0):
    d.line([(s(x), s(y)) for x, y in pts], fill=GOLD, width=int(w * S), joint="curve")


def circ(d, cx, cy, r, w=3.0):
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], outline=GOLD, width=int(w * S))


def fill_circ(d, cx, cy, r):
    d.ellipse([s(cx - r), s(cy - r), s(cx + r), s(cy + r)], fill=GOLD)


def box(d, x0, y0, x1, y1, w=3.0):
    d.rectangle([s(x0), s(y0), s(x1), s(y1)], outline=GOLD, width=int(w * S))


def draw_walk(d):
    for i, (x, y) in enumerate([(14, 32), (28, 18)]):
        fill_circ(d, x + 2, y - 4, 2.2)
    stroke(d, [(12, 40), (18, 36), (24, 40), (32, 34), (38, 38)], 3)


def draw_open(d):
    box(d, 14, 8, 34, 42)
    stroke(d, [(34, 8), (42, 12), (42, 42), (34, 42)], 3)
    fill_circ(d, 28, 26, 2)


def draw_unlock(d):
    box(d, 12, 22, 36, 42)
    stroke(d, [(18, 22), (18, 14), (30, 10), (30, 18)], 3)


def draw_crowbar(d):
    stroke(d, [(12, 36), (32, 14)], 5)
    stroke(d, [(32, 14), (38, 10)], 4)
    stroke(d, [(12, 36), (16, 40)], 4)


def draw_lockpick(d):
    circ(d, 17, 17, 6)
    stroke(d, [(22, 22), (38, 38)], 3.5)
    stroke(d, [(33, 33), (36, 30)], 3)
    stroke(d, [(38, 38), (42, 38)], 3)


def draw_take(d):
    box(d, 12, 20, 36, 40)
    stroke(d, [(18, 20), (18, 12), (30, 12), (30, 20)], 3)
    stroke(d, [(12, 28), (36, 28)], 2.5)


def draw_guard(d):
    stroke(d, [(24, 8), (38, 14), (38, 24), (24, 42), (10, 24), (10, 14), (24, 8)], 3)
    stroke(d, [(24, 16), (24, 30)], 2.5)


def draw_alarm(d):
    stroke(d, [(14, 34), (14, 24), (18, 16), (24, 12), (30, 16), (34, 24), (34, 34), (38, 36), (10, 36), (14, 34)], 3)
    circ(d, 24, 40, 3)
    stroke(d, [(38, 12), (44, 8)], 2.5)


def draw_car(d):
    stroke(d, [(8, 30), (12, 22), (20, 18), (30, 18), (38, 22), (42, 30), (42, 36), (8, 36), (8, 30)], 3)
    circ(d, 16, 36, 4)
    circ(d, 34, 36, 4)


def draw_wait(d):
    stroke(d, [(14, 10), (34, 10), (24, 24), (34, 38), (14, 38), (24, 24), (14, 10)], 3)


def draw_look(d):
    stroke(d, [(6, 24), (14, 14), (24, 10), (34, 14), (42, 24), (34, 34), (24, 38), (14, 34), (6, 24)], 3)
    fill_circ(d, 24, 24, 5)


def draw_talk(d):
    box(d, 8, 10, 32, 28, 2.8)
    stroke(d, [(16, 28), (16, 36), (24, 28)], 2.8)
    box(d, 18, 20, 40, 36, 2.8)


def draw_think(d):
    circ(d, 22, 22, 9, 2.8)
    circ(d, 34, 36, 3, 2.5)
    circ(d, 40, 42, 1.8, 2.5)


def draw_notes(d):
    box(d, 12, 8, 36, 42)
    for y in (18, 26, 34):
        stroke(d, [(18, y), (30, y)], 2.2)


def draw_city(d):
    stroke(d, [(6, 42), (6, 22), (14, 22), (14, 14), (24, 14), (24, 22), (32, 22), (32, 8), (42, 8), (42, 42), (6, 42)], 3)
    for x in (10, 18, 28, 36):
        fill_circ(d, x, 30, 1.5)


ICONS = {
    "walk": draw_walk, "open": draw_open, "unlock": draw_unlock, "crowbar": draw_crowbar,
    "lockpick": draw_lockpick, "take": draw_take, "guard": draw_guard, "alarm": draw_alarm,
    "car": draw_car, "wait": draw_wait, "look": draw_look, "talk": draw_talk,
    "think": draw_think, "notes": draw_notes, "city": draw_city,
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in ICONS.items():
        img, d = canvas()
        fn(d)
        img.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, f"{name}.png"))
    print(f"{len(ICONS)} Symbole nach {OUT}")


if __name__ == "__main__":
    main()

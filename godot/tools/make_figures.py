"""Erzeugt die Figuren für die 3D-Ansicht und die Planung (eigene Zeichnung, keine Vorlage übernommen).

Je Figur: Vorderseite, Rücken und Seite, je mit Stehen und einem Gehzyklus aus vier Bildern.
Gezeichnet mit der vierfachen Auflösung und danach geglättet, daher weiche Kanten und Schatten.
Aufruf:  python3 tools/make_figures.py
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
W, H = 64, 96   # Ergebnis in Pixeln
S = 4           # Zeichen-Faktor für glatte Kanten

OUTLINE = (22, 18, 26)
GOLD = (226, 182, 96)


def rgb(c, f=1.0, a=255):
    return (int(min(255, c[0] * f)), int(min(255, c[1] * f)), int(min(255, c[2] * f)), a)


class Pen:
    def __init__(self):
        self.img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, fill):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)

    def ell(self, cx, cy, rx, ry, fill):
        self.d.ellipse([(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill)

    def rrect(self, x0, y0, x1, y1, r, fill):
        self.d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill)

    def line(self, a, b, fill, w):
        self.d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=fill, width=max(1, int(w * S)), joint="curve")
        for q in (a, b):
            self.ell(q[0], q[1], w / 2.0, w / 2.0, fill)

    def save(self, path):
        self.img.resize((W, H), Image.LANCZOS).save(path)


def hat_shape(pen, hat, band):
    # Hut: Krempe, Kopf, Hutband
    pen.ell(32, 21.5, 19.5, 4.2, rgb(hat, 0.62))
    pen.rrect(22, 6.5, 42, 21, 6, hat)
    pen.rrect(22, 6.5, 26, 21, 4, rgb(hat, 1.12))
    pen.poly([(22, 16.5), (42, 16.5), (42, 19.2), (22, 19.2)], band)


def cap_shape(pen, cap, badge):
    # Dienstmütze mit Schirm und Abzeichen
    pen.rrect(23, 8, 41, 21, 7, cap)
    pen.ell(32, 21.5, 14, 3.2, rgb(cap, 0.6))
    pen.ell(32, 13.5, 2.2, 2.2, badge)


def headgear(pen, look, back=False):
    if look["cap"]:
        cap_shape(pen, look["hat"], GOLD)
    else:
        hat_shape(pen, look["hat"], look["band"])


def legs(pen, look, sw, side=False):
    pants, boot = look["pants"], (48, 34, 26)
    if not side:
        for hx, lx in ((27.5, sw), (36.5, -sw)):
            pen.line((hx, 74), (hx + lx * 0.9, 88.5), pants, 6.2)
            pen.ell(hx + lx * 0.9 + 0.8, 90.2, 4.4, 2.1, boot)
    else:
        # hinteres Bein dunkler, vorderes Bein vorne (Blickrichtung rechts)
        pen.line((31, 74), (31 - sw, 88.5), rgb(pants, 0.72), 6.0)
        pen.ell(31 - sw + 1.2, 90.2, 4.6, 2.1, rgb(boot, 0.8))
        pen.line((36, 74), (36 + sw, 88.5), pants, 6.0)
        pen.ell(36 + sw + 1.6, 90.2, 4.8, 2.1, boot)


def arms(pen, look, sw, side=False):
    coat, skin = look["coat"], look["skin"]
    if not side:
        for sx, dx in ((18.5, -sw * 0.35), (45.5, sw * 0.35)):
            hand = (sx + dx * 0.4, 70.5)
            pen.line((sx, 50.5), (sx + dx, 66.5), rgb(coat, 0.85), 5.8)
            pen.line((sx + dx, 66.5), hand, rgb(coat, 0.85), 5.2)
            pen.ell(hand[0], hand[1] + 1.2, 2.5, 2.6, skin)
    else:
        hand = (33 - sw * 0.9, 68.5)
        pen.line((33, 50.5), (33 - sw * 0.6, 66), rgb(coat, 0.78), 5.6)
        pen.line((33 - sw * 0.6, 66), hand, rgb(coat, 0.78), 5.0)
        pen.ell(hand[0], hand[1] + 1.2, 2.5, 2.6, skin)


def face_front(pen, look):
    skin, hair = look["skin"], look["hair"]
    pen.ell(22.5, 31, 2.2, 2.8, rgb(skin, 0.9))
    pen.ell(41.5, 31, 2.2, 2.8, rgb(skin, 0.9))
    pen.ell(32, 30.5, 9.6, 10.8, skin)
    pen.ell(28.5, 27.5, 4.2, 5.5, rgb(skin, 1.08))
    pen.ell(37.5, 37, 6.5, 6.5, rgb(skin, 0.94))
    pen.ell(28.6, 30.2, 1.35, 1.7, (34, 26, 24))
    pen.ell(35.4, 30.2, 1.35, 1.7, (34, 26, 24))
    pen.line((26, 25.8), (30.6, 25.2), rgb(hair, 0.9), 1.1)
    pen.line((33.4, 25.2), (38, 25.8), rgb(hair, 0.9), 1.1)
    pen.poly([(32, 30.5), (33.6, 34.6), (31, 35)], rgb(skin, 0.82))
    pen.line((29.6, 37.6), (34.4, 37.6), rgb(skin, 0.6), 0.9)


def face_side(pen, look):
    skin = look["skin"]
    pen.ell(33, 31, 7.6, 10.4, skin)
    pen.ell(30.5, 31, 2.4, 2.9, rgb(skin, 0.88))
    pen.poly([(40, 28.5), (44.5, 32.5), (40, 34)], rgb(skin, 0.92))
    pen.ell(38.3, 27.6, 1.25, 1.6, (34, 26, 24))
    pen.line((36.4, 37.4), (40, 37.2), rgb(skin, 0.6), 0.9)


def torso_front(pen, look):
    coat, scarf = look["coat"], look["scarf"]
    pen.poly([(17, 50), (20, 46), (44, 46), (47, 50), (45.5, 76), (18.5, 76)], coat)
    pen.poly([(36, 47), (44.5, 47), (45.5, 76), (36, 76)], rgb(coat, 0.72))
    pen.poly([(19.5, 50), (22.5, 48), (22.5, 74), (19.5, 75)], rgb(coat, 1.2))
    pen.poly([(29, 47.5), (32, 58.5), (28.8, 59)], rgb(coat, 1.3))
    pen.poly([(35, 47.5), (32, 58.5), (35.2, 59)], rgb(coat, 0.9))
    pen.ell(32, 63, 0.95, 0.95, GOLD)
    pen.ell(32, 68.5, 0.95, 0.95, GOLD)


def torso_back(pen, look):
    coat = look["coat"]
    pen.poly([(17, 50), (20, 46), (44, 46), (47, 50), (45.5, 76), (18.5, 76)], rgb(coat, 0.9))
    pen.poly([(20, 46), (44, 46), (44, 52), (20, 52)], rgb(coat, 0.7))
    pen.line((32, 52), (32, 75), rgb(coat, 0.7), 0.9)
    pen.rrect(39.5, 52, 50, 66, 2.5, look["bag"])
    pen.line((22, 47), (42, 74), look["bag"], 1.6)


def torso_side(pen, look):
    coat = look["coat"]
    pen.poly([(24, 49), (38, 46), (42, 50), (40.5, 76), (25.5, 76)], coat)
    pen.poly([(24, 49), (29, 48), (29, 76), (25.5, 76)], rgb(coat, 0.7))
    pen.poly([(33, 48), (40, 48), (40.5, 76), (35, 76)], rgb(coat, 1.12))
    pen.rrect(18.5, 51, 25.5, 66, 2.2, look["bag"])
    pen.line((22, 47.5), (34, 70), look["bag"], 1.5)


def belt(pen, look, side=False):
    x0, x1 = (24.5, 40.5) if side else (19, 45)
    pen.poly([(x0, 70), (x1, 70), (x1, 72.5), (x0, 72.5)], look["belt"])
    if not side:
        pen.poly([(30.6, 69.4), (33.4, 69.4), (33.4, 73.2), (30.6, 73.2)], GOLD)


def neck(pen, look, side=False):
    skin = rgb(look["skin"], 0.84)
    if side:
        pen.poly([(31, 39), (37.5, 39), (37.5, 46), (31, 46)], skin)
    else:
        pen.poly([(28.5, 39), (35.5, 39), (36.5, 46), (27.5, 46)], skin)


def scarf(pen, look, side=False):
    sc = look["scarf"]
    if side:
        pen.poly([(27.5, 43), (39.5, 43), (40.5, 50.5), (26.5, 50.5)], sc)
        pen.poly([(35, 49), (40, 49), (39, 58), (35.5, 57)], rgb(sc, 0.8))
    else:
        pen.poly([(25, 43), (39, 43), (40, 50), (24, 50)], sc)
        pen.poly([(35.5, 49), (40, 49), (39.5, 59), (36, 58)], rgb(sc, 0.8))


def figure(look, view, pose):
    pen = Pen()
    sw = pose["sw"]          # Schrittweite der Beine (Pixel)
    bob = pose["bob"]        # Körper hebt sich beim Gehen leicht
    side = view == "side"
    back = view == "back"
    # Schatten am Boden
    pen.ell(32, 91.2, 13, 2.4, (0, 0, 0, 70))
    if side:
        legs(pen, look, sw, side=True)
        arms(pen, look, sw, side=True)
        torso_side(pen, look)
        belt(pen, look, side=True)
        neck(pen, look, side=True)
        pen.ell(33, 27, 0.0, 0.0, (0, 0, 0, 0))
        # Kopf von der Seite: Haare hinten, Gesicht vorne
        pen.ell(30.2, 27.5, 8.6, 10.2, look["hair"])
        face_side(pen, look)
        pen.ell(31.0, 19.8, 6.5, 3.6, look["hair"])
        scarf(pen, look, side=True)
        headgear_offset(pen, look, shift=1.2)
    elif back:
        legs(pen, look, sw)
        arms(pen, look, sw)
        torso_back(pen, look)
        belt(pen, look)
        neck(pen, look)
        pen.ell(32, 30.5, 9.6, 10.8, look["hair"])
        pen.ell(32, 35, 6, 6, rgb(look["hair"], 0.85))
        scarf(pen, look)
        headgear(pen, look, back=True)
    else:
        legs(pen, look, sw)
        arms(pen, look, sw)
        torso_front(pen, look)
        belt(pen, look)
        neck(pen, look)
        scarf(pen, look)
        face_front(pen, look)
        headgear(pen, look)
    img = pen.img
    # Körper hebt sich leicht: Bild um bob Pixel nach oben verschieben
    out = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    out.paste(img, (0, -int(round(bob * S))), img)
    return out.resize((W, H), Image.LANCZOS)


def headgear_offset(pen, look, shift):
    # Seitenansicht: Krempe nach vorn gezogen, Kopf darunter, Band an der Stirn
    dx = shift
    if look["cap"]:
        pen.rrect(24 + dx, 8, 41 + dx, 20.5, 7, look["hat"])
        pen.poly([(33 + dx, 19.6), (46 + dx, 21.5), (33 + dx, 22.6)], rgb(look["hat"], 0.7))
        pen.ell(31 + dx, 13.5, 2.0, 2.0, GOLD)
    else:
        pen.ell(33 + dx, 21.2, 18.5, 3.9, rgb(look["hat"], 0.6))
        pen.ell(42.5 + dx, 22.2, 4.4, 2.2, rgb(look["hat"], 0.66))
        pen.rrect(24 + dx, 7, 41 + dx, 20.6, 6, look["hat"])
        pen.rrect(24 + dx, 7, 27 + dx, 20.6, 3.5, rgb(look["hat"], 1.14))
        pen.poly([(24 + dx, 16.4), (41 + dx, 16.4), (41 + dx, 19.0), (24 + dx, 19.0)], look["band"])


# Pose je Bild: Schrittweite und Körperbewegung. Vier Bilder ergeben einen Schritt.
POSES = {
    "idle": {"sw": 0.0, "bob": 0.0},
    "walk1": {"sw": 5.0, "bob": 0.7},
    "walk2": {"sw": 1.5, "bob": 0.0},
    "walk3": {"sw": -5.0, "bob": 0.7},
    "walk4": {"sw": -1.5, "bob": 0.0},
}

LOOKS = {
    "crew_mira": {"coat": (74, 118, 168), "hat": (58, 50, 46), "band": (200, 150, 80), "pants": (56, 60, 74),
                  "skin": (232, 192, 158), "hair": (92, 60, 46), "scarf": (206, 84, 74), "belt": (44, 30, 22),
                  "bag": (120, 84, 46), "cap": False},
    "crew_ilja": {"coat": (96, 146, 104), "hat": (36, 38, 42), "band": (220, 180, 90), "pants": (52, 54, 62),
                  "skin": (226, 184, 150), "hair": (46, 34, 30), "scarf": (236, 188, 84), "belt": (40, 30, 24),
                  "bag": (92, 70, 52), "cap": False},
    "crew_teo": {"coat": (150, 98, 58), "hat": (92, 62, 40), "band": (60, 40, 26), "pants": (70, 60, 52),
                 "skin": (198, 142, 106), "hair": (34, 26, 22), "scarf": (92, 150, 120), "belt": (40, 28, 20),
                 "bag": (110, 80, 44), "cap": False},
    "crew_rosa": {"coat": (150, 70, 110), "hat": (46, 46, 56), "band": (230, 190, 90), "pants": (40, 40, 52),
                  "skin": (240, 202, 172), "hair": (150, 90, 60), "scarf": (236, 200, 96), "belt": (30, 26, 34),
                  "bag": (80, 60, 70), "cap": False},
    "crew_otto": {"coat": (120, 96, 60), "hat": (54, 44, 34), "band": (60, 40, 26), "pants": (62, 56, 50),
                  "skin": (214, 166, 128), "hair": (120, 110, 100), "scarf": (168, 60, 56), "belt": (34, 24, 18),
                  "bag": (90, 70, 48), "cap": True},
    "crew_greta": {"coat": (60, 110, 96), "hat": (30, 40, 40), "band": (220, 180, 90), "pants": (44, 50, 56),
                   "skin": (236, 196, 166), "hair": (180, 70, 50), "scarf": (230, 230, 230), "belt": (30, 30, 30),
                   "bag": (70, 80, 84), "cap": True},
    "guard_indoor": {"coat": (40, 46, 66), "hat": (30, 34, 52), "band": (30, 34, 52), "pants": (30, 32, 44),
                     "skin": (222, 178, 140), "hair": (40, 32, 30), "scarf": (30, 34, 52), "belt": (20, 20, 28),
                     "bag": (30, 34, 50), "cap": True},
    "guard_street": {"coat": (46, 96, 200), "hat": (30, 60, 150), "band": (30, 60, 150), "pants": (34, 40, 70),
                     "skin": (222, 178, 140), "hair": (40, 32, 30), "scarf": (30, 60, 150), "belt": (20, 20, 28),
                     "bag": (30, 40, 70), "cap": True},
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    count = 0
    for name, look in LOOKS.items():
        for pose_name, pose in POSES.items():
            figure(look, "front", pose).save(os.path.join(OUT, f"{name}_{pose_name}.png"))
            figure(look, "side", pose).save(os.path.join(OUT, f"{name}_side_{pose_name}.png"))
            figure(look, "back", pose).save(os.path.join(OUT, f"{name}_back_{pose_name}.png"))
            count += 3
    print(f"{count} Figurenbilder nach {OUT}")


if __name__ == "__main__":
    main()

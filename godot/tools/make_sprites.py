"""Erzeugt die Pixelfiguren für die 3D-Ansicht (eigene Zeichnung, keine Vorlage übernommen).

Je Figur drei Stellungen: stehend, Schritt links, Schritt rechts.
Aufruf:  python3 tools/make_sprites.py
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
W, H = 16, 24
SKIN = (222, 178, 140, 255)
SKIN_DARK = (180, 130, 96, 255)
BOOT = (58, 36, 22, 255)
BELT = (50, 34, 24, 255)
BAG = (120, 84, 46, 255)
EYE = (30, 24, 20, 255)
OUTLINE = (24, 20, 26, 255)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


def figure(coat, hat, pants, pose):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Hut mit Krempe
    d.rectangle([4, 0, 11, 3], fill=hat)
    d.rectangle([2, 3, 13, 4], fill=shade(hat, 0.6))
    d.point([(4, 3), (11, 3)], fill=OUTLINE)
    # Gesicht und Hals
    d.rectangle([5, 5, 10, 8], fill=SKIN)
    d.rectangle([10, 6, 10, 8], fill=SKIN_DARK)
    d.point((9, 6), fill=EYE)
    d.rectangle([6, 9, 9, 9], fill=SKIN_DARK)
    # Mantel mit Schatten
    d.rectangle([3, 10, 12, 17], fill=coat)
    d.rectangle([11, 10, 12, 17], fill=shade(coat, 0.7))
    d.rectangle([3, 10, 4, 17], fill=shade(coat, 1.1))
    # Arme und Hände
    d.rectangle([2, 11, 3, 16], fill=coat)
    d.point([(2, 17), (13, 17)], fill=SKIN)
    # Gürtel und Tasche
    d.rectangle([3, 18, 12, 18], fill=BELT)
    d.rectangle([13, 14, 15, 17], fill=BAG)
    d.point((14, 13), fill=BELT)
    # Beine je nach Schritt
    if pose == "idle":
        left, right = (5, 6), (9, 10)
        lf, rf = (5, 6), (9, 10)
    elif pose == "walk1":
        left, right = (4, 5), (10, 11)
        lf, rf = (3, 5), (10, 12)
    else:
        left, right = (6, 7), (8, 9)
        lf, rf = (6, 8), (7, 9)
    d.rectangle([left[0], 19, left[1], 21], fill=pants)
    d.rectangle([right[0], 19, right[1], 21], fill=shade(pants, 0.8))
    d.rectangle([lf[0], 22, lf[1], 23], fill=BOOT)
    d.rectangle([rf[0], 22, rf[1], 23], fill=BOOT)
    return img


def legs(d, pants, pose):
    """Beine für Seiten- und Rückansicht: vorderes und hinteres Bein im Schritt."""
    if pose == "idle":
        front, back = (8, 9), (5, 6)
    elif pose == "walk1":
        front, back = (9, 11), (3, 5)
    else:
        front, back = (7, 8), (7, 9)
    d.rectangle([back[0], 19, back[1], 21], fill=shade(pants, 0.78))
    d.rectangle([front[0], 19, front[1], 21], fill=pants)
    d.rectangle([back[0], 22, back[1] + 1, 23], fill=BOOT)
    d.rectangle([front[0], 22, front[1] + 2, 23], fill=BOOT)
    d.point((front[1] + 2, 22), fill=shade(BOOT, 0.7))


def side_figure(coat, hat, pants, pose):
    """Profilansicht nach rechts: Hut mit Krempe, Gesicht, Kragen, Gürtelschnalle, Tasche und Schulterriemen."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Hut: Kuppel und vorstehende Krempe
    d.rectangle([5, 0, 11, 3], fill=hat)
    d.point((5, 0), fill=OUTLINE)
    d.rectangle([4, 3, 12, 4], fill=shade(hat, 0.6))
    d.point((12, 4), fill=OUTLINE)
    # Haare im Nacken
    d.rectangle([4, 5, 5, 7], fill=shade(hat, 0.8))
    # Gesicht im Profil mit Nase, Auge, Mund und Ohr
    d.rectangle([6, 5, 10, 8], fill=SKIN)
    d.point((11, 6), fill=SKIN)
    d.point((10, 7), fill=SKIN_DARK)
    d.point((9, 6), fill=EYE)
    d.point((10, 8), fill=SKIN_DARK)
    d.point((7, 7), fill=SKIN_DARK)
    # Hals und Kragen
    d.rectangle([7, 9, 8, 9], fill=SKIN_DARK)
    d.rectangle([5, 10, 11, 10], fill=shade(coat, 0.6))
    # Mantel mit Schattenkante, Knopf und Taschen
    d.rectangle([5, 11, 11, 17], fill=coat)
    d.rectangle([5, 11, 6, 17], fill=shade(coat, 0.7))
    d.rectangle([10, 11, 11, 17], fill=shade(coat, 1.1))
    d.point((9, 13), fill=(220, 180, 80, 255))
    d.rectangle([7, 15, 9, 15], fill=shade(coat, 0.8))
    # Arme: hinterer Arm wird vom Körper verdeckt, vorderer schwingt mit
    arm_x = {"idle": 11, "walk1": 12, "walk2": 10}[pose]
    d.rectangle([arm_x, 11, arm_x + 1, 15], fill=coat)
    d.rectangle([arm_x, 16, arm_x + 1, 16], fill=SKIN)
    # Gürtel mit Schnalle
    d.rectangle([5, 18, 11, 18], fill=BELT)
    d.point((8, 18), fill=(210, 170, 70, 255))
    # Tasche am Rücken und Schulterriemen
    d.rectangle([2, 13, 4, 17], fill=BAG)
    d.point((2, 13), fill=shade(BAG, 0.7))
    d.line([(4, 11), (6, 13)], fill=shade(BAG, 0.7), width=1)
    legs(d, pants, pose)
    return img


def back_figure(coat, hat, pants, pose):
    """Rückansicht: voller Hut, Nacken, Mantelrücken mit Schulterriemen und Tasche."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 0, 11, 3], fill=hat)
    d.point((4, 0), fill=OUTLINE)
    d.rectangle([3, 3, 12, 4], fill=shade(hat, 0.6))
    # Nacken und Haare, kein Gesicht
    d.rectangle([5, 5, 10, 8], fill=shade(hat, 0.85))
    d.rectangle([6, 9, 9, 9], fill=SKIN_DARK)
    # Mantelrücken mit Mittelnaht und Kragen
    d.rectangle([3, 10, 12, 17], fill=coat)
    d.rectangle([3, 10, 4, 17], fill=shade(coat, 0.75))
    d.rectangle([11, 10, 12, 17], fill=shade(coat, 0.75))
    d.line([(7, 11), (7, 17)], fill=shade(coat, 0.8), width=1)
    d.rectangle([5, 10, 10, 10], fill=shade(coat, 0.6))
    # Arme seitlich mit Händen
    d.rectangle([2, 11, 2, 16], fill=coat)
    d.rectangle([13, 11, 13, 16], fill=coat)
    d.point([(2, 17), (13, 17)], fill=SKIN)
    # Schulterriemen der Tasche und Gürtel
    d.line([(4, 11), (9, 17)], fill=BAG, width=1)
    d.rectangle([3, 18, 12, 18], fill=BELT)
    d.rectangle([13, 14, 15, 17], fill=BAG)
    legs(d, pants, pose)
    return img


FIGURES = {
    "crew_mira": ((86, 130, 170), (60, 52, 46), (60, 62, 74)),
    "crew_ilja": ((120, 160, 110), (40, 40, 40), (56, 56, 64)),
    "crew_teo": ((176, 120, 70), (96, 66, 40), (70, 60, 52)),
    "crew_rosa": ((170, 80, 120), (50, 50, 60), (40, 40, 52)),
    "guard_indoor": ((36, 40, 58), (30, 32, 48), (30, 32, 44)),
    "guard_street": ((46, 96, 200), (30, 60, 150), (34, 40, 70)),
}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, (coat, hat, pants) in FIGURES.items():
        for pose in ["idle", "walk1", "walk2"]:
            figure(coat, hat, pants, pose).save(os.path.join(OUT, f"{name}_{pose}.png"))
            side_figure(coat, hat, pants, pose).save(os.path.join(OUT, f"{name}_side_{pose}.png"))
            back_figure(coat, hat, pants, pose).save(os.path.join(OUT, f"{name}_back_{pose}.png"))
    print(f"{len(FIGURES) * 9} Sprites nach {OUT}")


if __name__ == "__main__":
    main()

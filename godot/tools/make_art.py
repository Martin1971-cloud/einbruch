"""Berechnet das Ortsbild des Museums selbst (keine Vorlage übernommen).

Nachtansicht: Himmel mit Verlauf und Mond, Säulen mit Rundungsschatten,
leuchtende Fenster, Giebel, Bäume, Lichtreflexe am Boden.
Aufruf:  python3 tools/make_art.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art")
W, H = 1280, 720


def sky() -> Image.Image:
    y = np.linspace(0, 1, H)[:, None]
    top = np.array([14, 22, 44])
    bottom = np.array([60, 72, 98])
    col = top * (1 - y) + bottom * y
    arr = np.repeat(col[:, None, :], W, axis=1)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGB").convert("RGBA")


def glow(img: Image.Image, box, color, radius: int, strength: float) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse(box, fill=color + (int(255 * strength),))
    layer = layer.filter(ImageFilter.GaussianBlur(radius))
    img.alpha_composite(layer)


def column(img: Image.Image, x: int, top: int, bottom: int, width: int) -> None:
    """Säule mit rundem Schatten: hell in der Mitte, dunkel an den Rändern."""
    h = bottom - top
    u = np.linspace(-1, 1, width)
    shade = (0.45 + 0.55 * np.sqrt(np.clip(1 - u ** 2, 0, 1)))[None, :]
    base = np.array([226, 214, 190], dtype=float)
    arr = np.zeros((h, width, 4), dtype=np.uint8)
    arr[..., :3] = np.clip(base[None, None, :] * shade[..., None], 0, 255).astype(np.uint8)
    arr[..., 3] = 255
    tile = Image.fromarray(arr, "RGBA")
    img.alpha_composite(tile, (x, top))
    # Kapitell und Sockel
    d = ImageDraw.Draw(img)
    d.rectangle([x - 6, top - 10, x + width + 6, top], fill=(214, 200, 172, 255))
    d.rectangle([x - 8, bottom, x + width + 8, bottom + 12], fill=(196, 184, 160, 255))


def window(img: Image.Image, x: int, y: int, w: int, h: int) -> None:
    d = ImageDraw.Draw(img)
    d.rectangle([x - 4, y - 4, x + w + 4, y + h + 4], fill=(120, 108, 92, 255))
    d.rectangle([x, y, x + w, y + h], fill=(255, 200, 110, 255))
    d.line([(x + w // 2, y), (x + w // 2, y + h)], fill=(120, 90, 50, 255), width=2)
    d.line([(x, y + h // 2), (x + w, y + h // 2)], fill=(120, 90, 50, 255), width=2)
    glow(img, [x - 30, y - 30, x + w + 30, y + h + 30], (255, 190, 90), 18, 0.35)


def tree(img: Image.Image, cx: int, cy: int, r: int, seed: int) -> None:
    rng = np.random.default_rng(seed)
    for _ in range(40):
        ox, oy = rng.normal(0, r * 0.45, 2)
        rr = r * rng.uniform(0.5, 0.8)
        g = int(rng.uniform(34, 58))
        d = ImageDraw.Draw(img)
        d.ellipse([cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr], fill=(18, g, 28, 255))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    img = sky()
    # Mond mit Lichthof
    glow(img, [1020, 60, 1100, 140], (235, 235, 215), 26, 0.45)
    ImageDraw.Draw(img).ellipse([1040, 80, 1080, 120], fill=(245, 244, 230, 255))
    # Ferne Stadtsilhouette
    d = ImageDraw.Draw(img)
    for x in range(0, W, 46):
        hgt = 120 + (x * 37 % 70)
        d.rectangle([x, 380 - hgt // 3, x + 40, 420], fill=(26, 32, 50, 255))
    # Gebäude: Sockel, Fassade, Giebel
    base_y = 520
    d.rectangle([160, base_y - 190, 1120, base_y], fill=(206, 190, 160, 255))
    d.rectangle([140, base_y, 1140, base_y + 26], fill=(180, 166, 140, 255))
    d.polygon([(140, base_y - 190), (640, base_y - 300), (1140, base_y - 190)], fill=(214, 200, 170, 255))
    d.polygon([(190, base_y - 196), (640, base_y - 286), (1090, base_y - 196)], fill=(120, 104, 84, 255))
    # Wappen im Giebel
    d.ellipse([610, base_y - 260, 670, base_y - 200], fill=(170, 150, 110, 255))
    # Säulen
    for i in range(6):
        column(img, 230 + i * 150, base_y - 180, base_y - 10, 26)
    # Fenster zwischen den Säulen, Reihe oben und unten
    for i in range(5):
        x = 282 + i * 150
        window(img, x, base_y - 140, 22, 60)
        window(img, x, base_y - 60, 22, 40)
    # Eingangstor in der Mitte mit warmem Licht
    d.rectangle([600, base_y - 110, 680, base_y], fill=(70, 46, 26, 255))
    d.rectangle([604, base_y - 106, 676, base_y - 4], fill=(255, 196, 110, 255))
    glow(img, [560, base_y - 150, 720, base_y + 20], (255, 190, 100), 30, 0.4)
    # Treppe
    for i in range(4):
        d.rectangle([520 - i * 20, base_y + 26 + i * 8, 760 + i * 20, base_y + 34 + i * 8], fill=(190, 178, 152, 255))
    # Bäume links und rechts
    tree(img, 90, 430, 110, 1)
    tree(img, 1190, 440, 120, 2)
    # Lichtpfützen am Boden
    glow(img, [420, base_y + 60, 880, base_y + 140], (255, 190, 100), 22, 0.22)
    # Dunkler Vordergrund
    d.rectangle([0, 620, W, H], fill=(14, 20, 24, 255))
    img = img.convert("RGB")
    path = os.path.join(OUT, "location_museum.png")
    img.save(path)
    print("gespeichert:", path, img.size)


if __name__ == "__main__":
    main()

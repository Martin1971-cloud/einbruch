"""Erzeugt die Stimmungsbilder: nächtlicher Hintergrund für alle Oberflächen und das Bild des Kiosks (eigene Zeichnung).
Aufruf:  python3 tools/make_backgrounds.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")


def sky(w, h, top, mid, low):
    img = Image.new("RGB", (w, h), top)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        if t < 0.6:
            k = t / 0.6
            c = tuple(int(top[i] + (mid[i] - top[i]) * k) for i in range(3))
        else:
            k = (t - 0.6) / 0.4
            c = tuple(int(mid[i] + (low[i] - mid[i]) * k) for i in range(3))
        d.line([(0, y), (w, y)], fill=c)
    return img


def moon(img, x, y, r):
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for i in range(10, 0, -1):
        rr = r * (1 + i * 0.35)
        hd.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(230, 220, 170, int(6 + (10 - i) * 1.4)))
    img.alpha_composite(halo)
    d = ImageDraw.Draw(img)
    d.ellipse([x - r, y - r, x + r, y + r], fill=(246, 238, 204, 255))


def roofs(img, rnd, base_y, color, windows, seed_scale=1.0):
    w, h = img.size
    d = ImageDraw.Draw(img)
    x = -20
    while x < w + 20:
        bw = rnd.randint(int(60 * seed_scale), int(130 * seed_scale))
        bh = rnd.randint(int(60 * seed_scale), int(180 * seed_scale))
        top = base_y - bh
        d.rectangle([x, top, x + bw, h], fill=color)
        # Dach-Spitze
        if rnd.random() < 0.35:
            d.polygon([(x + bw * 0.2, top), (x + bw * 0.5, top - bh * 0.2), (x + bw * 0.8, top)], fill=color)
        for _ in range(windows):
            wx = rnd.randint(x + 6, max(x + 7, x + bw - 14))
            wy = rnd.randint(top + 10, max(top + 11, h - 30))
            if rnd.random() < 0.5:
                d.rectangle([wx, wy, wx + 7, wy + 9], fill=(255, 196, 96, rnd.randint(150, 240)))
        x += bw + rnd.randint(4, 14)


def background(path, w=1600, h=1000):
    rnd = random.Random(21)
    img = sky(w, h, (10, 16, 34), (26, 52, 74), (120, 96, 60)).convert("RGBA")
    moon(img, int(w * 0.82), int(h * 0.16), 46)
    # Wolken als weiche Streifen
    clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    for _ in range(14):
        cx, cy = rnd.randint(0, w), rnd.randint(0, int(h * 0.45))
        cd.ellipse([cx - 220, cy - 26, cx + 220, cy + 26], fill=(60, 80, 110, 46))
    img.alpha_composite(clouds.filter(ImageFilter.GaussianBlur(18)))
    far = Image.new("RGB", (w, h), (0, 0, 0))
    roofs(far, rnd, int(h * 0.72), (20, 30, 50), 3, 0.9)
    img = Image.alpha_composite(img, Image.blend(far.convert("RGBA"), Image.new("RGBA", (w, h), (0, 0, 0, 0)), 0.0))
    near = Image.new("RGB", (w, h), (0, 0, 0))
    roofs(near, rnd, int(h * 0.9), (12, 18, 32), 4, 1.2)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rectangle([0, 0, w, h], fill=255)
    base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    img = Image.alpha_composite(img, far.convert("RGBA") if False else img)
    img = Image.alpha_composite(img, near.convert("RGBA"))
    # Dunkler Rand zum Rand hin, damit die Oberflächen darauf lesbar sind
    vign = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vign)
    for i in range(60):
        vd.rectangle([i, i, w - i, h - i], outline=int(120 * (1 - i / 60)))
    dark = Image.new("RGBA", (w, h), (4, 8, 16, 255))
    img = Image.composite(dark, img, vign.filter(ImageFilter.GaussianBlur(20)))
    img.convert("RGB").save(path, quality=90)


def kiosk(path, w=960, h=600):
    rnd = random.Random(5)
    img = sky(w, h, (14, 20, 40), (34, 60, 84), (70, 66, 60)).convert("RGBA")
    moon(img, int(w * 0.8), int(h * 0.2), 30)
    d = ImageDraw.Draw(img)
    # Hafenbecken mit Spiegelung
    water_top = int(h * 0.72)
    for y in range(water_top, h):
        t = (y - water_top) / (h - water_top)
        d.line([(0, y), (w, y)], fill=(int(18 + 10 * t), int(38 + 16 * t), int(60 + 14 * t), 255))
    for _ in range(120):
        x, y = rnd.randint(0, w), rnd.randint(water_top, h)
        d.line([(x, y), (x + rnd.randint(10, 30), y)], fill=(120, 150, 170, 60), width=1)
    # Kai und Kiosk
    d.rectangle([0, water_top - 20, w, water_top], fill=(44, 40, 44))
    kx, ky = int(w * 0.36), int(h * 0.36)
    kw, kh = int(w * 0.28), int(h * 0.36)
    d.rectangle([kx, ky, kx + kw, ky + kh], fill=(92, 60, 40))
    for x in range(kx, kx + kw, 14):
        d.line([(x, ky), (x, ky + kh)], fill=(74, 46, 30), width=1)
    # Markise rot-weiß
    for i in range(10):
        c = (176, 40, 40) if i % 2 == 0 else (236, 230, 220)
        x0 = kx - 18 + i * (kw + 36) // 10
        d.polygon([(x0, ky - 4), (x0 + (kw + 36) // 10, ky - 4), (x0 + (kw + 36) // 10 + 2, ky + 22), (x0 + 2, ky + 22)], fill=c)
    # Schaufenster mit warmem Licht
    d.rectangle([kx + 22, ky + 50, kx + kw - 22, ky + kh - 60], fill=(255, 190, 96))
    for i in range(4):
        d.rectangle([kx + 40 + i * 52, ky + 110, kx + 70 + i * 52, ky + 132], fill=(180, 60, 40))
    # Tür und Lampe
    d.rectangle([kx + kw - 60, ky + 130, kx + kw - 30, ky + kh], fill=(40, 26, 20))
    d.ellipse([kx - 40, ky + 60, kx - 26, ky + 74], fill=(255, 220, 140))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.convert("RGB").save(path, quality=90)


def main() -> None:
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    background(os.path.join(ROOT, "art", "bg_default.jpg"))
    kiosk(os.path.join(ROOT, "art", "location_kiosk.jpg"))
    print("Hintergrund und Kiosk-Bild erzeugt")




def planning(path, w=1600, h=900):
    """Planung: nächtlicher Hafen mit Stadtlichtern und einem Blaupausen-Raster, dunkel, damit die Pläne lesbar bleiben."""
    rnd = random.Random(31)
    img = sky(w, h, (8, 12, 26), (22, 40, 62), (60, 54, 52)).convert("RGBA")
    moon(img, int(w * 0.86), int(h * 0.14), 36)
    # Raster wie auf einer Bauzeichnung, sehr zart
    grid = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for x in range(0, w, 48):
        gd.line([(x, 0), (x, h)], fill=(90, 140, 190, 22), width=1)
    for y in range(0, h, 48):
        gd.line([(0, y), (w, y)], fill=(90, 140, 190, 22), width=1)
    img.alpha_composite(grid)
    roofs(img.convert("RGB"), rnd, int(h * 0.82), (14, 22, 38), 3, 1.1)
    img = Image.open("/dev/null") if False else img
    d = ImageDraw.Draw(img)
    # Hafenkräne und Lichter am Wasser
    wy = int(h * 0.84)
    d.rectangle([0, wy, w, h], fill=(12, 26, 40, 255))
    for _ in range(90):
        x, y = rnd.randint(0, w), rnd.randint(wy, h)
        d.line([(x, y), (x + rnd.randint(14, 40), y)], fill=(170, 160, 120, 50), width=1)
    for _ in range(60):
        x, y = rnd.randint(0, w), rnd.randint(int(h * 0.7), wy)
        d.ellipse([x, y, x + 3, y + 3], fill=(255, 200, 110, rnd.randint(120, 220)))
    vign = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vign)
    for i in range(80):
        vd.rectangle([i, i, w - i, h - i], outline=int(150 * (1 - i / 80)))
    dark = Image.new("RGBA", (w, h), (4, 6, 12, 255))
    img = Image.composite(dark, img, vign.filter(ImageFilter.GaussianBlur(24)))
    img.convert("RGB").save(path, quality=90)


def execution(path, w=1600, h=900):
    """Ausführung: nächtliche Straße vor dem Gebäude mit Scheinwerfern und rotem Blaulicht am Rand."""
    rnd = random.Random(47)
    img = sky(w, h, (6, 8, 20), (30, 26, 50), (40, 30, 30)).convert("RGBA")
    moon(img, int(w * 0.15), int(h * 0.18), 30)
    roofs(img.convert("RGB"), rnd, int(h * 0.62), (16, 14, 30), 4, 1.3)
    img = img  # Schicht
    d = ImageDraw.Draw(img)
    # Straße mit Perspektive
    d.polygon([(0, int(h * 0.62)), (w, int(h * 0.62)), (w, h), (0, h)], fill=(22, 20, 26, 255))
    for i in range(12):
        t = i / 12
        y = int(h * (0.66 + 0.3 * t * t))
        d.line([(0, y), (w, y)], fill=(40, 36, 46, 255), width=1)
    # Laternen
    for x in range(120, w, 340):
        d.line([(x, int(h * 0.62)), (x, int(h * 0.38))], fill=(30, 30, 36, 255), width=5)
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse([x - 60, int(h * 0.36) - 40, x + 60, int(h * 0.36) + 40], fill=(255, 200, 120, 60))
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))
        d.ellipse([x - 9, int(h * 0.36) - 9, x + 9, int(h * 0.36) + 9], fill=(255, 226, 160, 255))
    # Blaulicht am Rand, sehr dezent
    flash = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(flash)
    fd.ellipse([-120, h - 260, 220, h + 80], fill=(200, 30, 40, 60))
    fd.ellipse([w - 260, h - 260, w + 120, h + 80], fill=(40, 90, 220, 60))
    img.alpha_composite(flash.filter(ImageFilter.GaussianBlur(40)))
    vign = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vign)
    for i in range(80):
        vd.rectangle([i, i, w - i, h - i], outline=int(150 * (1 - i / 80)))
    dark = Image.new("RGBA", (w, h), (4, 4, 10, 255))
    img = Image.composite(dark, img, vign.filter(ImageFilter.GaussianBlur(24)))
    img.convert("RGB").save(path, quality=90)


if __name__ == "__main__":
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    planning(os.path.join(ROOT, "art", "bg_planung.jpg"))
    execution(os.path.join(ROOT, "art", "bg_ausfuehrung.jpg"))
    print("Planung und Ausführung erzeugt")

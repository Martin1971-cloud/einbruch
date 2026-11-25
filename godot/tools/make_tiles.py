"""Erzeugt die Kacheln für den Grundriss: Parkett, Rasen, Mauer, Fenster (eigene Zeichnung).
Jede Kachel 128 x 128 Pixel, nahtlos, mit leichter Zufallsstruktur (fester Seed, dadurch immer gleich).
Aufruf:  python3 tools/make_tiles.py
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "tiles")
N = 128


def noisy(base, spread, rnd, img):
    px = img.load()
    for y in range(N):
        for x in range(N):
            k = 1.0 + rnd.uniform(-spread, spread)
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return img


def parquet():
    rnd = random.Random(7)
    img = Image.new("RGBA", (N, N), (150, 110, 70, 255))
    d = ImageDraw.Draw(img)
    plank_h = 32
    for row in range(N // plank_h + 1):
        y0 = row * plank_h
        shift = (row % 2) * 40
        for x0 in range(-shift, N + 40, 40):
            tone = rnd.uniform(0.86, 1.1)
            col = (int(170 * tone), int(124 * tone), int(78 * tone), 255)
            d.rectangle([x0, y0, x0 + 39, y0 + plank_h - 1], fill=col)
            for _ in range(6):
                gy = y0 + rnd.randint(3, plank_h - 4)
                d.line([(x0 + 2, gy), (x0 + 37, gy + rnd.randint(-1, 1))], fill=(int(col[0] * 0.82), int(col[1] * 0.82), int(col[2] * 0.82), 255), width=1)
            d.line([(x0, y0), (x0 + 39, y0)], fill=(96, 66, 38, 255), width=1)
            d.line([(x0, y0), (x0, y0 + plank_h - 1)], fill=(96, 66, 38, 255), width=1)
    return noisy(None, 0.04, rnd, img)


def grass():
    rnd = random.Random(11)
    img = Image.new("RGBA", (N, N), (42, 86, 62, 255))
    d = ImageDraw.Draw(img)
    for _ in range(900):
        x, y = rnd.randint(0, N - 1), rnd.randint(0, N - 1)
        t = rnd.uniform(0.7, 1.25)
        d.line([(x, y), (x + rnd.randint(-2, 2), y - rnd.randint(2, 5))], fill=(int(60 * t), int(120 * t), int(80 * t), 255), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    return noisy(None, 0.05, rnd, img)


def wall():
    rnd = random.Random(3)
    img = Image.new("RGBA", (N, N), (58, 62, 80, 255))
    d = ImageDraw.Draw(img)
    for row in range(N // 32):
        y0 = row * 32
        off = 0 if row % 2 == 0 else 32
        for x0 in range(-off, N + 32, 64):
            t = rnd.uniform(0.9, 1.1)
            d.rectangle([x0 + 2, y0 + 2, x0 + 61, y0 + 29], fill=(int(70 * t), int(74 * t), int(96 * t), 255))
            d.line([(x0 + 2, y0 + 2), (x0 + 61, y0 + 2)], fill=(110, 116, 140, 255), width=1)
    img = img.filter(ImageFilter.GaussianBlur(0.3))
    return noisy(None, 0.03, rnd, img)


def window():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(N):
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=(int(120 + 60 * t), int(170 + 40 * t), int(220 + 20 * t), 255))
    d.line([(N // 2, 0), (N // 2, N)], fill=(60, 70, 96, 255), width=5)
    d.polygon([(14, 20), (44, 10), (50, 40), (20, 52)], fill=(230, 245, 255, 90))
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("parkett", parquet), ("rasen", grass), ("mauer", wall), ("fenster", window)]:
        fn().save(os.path.join(OUT, f"{name}.png"))
    print("Kacheln nach", OUT)


if __name__ == "__main__":
    main()

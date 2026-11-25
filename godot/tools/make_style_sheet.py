"""Stil-Entwürfe zur Auswahl: drei Grundriss-Stile und drei 3D-Stile (eigene Zeichnung, nur Vorschau).
Aufruf:  python3 tools/make_style_sheet.py <Ausgabedatei.png>
"""
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 420, 270


def room(style):
    img = Image.new("RGB", (W, H), (14, 18, 30))
    d = ImageDraw.Draw(img)
    cols, rows = 10, 6
    cs = 34
    ox, oy = (W - cols * cs) // 2, (H - rows * cs) // 2
    rnd = random.Random(3)
    if style == "A":  # Farbflächen, warm, weiche Schatten
        for y in range(rows):
            for x in range(cols):
                c = (176, 130, 84) if (x + y) % 2 == 0 else (164, 120, 76)
                wall = x in (0, cols - 1) or y in (0, rows - 1)
                col = (70, 74, 92) if wall else c
                d.rectangle([ox + x * cs, oy + y * cs, ox + (x + 1) * cs - 1, oy + (y + 1) * cs - 1], fill=col)
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rectangle([ox + 4, oy + 4, ox + cols * cs + 4, oy + rows * cs + 4], fill=(0, 0, 0, 90))
        img.paste(sh, (0, 0), sh.filter(ImageFilter.GaussianBlur(4)))
        d = ImageDraw.Draw(img)
        for x, y in [(4, 2), (6, 4), (2, 3)]:
            d.ellipse([ox + x * cs + 8, oy + y * cs + 8, ox + x * cs + 26, oy + y * cs + 26], fill=(250, 214, 120))
    elif style == "B":  # Modern flach: reine Flächen, dünne Linien, kühle Palette
        for y in range(rows):
            for x in range(cols):
                wall = x in (0, cols - 1) or y in (0, rows - 1)
                col = (38, 46, 64) if wall else (206, 214, 226)
                d.rectangle([ox + x * cs, oy + y * cs, ox + (x + 1) * cs - 1, oy + (y + 1) * cs - 1], fill=col, outline=(120, 130, 150))
        for x, y in [(4, 2), (6, 4), (2, 3)]:
            d.rectangle([ox + x * cs + 10, oy + y * cs + 10, ox + x * cs + 24, oy + y * cs + 24], fill=(232, 176, 60), outline=(255, 230, 150))
    else:  # C: Pixel-Stil mit kräftigen Farben
        px = 4
        for y in range(rows):
            for x in range(cols):
                wall = x in (0, cols - 1) or y in (0, rows - 1)
                for sy in range(cs // px):
                    for sx in range(cs // px):
                        base = (60, 40, 30) if wall else ((150, 100, 60) if (x + y) % 2 == 0 else (136, 90, 54))
                        k = 1 + rnd.uniform(-0.06, 0.06)
                        col = tuple(min(255, int(v * k)) for v in base)
                        d.rectangle([ox + x * cs + sx * px, oy + y * cs + sy * px, ox + x * cs + sx * px + px - 1, oy + y * cs + sy * px + px - 1], fill=col)
        for x, y in [(4, 2), (6, 4), (2, 3)]:
            d.rectangle([ox + x * cs + 10, oy + y * cs + 10, ox + x * cs + 24, oy + y * cs + 24], fill=(255, 210, 60), outline=(120, 60, 0))
    return img


def iso_scene(style):
    img = Image.new("RGB", (W, H), (14, 18, 30))
    d = ImageDraw.Draw(img)
    def pt(x, y, z):
        return (W / 2 + (x - y) * 22, 110 + (x + y) * 11 - z * 22)
    faces = []
    blocks = [((0, 0, 0), (6, 4, 0.2), (150, 120, 90)), ((1, 1, 0.2), (1, 1, 1.6), (240, 210, 170)), ((4, 2, 0.2), (1, 2, 1.2), (80, 90, 120))]
    for (x0, y0, z0), (sx, sy, sz), col in blocks:
        cx = [x0, x0 + sx]
        cy = [y0, y0 + sy]
        top = [pt(cx[0], cy[0], z0 + sz), pt(cx[1], cy[0], z0 + sz), pt(cx[1], cy[1], z0 + sz), pt(cx[0], cy[1], z0 + sz)]
        left = [pt(cx[0], cy[1], z0), pt(cx[0], cy[1], z0 + sz), pt(cx[0], cy[0], z0 + sz), pt(cx[0], cy[0], z0)]
        right = [pt(cx[1], cy[0], z0), pt(cx[1], cy[0], z0 + sz), pt(cx[1], cy[1], z0 + sz), pt(cx[1], cy[1], z0)]
        faces.append((top, left, right, col))
    for top, left, right, col in faces:
        if style == "A":  # Cel-Shading mit dunklem Umriss
            d.polygon(left, fill=tuple(int(v * 0.7) for v in col), outline=(20, 16, 24))
            d.polygon(right, fill=tuple(int(v * 0.85) for v in col), outline=(20, 16, 24))
            d.polygon(top, fill=col, outline=(20, 16, 24))
        elif style == "B":  # realistischer Look: weiche Verläufe über Licht und Schatten
            for poly, k in ((left, 0.55), (right, 0.75), (top, 1.0)):
                d.polygon(poly, fill=tuple(min(255, int(v * k)) for v in col))
            d.line(top + [top[0]], fill=(255, 245, 220), width=1)
        else:  # Diorama: flache Farben, unscharfe Ränder (Tilt-Shift-Gefühl)
            for poly, k in ((left, 0.6), (right, 0.8), (top, 1.0)):
                d.polygon(poly, fill=tuple(min(255, int(v * k)) for v in col))
    if style == "C":
        img = img.filter(ImageFilter.GaussianBlur(1.2))
        band = Image.new("RGB", (W, H), (0, 0, 0))
        bd = ImageDraw.Draw(band)
        bd.rectangle([0, 0, W, 50], fill=(255, 255, 255))
        bd.rectangle([0, H - 50, W, H], fill=(255, 255, 255))
        mask = Image.new("L", (W, H), 255)
        ImageDraw.Draw(mask).rectangle([0, 0, W, 50], fill=0)
        ImageDraw.Draw(mask).rectangle([0, H - 50, W, H], fill=0)
        img = Image.composite(img, Image.blend(img, Image.new("RGB", (W, H), (0, 0, 0)), 0.7), mask.filter(ImageFilter.GaussianBlur(12)))
    return img


def main() -> None:
    out_path = sys.argv[1] if len(sys.argv) > 1 else "stil_vorschau.png"
    sheet = Image.new("RGB", (W * 3 + 40, (H + 46) * 2 + 20), (8, 10, 18))
    d = ImageDraw.Draw(sheet)
    names2d = ["A  Warm, Farbflächen", "B  Modern, flach", "C  Pixel-Retro"]
    names3d = ["A  Cel-Shading mit Umriss", "B  Realistisch, Licht und Schatten", "C  Diorama (unscharfe Ränder)"]
    for i, st in enumerate("ABC"):
        x = 10 + i * (W + 10)
        sheet.paste(room(st), (x, 36))
        d.text((x + 6, 12), "Grundriss " + names2d[i], fill=(240, 220, 170))
    for i, st in enumerate("ABC"):
        x = 10 + i * (W + 10)
        y = H + 46 + 36
        sheet.paste(iso_scene(st), (x, y))
        d.text((x + 6, y - 24), "3D " + names3d[i], fill=(240, 220, 170))
    sheet.save(out_path)
    print("Vorschau gespeichert:", out_path)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Style Buddy : portrait natif 1284x2778
- Fond violet plein écran
- Titre en haut
- Téléphone centré en dessous (extrait des promo_v2)
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1284, 2778
SRC = Path(__file__).parent / "promo"
OUT = SRC / "ios_1284x2778"

PURPLE_TOP = (88, 48, 158)
PURPLE_BOTTOM = (118, 78, 195)
WHITE = (255, 255, 255)
SUB = (225, 215, 255)

SLIDES = [
    {
        "src": "promo_v2_01_accueil.png",
        "out": "01_accueil_1284x2778.png",
        "title": "Suivez vos dépenses",
        "subtitle": "Comprenez où va votre argent",
        "phone_crop": (0.43, 0.30, 0.68, 0.98),
    },
    {
        "src": "promo_v2_02_stats.png",
        "out": "02_statistiques_1284x2778.png",
        "title": "Visualisez vos finances",
        "subtitle": "Graphiques clairs et détaillés",
        "phone_crop": (0.52, 0.06, 0.90, 0.96),
    },
    {
        "src": "promo_v2_03_budget.png",
        "out": "03_budget_categories_1284x2778.png",
        "title": "Budget par catégorie",
        "subtitle": "Ne dépassez plus vos limites",
        "phone_crop": (0.52, 0.06, 0.90, 0.96),
    },
    {
        "src": "promo_v2_04_pro.png",
        "out": "04_version_pro_1284x2778.png",
        "title": "Version Pro",
        "subtitle": "OCR, export, sans publicités",
        "phone_crop": (0.52, 0.06, 0.90, 0.96),
    },
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in ("segoeuib.ttf", "arialbd.ttf") if bold else ("segoeui.ttf", "arial.ttf"):
        path = f"C:/Windows/Fonts/{name}"
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def gradient(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(PURPLE_TOP[i] + (PURPLE_BOTTOM[i] - PURPLE_TOP[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=c)
    return img


def add_curves(base: Image.Image) -> None:
    ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.pieslice((-200, 400, 600, 1200), 300, 420, fill=(255, 255, 255, 18))
    d.pieslice((900, 1800, 1500, 2600), 120, 240, fill=(255, 255, 255, 14))
    d.ellipse((950, -100, 1350, 300), fill=(255, 255, 255, 12))
    base.paste(Image.alpha_composite(base.convert("RGBA"), ov).convert("RGB"))


def wrap_title(draw: ImageDraw.ImageDraw, text: str, font, max_w: int) -> list[str]:
    words = text.split()
    lines, line = [], ""
    for word in words:
        test = f"{line} {word}".strip()
        if draw.textlength(test, font=font) <= max_w:
            line = test
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def extract_phone(src: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    w, h = src.size
    l, t, r, b = box
    return src.crop((int(w * l), int(h * t), int(w * r), int(h * b)))


def paste_phone(canvas: Image.Image, phone: Image.Image, top_y: int) -> None:
    target_w = int(W * 0.72)
    ratio = target_w / phone.width
    target_h = int(phone.height * ratio)
    max_h = H - top_y - 80
    if target_h > max_h:
        ratio = max_h / phone.height
        target_w = int(phone.width * ratio)
        target_h = max_h
    phone = phone.resize((target_w, target_h), Image.Resampling.LANCZOS)

    x = (W - target_w) // 2
    y = top_y + (max_h - target_h) // 2

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (x + 12, y + 18, x + target_w + 12, y + target_h + 18),
        radius=48,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    canvas.paste(shadow, (0, 0), shadow)

    mask = Image.new("L", (target_w, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, target_w, target_h), 48, fill=255)
    canvas.paste(phone, (x, y), mask)


def build_slide(cfg: dict) -> Image.Image:
    src = Image.open(SRC / cfg["src"]).convert("RGB")
    phone = extract_phone(src, cfg["phone_crop"])

    canvas = gradient(W, H)
    add_curves(canvas)
    draw = ImageDraw.Draw(canvas)

    margin = 72
    max_w = W - 2 * margin
    title_font = load_font(92, bold=True)
    sub_font = load_font(48)

    y = 110
    for line in wrap_title(draw, cfg["title"], title_font, max_w):
        draw.text((margin, y), line, fill=WHITE, font=title_font)
        y += 108
    y += 16
    for line in wrap_title(draw, cfg["subtitle"], sub_font, max_w):
        draw.text((margin, y), line, fill=SUB, font=sub_font)
        y += 58

    paste_phone(canvas, phone, top_y=y + 40)
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for cfg in SLIDES:
        out = build_slide(cfg)
        dest = OUT / cfg["out"]
        out.save(dest, "PNG", optimize=True)
        assert out.size == (W, H)
        print(f"OK {dest.name} ({W}x{H}) style Buddy")


if __name__ == "__main__":
    main()

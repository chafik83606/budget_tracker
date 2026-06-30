#!/usr/bin/env python3
"""
Compose Play Store promo images from REAL app screenshots + polished templates.
Run integration_test/store_screenshots_test.dart first to capture raw screenshots.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).parent
RAW_DIR = ROOT / "screenshots" / "raw"
OUT_DIR = ROOT / "promo"
W, H = 1080, 1920

# Buddy-style purple palette
BG_TOP = (72, 45, 145)
BG_BOTTOM = (108, 72, 188)
ACCENT = (255, 255, 255)
SUBTEXT = (220, 210, 255)

CARDS = [
    {
        "raw": "01_home.png",
        "out": "01_accueil_solde_1080x1920.png",
        "title": "Suivez vos\ndépenses",
        "subtitle": "Comprenez où va votre argent",
    },
    {
        "raw": "02_stats.png",
        "out": "02_statistiques_1080x1920.png",
        "title": "Visualisez\nvos finances",
        "subtitle": "Graphiques clairs et détaillés",
    },
    {
        "raw": "03_categories.png",
        "out": "03_budget_categories_1080x1920.png",
        "title": "Budget par\ncatégorie",
        "subtitle": "Ne dépassez plus vos limites",
    },
    {
        "raw": "04_settings.png",
        "out": "04_version_pro_1080x1920.png",
        "title": "Version Pro\n& sauvegarde",
        "subtitle": "OCR, export, données protégées",
    },
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    paths = [
        ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/segoeui.ttf"),
        ("C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf"),
    ]
    for bold_p, reg_p in paths:
        p = bold_p if bold else reg_p
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def gradient_bg() -> Image.Image:
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3))
        draw.line([(0, y), (W, y)], fill=c)
    return img


def add_decorations(base: Image.Image) -> None:
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    blobs = [
        ((820, -80, 1180, 280), (255, 255, 255, 28)),
        ((-120, 420, 280, 820), (255, 255, 255, 18)),
        ((680, 1200, 1120, 1640), (255, 255, 255, 14)),
        ((-60, 1500, 360, 1920), (255, 255, 255, 20)),
    ]
    for box, color in blobs:
        draw.ellipse(box, fill=color)
    # Soft curve band
    draw.pieslice((-200, 260, 900, 1360), 300, 420, fill=(255, 255, 255, 12))
    base.paste(Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB"))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_phone(base: Image.Image, screenshot: Image.Image) -> None:
    phone_w, phone_h = 700, 1380
    px = (W - phone_w) // 2
    py = H - phone_h - 60

    # Shadow
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        (px + 14, py + 22, px + phone_w + 14, py + phone_h + 22),
        radius=56,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    base.paste(shadow, (0, 0), shadow)

    # Bezel
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(
        (px, py, px + phone_w, py + phone_h),
        radius=56,
        fill=(18, 18, 22),
    )

    inset = 16
    screen_w, screen_h = phone_w - inset * 2, phone_h - inset * 2
    sx, sy = px + inset, py + inset

    # Fit screenshot into screen area (crop center)
    fitted = ImageOps.fit(screenshot, (screen_w, screen_h), method=Image.Resampling.LANCZOS)
    mask = rounded_mask((screen_w, screen_h), 44)
    base.paste(fitted, (sx, sy), mask)

    # Notch / status bar hint
    notch_w = 180
    nx = px + (phone_w - notch_w) // 2
    draw.rounded_rectangle((nx, py + 8, nx + notch_w, py + 28), radius=10, fill=(18, 18, 22))


def draw_titles(base: Image.Image, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(base)
    font_title = load_font(78, bold=True)
    font_sub = load_font(38)

    y = 72
    for line in title.split("\n"):
        draw.text((64, y), line, fill=ACCENT, font=font_title)
        y += 86
    draw.text((64, y + 12), subtitle, fill=SUBTEXT, font=font_sub)


def compose_card(raw_name: str, out_name: str, title: str, subtitle: str) -> None:
    raw_path = RAW_DIR / raw_name
    if not raw_path.exists():
        raise FileNotFoundError(f"Capture manquante : {raw_path}\nLancez d'abord store_screenshots_test.dart")

    screenshot = Image.open(raw_path).convert("RGB")
    base = gradient_bg()
    add_decorations(base)
    draw_titles(base, title, subtitle)
    paste_phone(base, screenshot)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / out_name
    base.save(out, "PNG", optimize=True)
    print(f"OK {out}")


def compose_feature() -> None:
    raw = RAW_DIR / "01_home.png"
    if not raw.exists():
        return
    shot = Image.open(raw).convert("RGB")
    base = gradient_bg().resize((1024, 500), Image.Resampling.LANCZOS)
    add_decorations(base)
    draw = ImageDraw.Draw(base)
    draw.text((48, 140), "Budget Tracker Finance", fill=ACCENT, font=load_font(54, bold=True))
    draw.text(
        (48, 210),
        "Suivez vos dépenses · Gérez votre budget",
        fill=SUBTEXT,
        font=load_font(26),
    )
    # Mini phone
    mini = ImageOps.fit(shot, (240, 480), Image.Resampling.LANCZOS)
    mask = rounded_mask((240, 480), 28)
    base.paste(mini, (740, 10), mask)
    out = OUT_DIR / "feature_graphic_1024x500.png"
    base.save(out, "PNG", optimize=True)
    print(f"OK {out}")


def main() -> None:
    for card in CARDS:
        compose_card(card["raw"], card["out"], card["title"], card["subtitle"])
    compose_feature()
    print(f"\nImages finales dans {OUT_DIR}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate Play Store / App Store promotional images for Budget Tracker Finance."""

from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).parent / "promo"
W, H = 1080, 1920
FEATURE_W, FEATURE_H = 1024, 500

# Buddy-inspired palette + Budget Tracker indigo/green
PURPLE_TOP = (88, 56, 168)
PURPLE_BOTTOM = (120, 82, 196)
INDIGO = (63, 81, 181)
GREEN = (46, 125, 50)
GREEN_LIGHT = (102, 187, 106)
WHITE = (255, 255, 255)
GREY_BG = (245, 245, 248)
GREY_TEXT = (110, 110, 120)
CARD = (255, 255, 255)
RED = (229, 57, 53)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def vertical_gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    w, h = size
    for y in range(h):
        t = y / max(h - 1, 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (w, y)], fill=color)
    return img


def draw_rounded_rect(draw: ImageDraw.ImageDraw, xy, radius: int, fill, outline=None, width: int = 1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_phone_frame(base: Image.Image, phone_x: int, phone_y: int, phone_w: int, phone_h: int) -> tuple[int, int, int, int]:
    draw = ImageDraw.Draw(base)
    radius = 48
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle(
        (phone_x + 8, phone_y + 12, phone_x + phone_w + 8, phone_y + phone_h + 12),
        radius=radius,
        fill=(0, 0, 0, 60),
    )
    base.paste(shadow, (0, 0), shadow)
    draw.rounded_rectangle((phone_x, phone_y, phone_x + phone_w, phone_y + phone_h), radius=radius, fill=(20, 20, 24))
    inset = 14
    inner = (phone_x + inset, phone_y + inset, phone_x + phone_w - inset, phone_y + phone_h - inset)
    draw.rounded_rectangle(inner, radius=radius - 8, fill=GREY_BG)
    return inner


def draw_app_bar(draw: ImageDraw.ImageDraw, inner, title: str):
    x0, y0, x1, y1 = inner
    draw.rectangle((x0, y0, x1, y0 + 88), fill=INDIGO)
    font = load_font(34, bold=True)
    tw = draw.textlength(title, font=font)
    draw.text(((x0 + x1 - tw) / 2, y0 + 24), title, fill=WHITE, font=font)


def draw_nav_bar(draw: ImageDraw.ImageDraw, inner):
    x0, y0, x1, y1 = inner
    h = 96
    draw.rectangle((x0, y1 - h, x1, y1), fill=WHITE)
    labels = [("Accueil", True), ("Statistiques", False), ("Réglages", False)]
    slot = (x1 - x0) / 3
    font = load_font(22)
    for i, (label, active) in enumerate(labels):
        cx = x0 + slot * i + slot / 2
        color = INDIGO if active else GREY_TEXT
        tw = draw.textlength(label, font=font)
        draw.text((cx - tw / 2, y1 - 52), label, fill=color, font=font)
        if active:
            draw.ellipse((cx - 6, y1 - 78, cx + 6, y1 - 66), fill=INDIGO)


def draw_balance_header(draw: ImageDraw.ImageDraw, inner, balance: str, income: str, expense: str):
    x0, y0, x1, _ = inner
    h = 150
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(int(GREEN[i] + (GREEN_LIGHT[i] - GREEN[i]) * t) for i in range(3))
        draw.line([(x0, y0 + 88 + y), (x1, y0 + 88 + y)], fill=c)
    font_l = load_font(24)
    font_b = load_font(44, bold=True)
    font_s = load_font(22)
    draw.text((x0 + 24, y0 + 104), "Solde du mois", fill=(255, 255, 255, 200), font=font_l)
    draw.text((x0 + 24, y0 + 136), balance, fill=WHITE, font=font_b)
    draw.text((x1 - 180, y0 + 110), "Revenus", fill=(200, 255, 200), font=font_s)
    draw.text((x1 - 180, y0 + 136), income, fill=WHITE, font=load_font(26, bold=True))
    draw.text((x1 - 180, y0 + 178), "Dépenses", fill=(255, 200, 200), font=font_s)
    draw.text((x1 - 180, y0 + 204), expense, fill=WHITE, font=load_font(26, bold=True))


def draw_transaction_row(draw, x0, y, x1, icon: str, label: str, cat: str, amount: str, negative: bool):
    draw_rounded_rect(draw, (x0 + 16, y, x1 - 16, y + 88), 16, CARD)
    draw.text((x0 + 32, y + 18), icon, fill=GREY_TEXT, font=load_font(28))
    draw.text((x0 + 80, y + 16), label, fill=(30, 30, 40), font=load_font(26, bold=True))
    draw.text((x0 + 80, y + 48), cat, fill=GREY_TEXT, font=load_font(20))
    color = RED if negative else GREEN
    tw = draw.textlength(amount, font=load_font(26, bold=True))
    draw.text((x1 - 32 - tw, y + 28), amount, fill=color, font=load_font(26, bold=True))


def draw_home_screen(draw, inner):
    draw_app_bar(draw, inner, "Budget Tracker")
    draw_balance_header(draw, inner, "847,50 €", "2 450,00 €", "1 602,50 €")
    x0, y0, x1, y1 = inner
    y = y0 + 260
    draw.text((x0 + 24, y), "◀  juin 2026  ▶", fill=GREY_TEXT, font=load_font(24))
    y += 48
    rows = [
        ("🛒", "Carrefour", "Courses", "-67,40 €", True),
        ("⛽", "Total", "Transport", "-52,00 €", True),
        ("🏠", "Loyer", "Logement", "-750,00 €", True),
        ("💼", "Salaire", "Revenus", "+2 450,00 €", False),
    ]
    for icon, label, cat, amt, neg in rows:
        draw_transaction_row(draw, x0, y, x1, icon, label, cat, amt, neg)
        y += 100
    draw_nav_bar(draw, inner)
    fab_x, fab_y = x1 - 90, y1 - 180
    draw.ellipse((fab_x, fab_y, fab_x + 120, fab_y + 56), fill=INDIGO)
    draw.text((fab_x + 18, fab_y + 14), "+ Ajouter", fill=WHITE, font=load_font(22, bold=True))


def draw_pie_chart(draw, cx, cy, r, slices):
    start = -90
    for value, color in slices:
        sweep = value / 100 * 360
        draw.pieslice((cx - r, cy - r, cx + r, cy + r), start, start + sweep, fill=color)
        start += sweep
    draw.ellipse((cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55), fill=WHITE)
    draw.text((cx - 50, cy - 18), "1 602 €", fill=(30, 30, 40), font=load_font(28, bold=True))


def draw_stats_screen(draw, inner):
    draw_app_bar(draw, inner, "Statistiques")
    x0, y0, x1, y1 = inner
    y = y0 + 110
    draw.text((x0 + 24, y), "Dépenses par catégorie", fill=(30, 30, 40), font=load_font(30, bold=True))
    draw.text((x0 + 24, y + 40), "juin 2026", fill=GREY_TEXT, font=load_font(24))
    cx = (x0 + x1) // 2
    draw_pie_chart(
        draw,
        cx,
        y + 220,
        150,
        [(47, (63, 81, 181)), (18, (255, 183, 77)), (15, (77, 182, 172)), (12, (239, 83, 80)), (8, (171, 71, 188))],
    )
    y += 420
    cats = [("Logement", "750 €", 47, INDIGO), ("Courses", "280 €", 18, (255, 183, 77)), ("Transport", "180 €", 12, (77, 182, 172))]
    for name, amt, pct, color in cats:
        draw_rounded_rect(draw, (x0 + 24, y, x1 - 24, y + 56), 12, CARD)
        draw.rectangle((x0 + 36, y + 18, x0 + 52, y + 38), fill=color)
        draw.text((x0 + 64, y + 14), name, fill=(30, 30, 40), font=load_font(24))
        draw.text((x1 - 140, y + 14), f"{pct}%  {amt}", fill=GREY_TEXT, font=load_font(22))
        y += 68
    y += 20
    draw.text((x0 + 24, y), "Évolution mensuelle", fill=(30, 30, 40), font=load_font(28, bold=True))
    y += 50
    bars = [("Jan", 120), ("Fév", 90), ("Mar", 140), ("Avr", 110), ("Mai", 130), ("Juin", 160)]
    bw = (x1 - x0 - 48) // len(bars)
    for i, (label, h) in enumerate(bars):
        bx = x0 + 24 + i * bw + bw // 4
        by = y + 180 - h
        draw_rounded_rect(draw, (bx, by, bx + bw // 2, y + 180), 8, INDIGO)
        draw.text((bx, y + 190), label, fill=GREY_TEXT, font=load_font(18))
    draw_nav_bar(draw, inner)


def draw_budget_screen(draw, inner):
    draw_app_bar(draw, inner, "Catégories")
    x0, y0, x1, y1 = inner
    y = y0 + 110
    cats = [
        ("🏠", "Logement", "750 € / 800 €", 0.94, GREEN),
        ("🛒", "Courses", "280 € / 350 €", 0.80, GREEN),
        ("🚗", "Transport", "180 € / 150 €", 1.0, RED),
        ("🎮", "Loisirs", "95 € / 120 €", 0.79, GREEN),
    ]
    for icon, name, budget, ratio, color in cats:
        draw_rounded_rect(draw, (x0 + 24, y, x1 - 24, y + 120), 16, CARD)
        draw.text((x0 + 40, y + 20), icon, font=load_font(32))
        draw.text((x0 + 96, y + 18), name, fill=(30, 30, 40), font=load_font(28, bold=True))
        draw.text((x0 + 96, y + 54), budget, fill=GREY_TEXT, font=load_font(22))
        bar_x0, bar_x1 = x0 + 96, x1 - 40
        draw_rounded_rect(draw, (bar_x0, y + 86, bar_x1, y + 102), 8, (230, 230, 235))
        fill_w = int((bar_x1 - bar_x0) * min(ratio, 1.0))
        if fill_w > 0:
            draw_rounded_rect(draw, (bar_x0, y + 86, bar_x0 + fill_w, y + 102), 8, color)
        y += 136
    draw_nav_bar(draw, inner)


def draw_pro_screen(draw, inner):
    draw_app_bar(draw, inner, "Réglages")
    x0, y0, x1, y1 = inner
    y = y0 + 110
    draw_rounded_rect(draw, (x0 + 24, y, x1 - 24, y + 200), 20, (255, 243, 200))
    draw.text((x0 + 48, y + 24), "⭐ Budget Tracker Pro", fill=(120, 80, 0), font=load_font(30, bold=True))
    features = [
        "✅ Scan OCR de tickets",
        "✅ Import & export CSV/PDF",
        "✅ Budget par catégorie",
        "✅ Sauvegarde chiffrée",
        "✅ Sans publicités",
    ]
    fy = y + 70
    for f in features[:3]:
        draw.text((x0 + 48, fy), f, fill=(80, 60, 20), font=load_font(22))
        fy += 34
    y += 230
    draw.text((x0 + 24, y), "Sauvegarde automatique", fill=(30, 30, 40), font=load_font(28, bold=True))
    y += 48
    draw_rounded_rect(draw, (x0 + 24, y, x1 - 24, y + 100), 16, CARD)
    draw.text((x0 + 48, y + 20), "Dernière : aujourd'hui", fill=GREY_TEXT, font=load_font(22))
    draw.text((x0 + 48, y + 52), "2 copies max. (aujourd'hui + hier)", fill=(30, 30, 40), font=load_font(24))
    y += 130
    draw_rounded_rect(draw, (x0 + 24, y, x1 - 24, y + 88), 16, CARD)
    draw.text((x0 + 48, y + 28), "📷 Scanner un ticket (OCR)", fill=(30, 30, 40), font=load_font(26))
    draw_nav_bar(draw, inner)


def draw_hero_card(draw, inner):
    x0, y0, x1, y1 = inner
    draw_rounded_rect(draw, (x0 + 24, y0 + 110, x1 - 24, y0 + 340), 24, WHITE)
    font_h = load_font(36, bold=True)
    font_s = load_font(26)
    draw.text((x0 + 48, y0 + 150), "Budget Tracker Finance", fill=INDIGO, font=font_h)
    draw.text((x0 + 48, y0 + 210), "Simple · Local · Français", fill=GREY_TEXT, font=font_s)
    draw.text((x0 + 48, y0 + 260), "Gratuit avec version Pro", fill=GREEN, font=load_font(24, bold=True))
    draw.text((x0 + 48, y0 + 380), "★★★★★", fill=(255, 193, 7), font=load_font(32))
    draw.text((x0 + 48, y0 + 430), "Gérez votre budget au quotidien", fill=WHITE, font=load_font(34, bold=True))
    draw_home_screen(draw, inner)


def make_promo_card(filename: str, headline: str, subline: str, screen: str):
    img = vertical_gradient((W, H), PURPLE_TOP, PURPLE_BOTTOM)
    draw = ImageDraw.Draw(img)

    font_h = load_font(62, bold=True)
    font_s = load_font(36)

    # Headline wrapping
    lines = []
    words = headline.split()
    line = ""
    for w in words:
        test = (line + " " + w).strip()
        if draw.textlength(test, font=font_h) < W - 120:
            line = test
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)

    y = 80
    for ln in lines:
        draw.text((60, y), ln, fill=WHITE, font=font_h)
        y += 72
    draw.text((60, y + 8), subline, fill=(230, 220, 255), font=font_s)

    phone_w, phone_h = 620, 1180
    phone_x = (W - phone_w) // 2
    phone_y = H - phone_h - 80
    inner = draw_phone_frame(img, phone_x, phone_y, phone_w, phone_h)
    draw = ImageDraw.Draw(img)

    screens = {
        "home": draw_home_screen,
        "stats": draw_stats_screen,
        "budget": draw_budget_screen,
        "pro": draw_pro_screen,
        "hero": draw_hero_card,
    }
    screens[screen](draw, inner)

    out = OUT_DIR / filename
    img.save(out, "PNG", optimize=True)
    print(f"Created {out}")


def make_feature_graphic():
    img = vertical_gradient((FEATURE_W, FEATURE_H), PURPLE_TOP, PURPLE_BOTTOM)
    draw = ImageDraw.Draw(img)
    draw.text((48, 120), "Budget Tracker Finance", fill=WHITE, font=load_font(52, bold=True))
    draw.text((48, 190), "Suivez vos dépenses · Gérez votre budget", fill=(230, 220, 255), font=load_font(28))
    # Mini phone
    pw, ph = 220, 380
    px, py = FEATURE_W - pw - 48, 60
    inner = draw_phone_frame(img, px, py, pw, ph)
    draw = ImageDraw.Draw(img)
    draw_app_bar(draw, inner, "Budget Tracker")
    draw_balance_header(draw, inner, "847 €", "2 450 €", "1 602 €")
    out = OUT_DIR / "feature_graphic_1024x500.png"
    img.save(out, "PNG", optimize=True)
    print(f"Created {out}")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cards = [
        ("01_accueil_solde_1080x1920.png", "Suivez vos dépenses", "Comprenez où va votre argent", "home"),
        ("02_statistiques_1080x1920.png", "Visualisez vos finances", "Graphiques clairs et détaillés", "stats"),
        ("03_budget_categories_1080x1920.png", "Budget par catégorie", "Ne dépassez plus vos limites", "budget"),
        ("04_version_pro_1080x1920.png", "Passez à la version Pro", "OCR, export, sans publicités", "pro"),
    ]
    for filename, head, sub, screen in cards:
        make_promo_card(filename, head, sub, screen)
    make_feature_graphic()
    print(f"\nDone — {len(cards) + 1} images in {OUT_DIR}")


if __name__ == "__main__":
    main()

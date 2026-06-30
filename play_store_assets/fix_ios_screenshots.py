#!/usr/bin/env python3
"""Redimensionne en plein écran exact (1284x2778 / 1242x2688), sans bandes."""

from pathlib import Path

from PIL import Image

SRC = Path(__file__).parent / "promo"
TARGETS = [(1242, 2688), (1284, 2778)]
SOURCES = [
    ("promo_v2_01_accueil.png", "01_accueil"),
    ("promo_v2_02_stats.png", "02_statistiques"),
    ("promo_v2_03_budget.png", "03_budget_categories"),
    ("promo_v2_04_pro.png", "04_version_pro"),
]


def main() -> None:
    for tw, th in TARGETS:
        out_dir = SRC / f"ios_{tw}x{th}"
        out_dir.mkdir(parents=True, exist_ok=True)
        for src_name, base in SOURCES:
            path = SRC / src_name
            if not path.exists():
                continue
            im = Image.open(path).convert("RGB")
            out = im.resize((tw, th), Image.Resampling.LANCZOS)
            dest = out_dir / f"{base}_{tw}x{th}.png"
            out.save(dest, "PNG", optimize=True)
            print(f"OK {dest.name}")


if __name__ == "__main__":
    main()

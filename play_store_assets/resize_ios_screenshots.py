#!/usr/bin/env python3
"""Export App Store screenshots at exact Apple-required pixel sizes."""

from pathlib import Path

from PIL import Image, ImageFilter

SRC = Path(__file__).parent / "promo"
TW, TH = 1242, 2688

# App Store Connect — iPhone 6,5" / 6,7" (portrait)
TARGETS = [
    (1242, 2688, "ios_1242x2688"),
    (1284, 2778, "ios_1284x2778"),
]

FILES = [
    ("01_accueil_1080x1920.png", "01_accueil"),
    ("02_stats_1080x1920.png", "02_statistiques"),
    ("03_budget_1080x1920.png", "03_budget_categories"),
    ("04_pro_1080x1920.png", "04_version_pro"),
]


def to_exact_size(im: Image.Image, tw: int, th: int) -> Image.Image:
    im = im.convert("RGB")
    bg_scale = max(tw / im.width, th / im.height)
    bg = im.resize(
        (int(im.width * bg_scale), int(im.height * bg_scale)),
        Image.Resampling.LANCZOS,
    )
    left = (bg.width - tw) // 2
    top = (bg.height - th) // 2
    bg = bg.crop((left, top, left + tw, top + th)).filter(ImageFilter.GaussianBlur(28))

    fg_scale = min(tw / im.width, th / im.height)
    fg = im.resize(
        (int(im.width * fg_scale), int(im.height * fg_scale)),
        Image.Resampling.LANCZOS,
    )
    canvas = bg.copy()
    canvas.paste(fg, ((tw - fg.width) // 2, (th - fg.height) // 2))
    assert canvas.size == (tw, th), canvas.size
    return canvas


def main() -> None:
    for tw, th, folder in TARGETS:
        out_dir = SRC / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n=== {tw} x {th} -> {folder}/ ===")
        for src_name, base in FILES:
            src = SRC / src_name
            if not src.exists():
                print(f"SKIP: {src}")
                continue
            im = Image.open(src)
            out = to_exact_size(im, tw, th)
            dest = out_dir / f"{base}_{tw}x{th}.png"
            out.save(dest, "PNG", optimize=True)
            check = Image.open(dest)
            print(f"OK {dest.name} -> {check.size[0]}x{check.size[1]} px")


if __name__ == "__main__":
    main()

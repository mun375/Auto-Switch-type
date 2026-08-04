#!/usr/bin/env python3
"""Recolour the inherited McBopomofo icons for the Switchless rebrand.

The glyph shape is upstream's and stays as it is; only the hue moves, so the
input menu no longer shows two identical-looking icons when both Switchless and
McBopomofo are installed. This is a placeholder until Switchless gets an icon of
its own — rerun it after any upstream icon sync.

The transform is a fixed hue rotation in HSV with saturation and value left
alone, which keeps every shading variant (highlights, antialiased edges,
translucent pixels) consistent with each other.

Usage: python3 scripts/recolor_icons.py [--check]
       --check reports the resulting colours without writing anything.
"""

import argparse
import colorsys
import pathlib
import sys

from PIL import Image

# Upstream's navy is hue 214°; Switchless uses a deep ink-teal at 168°.
SOURCE_HUE = 214.0
TARGET_HUE = 168.0
HUE_SHIFT = (TARGET_HUE - SOURCE_HUE) / 360.0

IME_ROOT = pathlib.Path(__file__).resolve().parent.parent / "vendor" / "McBopomofo"
IMAGES = IME_ROOT / "Source" / "Images"

TARGETS = [
    *sorted((IMAGES / "Images.xcassets" / "AppIcon.appiconset").glob("*.png")),
    *sorted((IMAGES / "Images.xcassets" / "AlertIcon.imageset").glob("*.png")),
    IMAGES / "Bopomofo.tiff",
    IMAGES / "Bopomofo@2x.tiff",
    IMAGES / "PlainBopomofo.tiff",
    IMAGES / "PlainBopomofo@2x.tiff",
]


def shift_pixel(r: int, g: int, b: int) -> tuple[int, int, int]:
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    # Greys have no meaningful hue; rotating them would tint the glyph.
    if s < 0.05:
        return r, g, b
    h = (h + HUE_SHIFT) % 1.0
    r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
    return round(r2 * 255), round(g2 * 255), round(b2 * 255)


def recolour(path: pathlib.Path, dry_run: bool) -> str:
    image = Image.open(path)
    fmt = image.format
    rgba = image.convert("RGBA")
    cache: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    out = []
    for r, g, b, a in rgba.getdata():
        key = (r, g, b)
        if key not in cache:
            cache[key] = shift_pixel(r, g, b)
        out.append((*cache[key], a))
    rgba.putdata(out)
    sample = cache.get((21, 55, 104), "n/a")
    if not dry_run:
        rgba.save(path, format=fmt)
    return f"{path.relative_to(IME_ROOT)}: navy (21,55,104) -> {sample}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="do not write files")
    args = parser.parse_args()

    missing = [p for p in TARGETS if not p.exists()]
    if missing:
        print("error: missing icon files:", *missing, sep="\n  ", file=sys.stderr)
        return 1

    for path in TARGETS:
        print(recolour(path, dry_run=args.check))
    print(f"{'checked' if args.check else 'recoloured'} {len(TARGETS)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Install the app icon from the source artwork.

Reads docs/branding/AppIcon-source.webp (the artwork as delivered, kept
unmodified) and writes into Assets.xcassets:

    AppIcon.appiconset/AppIcon-1024.png   1024 × 1024, opaque RGB, square
    AppLogo.imageset/AppLogo.png          512 × 512, the logo on the app's screen

Needs Pillow:

    python3 scripts/make_icon.py

The only change to the artwork: stray pixels in the outermost columns and
rows (leftovers of a rounded outline, a few pixels wide, darker than the
field) are painted with the field colour next to them, so the icon is a
clean full-bleed square as iOS requires. Nothing inside that border is
touched; the script reports how many pixels it repainted and stops if the
source is not the expected size or the strays reach further in.
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(REPO, "docs", "branding", "AppIcon-source.webp")
ASSETS = os.path.join(REPO, "KumykKeyboard", "KumykKeyboard", "Assets.xcassets")
SIZE = 1024
BORDER = 8        # px from each edge that may be repainted
REFERENCE = 24    # px inward from the edge where the field colour is sampled
TOLERANCE = 30    # summed RGB difference that counts as a stray pixel


def distance(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def main():
    source = Image.open(SOURCE)
    if source.size != (SIZE, SIZE):
        sys.exit(f"error: the source is {source.size}, expected {SIZE} × {SIZE}")
    if "A" in source.getbands() and source.getchannel("A").getextrema()[0] < 255:
        sys.exit("error: the source has transparent pixels; an app icon must be opaque")
    img = source.convert("RGB")
    px = img.load()

    repainted = 0
    for y in range(SIZE):
        for x in range(SIZE):
            edge = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            if edge >= BORDER:
                continue
            # The field colour of this row or column, further inside
            if x < BORDER:
                field = px[REFERENCE, y]
            elif x >= SIZE - BORDER:
                field = px[SIZE - 1 - REFERENCE, y]
            elif y < BORDER:
                field = px[x, REFERENCE]
            else:
                field = px[x, SIZE - 1 - REFERENCE]
            if distance(px[x, y], field) > TOLERANCE:
                px[x, y] = field
                repainted += 1

    # Nothing just inside the border may still look like a stray
    for y in range(SIZE):
        for x in (BORDER, SIZE - 1 - BORDER):
            inner = px[REFERENCE if x == BORDER else SIZE - 1 - REFERENCE, y]
            if distance(px[x, y], inner) > TOLERANCE:
                sys.exit(f"error: a stray pixel at ({x}, {y}) is deeper than the {BORDER} px border")

    img.save(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png"), "PNG", optimize=True)
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(ASSETS, "AppLogo.imageset", "AppLogo.png"),
                                               "PNG", optimize=True)
    print(f"icon installed: {SIZE} × {SIZE} RGB, {repainted} stray border pixels repainted")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Renders the PWA icons and favicon used when MacroDash is installed.

Run from the repo root:

    python3 scripts/make_icons.py

Only Pillow and numpy are required. The mark mirrors assets/macrodash.svg (and
scripts/make_og_image.py) so the installed icon matches the in-app logo.

Launchers crop maskable icons to their own shape, so those variants keep the
mark inside the centre 80% "safe zone" instead of the full canvas.
"""

import os

import numpy as np
from PIL import Image, ImageDraw

from make_og_image import EMERALD, EMERALD_LIGHT, NAVY_BOTTOM, NAVY_TOP

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "web", "icons")
FAVICON = os.path.join(ROOT, "web", "favicon.png")

SUPERSAMPLE = 4

# Fraction of the canvas the mark spans. 1.0 matches the in-app logo; maskable
# icons shrink it so cropping to a circle or squircle never clips the mark.
FULL_BLEED_MARK_SCALE = 1.0
MASKABLE_MARK_SCALE = 0.8


def diagonal_gradient(size):
    """The navy tile gradient from the logo (top-left to bottom-right)."""
    width, height = size
    x, y = np.meshgrid(np.arange(width), np.arange(height))
    t = (x + y) / max(width + height - 2, 1)
    channels = [
        np.round(top + (bottom - top) * t).astype(np.uint8)
        for top, bottom in zip(NAVY_TOP, NAVY_BOTTOM)
    ]
    return Image.fromarray(np.dstack(channels), "RGB")


def draw_mark(canvas, mark_scale):
    """The "M" chart-line monogram, scaled about the canvas centre."""
    width, height = canvas.size
    unit = min(width, height) / 64 * mark_scale
    centre_x, centre_y = width / 2, height / 2

    def point(svg_x, svg_y):
        return (centre_x + (svg_x - 32) * unit, centre_y + (svg_y - 32) * unit)

    points = [
        point(15, 48),
        point(15, 22),
        point(32, 38),
        point(49, 16),
        point(49, 48),
    ]
    draw = ImageDraw.Draw(canvas)
    draw.line(points, fill=EMERALD, width=round(6.5 * unit), joint="curve")
    for svg_x, svg_y in ((15, 22), (49, 16)):
        radius = 3 * unit
        x, y = point(svg_x, svg_y)
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius), fill=EMERALD_LIGHT
        )


def render(size, mark_scale):
    """Renders a square icon, supersampled so the strokes stay smooth."""
    tile = diagonal_gradient((size, size))
    canvas = tile.resize(
        (size * SUPERSAMPLE, size * SUPERSAMPLE), Image.LANCZOS
    )
    draw_mark(canvas, mark_scale)
    return canvas.resize((size, size), Image.LANCZOS)


def main():
    icons = {
        "Icon-180.png": (180, FULL_BLEED_MARK_SCALE),
        "Icon-192.png": (192, FULL_BLEED_MARK_SCALE),
        "Icon-512.png": (512, FULL_BLEED_MARK_SCALE),
        "Icon-maskable-192.png": (192, MASKABLE_MARK_SCALE),
        "Icon-maskable-512.png": (512, MASKABLE_MARK_SCALE),
    }
    for name, (size, mark_scale) in icons.items():
        path = os.path.join(ICONS, name)
        render(size, mark_scale).save(path, optimize=True)
        print(f"wrote {os.path.relpath(path, ROOT)}")

    render(64, FULL_BLEED_MARK_SCALE).save(FAVICON, optimize=True)
    print(f"wrote {os.path.relpath(FAVICON, ROOT)}")


if __name__ == "__main__":
    main()

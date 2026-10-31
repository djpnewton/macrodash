#!/usr/bin/env python3
"""Renders web/og-image.png, the 1200x630 card used for link previews.

Run from the repo root:

    python3 scripts/make_og_image.py

Only Pillow is required. The mark mirrors assets/macrodash.svg so the preview
and the in-app logo stay in sync.
"""

import os

from PIL import Image, ImageDraw, ImageFont

SCALE = 2
WIDTH, HEIGHT = 1200, 630
W, H = WIDTH * SCALE, HEIGHT * SCALE

NAVY_TOP = (27, 53, 89)  # #1B3559
NAVY_BOTTOM = (11, 27, 51)  # #0B1B33
EMERALD = (52, 211, 153)  # #34D399
EMERALD_LIGHT = (167, 243, 208)  # #A7F3D0
INK = (230, 237, 247)  # #E6EDF7
MUTED = (169, 186, 205)  # #A9BACD
SUBTLE = (126, 147, 171)  # #7E93AB
GRID = (44, 71, 103)  # #2C4767

FONT_CANDIDATES = {
    "bold": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ],
    "regular": [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ],
}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "web", "og-image.png")


def font(kind, size):
    for path in FONT_CANDIDATES[kind]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size * SCALE)
    raise SystemExit(f"no {kind} font found, looked in: {FONT_CANDIDATES[kind]}")


def vertical_gradient(size, top, bottom):
    image = Image.new("RGB", (1, size[1]))
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        draw.point(
            (0, y),
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)),
        )
    return image.resize(size)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius * SCALE, fill=255
    )
    return mask


def draw_mark(canvas, origin, size):
    """The "M" chart-line monogram from assets/macrodash.svg."""
    x0, y0 = origin
    tile = vertical_gradient((size, size), NAVY_TOP, NAVY_BOTTOM)
    canvas.paste(tile, (x0, y0), rounded_mask((size, size), int(size / 6.4)))

    point = lambda px, py: (  # noqa: E731 - compact SVG -> pixel mapping
        x0 + px / 64 * size,
        y0 + py / 64 * size,
    )
    m_points = [point(15, 48), point(15, 22), point(32, 38), point(49, 16),
                point(49, 48)]
    draw = ImageDraw.Draw(canvas)
    draw.line(m_points, fill=EMERALD, width=round(6.5 / 64 * size), joint="curve")
    for svg_x, svg_y in ((15, 22), (49, 16)):
        r = 3 / 64 * size
        cx, cy = point(svg_x, svg_y)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=EMERALD_LIGHT)


def draw_chart(canvas, box):
    """Area sparkline suggesting market data."""
    left, top, right, bottom = box
    draw = ImageDraw.Draw(canvas)
    for y in (top, bottom):
        draw.line((left, y, right, y), fill=GRID, width=SCALE)

    # deterministic, plausible-looking walk
    steps = 120
    values, value, seed = [], 0.45, 7
    for _ in range(steps):
        seed = (seed * 1103515245 + 12345) % 2**31
        value += ((seed / 2**31) - 0.45) * 0.11
        value = min(max(value, 0.08), 0.95)
        values.append(value)

    points = [
        (left + (right - left) * i / (steps - 1), bottom - (bottom - top) * v)
        for i, v in enumerate(values)
    ]
    fill = [(left, bottom), *points, (right, bottom)]
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(overlay).polygon(fill, fill=EMERALD + (46,))
    canvas.alpha_composite(overlay)
    ImageDraw.Draw(canvas).line(points, fill=EMERALD, width=round(2.5 * SCALE))


def main():
    canvas = Image.new("RGBA", (W, H))
    canvas.paste(vertical_gradient((W, H), NAVY_TOP, NAVY_BOTTOM))

    # faint vertical grid, like the app's charts
    draw = ImageDraw.Draw(canvas)
    for x in range(0, W, 100 * SCALE):
        draw.line((x, H * 0.30, x, H), fill=GRID + (90,), width=SCALE)

    draw_mark(canvas, (80 * SCALE, 84 * SCALE), 96 * SCALE)

    draw.text((200 * SCALE, 88 * SCALE), "MacroDash", font=font("bold", 76),
              fill=INK)
    draw.text((202 * SCALE, 188 * SCALE), "Macroeconomic dashboard",
              font=font("regular", 32), fill=MUTED)
    draw.text((202 * SCALE, 240 * SCALE),
              "Markets  ·  M2  ·  Debt  ·  Bond rates  ·  Market cap",
              font=font("regular", 26), fill=SUBTLE)
    draw.text((80 * SCALE, 578 * SCALE), "macrodash.me",
              font=font("regular", 24), fill=SUBTLE)

    draw_chart(canvas, (80 * SCALE, 400 * SCALE, 1120 * SCALE, 545 * SCALE))

    canvas.convert("RGB").resize((WIDTH, HEIGHT), Image.LANCZOS).save(
        OUTPUT, optimize=True
    )
    print(f"wrote {os.path.relpath(OUTPUT, ROOT)}")


if __name__ == "__main__":
    main()

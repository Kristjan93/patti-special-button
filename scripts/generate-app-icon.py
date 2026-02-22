#!/usr/bin/env python3
"""Generate the macOS app icon for pattiSpecialButton.

Creates a polished squircle icon with a hot pink-to-coral gradient
background and the asynchronous-butt line art centered on top.
Outputs all 10 required PNG sizes for the Xcode asset catalog.

Usage:
    cd scripts/
    source .venv/bin/activate
    python3 generate-app-icon.py
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

# -- Configuration ----------------------------------------------------------

CANVAS_SIZE = 1024
ICON_BODY_SIZE = 824        # Apple spec: icon body within 1024 canvas
SQUIRCLE_EXPONENT = 5.0     # Superellipse n — matches Apple's continuous corners
SUPERSAMPLE = 4             # Anti-aliasing quality multiplier
BUTT_SCALE = 0.72           # Butt art as fraction of icon body

# Gradient: peach cream -> blush pink (diagonal, top-left to bottom-right)
COLOR_TOP = (255, 245, 238)     # #FFF5EE — warm peach cream
COLOR_BOTTOM = (255, 205, 190)  # #FFCDBE — soft blush

SCRIPT_DIR = Path(__file__).resolve().parent
GIF_PATH = SCRIPT_DIR / "fractured-but-whole" / "Asynchronous-Butt.gif"
OUTPUT_DIR = (
    SCRIPT_DIR.parent
    / "pattiSpecialButton"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)

OUTPUT_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


# -- Helpers ----------------------------------------------------------------

def extract_butt_art(gif_path: Path) -> Image.Image:
    """Extract frame 0 from the source GIF and convert to RGBA outline art.

    Same pipeline as brazilian-butt-lift.py: grayscale -> invert -> alpha.
    Black outlines become opaque, white background becomes transparent.
    """
    img = Image.open(gif_path)
    img.seek(0)

    canvas = Image.new("RGBA", img.size, (255, 255, 255, 255))
    frame = img.convert("RGBA")
    canvas.paste(frame, (0, 0), frame)

    grayscale = canvas.convert("L")
    inverted = ImageOps.invert(grayscale)
    black = Image.new("L", grayscale.size, 0)
    return Image.merge("RGBA", (black, black, black, inverted))


def make_gradient(size: int, c1: tuple, c2: tuple) -> Image.Image:
    """Create a diagonal linear gradient from top-left to bottom-right."""
    img = Image.new("RGBA", (size, size))
    pixels = img.load()
    max_dist = 2.0 * (size - 1)
    for y in range(size):
        for x in range(size):
            t = (x + y) / max_dist
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)
            pixels[x, y] = (r, g, b, 255)
    return img


def make_squircle_mask(
    canvas_size: int,
    body_size: int,
    exponent: float = 5.0,
    supersample: int = 4,
) -> Image.Image:
    """Generate an anti-aliased superellipse mask.

    Renders at supersample resolution then downsamples with LANCZOS
    for smooth edges. Returns a grayscale mask (white = inside).
    """
    render_size = canvas_size * supersample
    body_render = body_size * supersample

    a = body_render / 2.0
    b = body_render / 2.0
    cx = render_size / 2.0
    cy = render_size / 2.0

    num_points = 2000
    points = []
    for i in range(num_points):
        theta = 2 * math.pi * i / num_points
        cos_t = math.cos(theta)
        sin_t = math.sin(theta)
        x = cx + a * abs(cos_t) ** (2.0 / exponent) * (1 if cos_t >= 0 else -1)
        y = cy + b * abs(sin_t) ** (2.0 / exponent) * (1 if sin_t >= 0 else -1)
        points.append((x, y))

    mask_big = Image.new("L", (render_size, render_size), 0)
    draw = ImageDraw.Draw(mask_big)
    draw.polygon(points, fill=255)

    return mask_big.resize((canvas_size, canvas_size), Image.LANCZOS)


def build_master_icon(butt_art: Image.Image) -> Image.Image:
    """Compose the 1024x1024 master icon."""
    gradient = make_gradient(CANVAS_SIZE, COLOR_TOP, COLOR_BOTTOM)
    mask = make_squircle_mask(CANVAS_SIZE, ICON_BODY_SIZE, SQUIRCLE_EXPONENT, SUPERSAMPLE)

    # Apply squircle mask — transparent outside
    gradient.putalpha(mask)

    # Scale butt art to fit within the icon body
    butt_target = int(ICON_BODY_SIZE * BUTT_SCALE)
    butt_scaled = butt_art.resize((butt_target, butt_target), Image.LANCZOS)

    # Center on canvas
    offset = (CANVAS_SIZE - butt_target) // 2

    master = gradient.copy()
    master.paste(butt_scaled, (offset, offset), butt_scaled)
    return master


# -- Main -------------------------------------------------------------------

def main():
    print(f"Generating app icon from {GIF_PATH.name}...")

    butt_art = extract_butt_art(GIF_PATH)
    butt_target = int(ICON_BODY_SIZE * BUTT_SCALE)
    print(
        f"  Master: {CANVAS_SIZE}x{CANVAS_SIZE} "
        f"(squircle {ICON_BODY_SIZE}px, butt {butt_target}px, "
        f"gradient #{COLOR_TOP[0]:02X}{COLOR_TOP[1]:02X}{COLOR_TOP[2]:02X}"
        f"->#{COLOR_BOTTOM[0]:02X}{COLOR_BOTTOM[1]:02X}{COLOR_BOTTOM[2]:02X})"
    )

    master = build_master_icon(butt_art)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename, px in OUTPUT_SIZES:
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(OUTPUT_DIR / filename, "PNG")
        print(f"  {filename:25s} {px:4d}px")

    print(f"\nDone: {len(OUTPUT_SIZES)} icons written to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()

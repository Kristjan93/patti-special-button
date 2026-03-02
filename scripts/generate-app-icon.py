#!/usr/bin/env python3
"""Generate the macOS app icon for pattiSpecialButton.

Creates a bold squircle icon with a solid coral background and white butt
outlines. High contrast, reads at any size.
Outputs all 10 required PNG sizes for the Xcode asset catalog.

Usage:
    cd scripts/
    uv run generate-app-icon.py
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

# Solid coral background
BG_COLOR = (255, 107, 107)      # #FF6B6B — bold coral

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


def make_solid_bg(size: int, color: tuple) -> Image.Image:
    """Create a solid-color RGBA background."""
    return Image.new("RGBA", (size, size), (*color, 255))


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
    """Compose the 1024x1024 master icon.

    Butt outlines are recolored to white and layered directly on coral.
    """
    bg = make_solid_bg(CANVAS_SIZE, BG_COLOR)
    mask = make_squircle_mask(CANVAS_SIZE, ICON_BODY_SIZE, SQUIRCLE_EXPONENT, SUPERSAMPLE)

    # Apply squircle mask — transparent outside
    bg.putalpha(mask)

    # Scale butt art to fit within the icon body
    butt_target = int(ICON_BODY_SIZE * BUTT_SCALE)
    butt_scaled = butt_art.resize((butt_target, butt_target), Image.LANCZOS)

    # Recolor outlines from black to white, preserving alpha
    r, g, b, a = butt_scaled.split()
    white_channel = Image.new("L", butt_scaled.size, 255)
    butt_white = Image.merge("RGBA", (white_channel, white_channel, white_channel, a))

    # Center on canvas
    offset = (CANVAS_SIZE - butt_target) // 2

    master = bg.copy()
    master.paste(butt_white, (offset, offset), butt_white)
    return master


# -- Main -------------------------------------------------------------------

def main():
    print(f"Generating app icon from {GIF_PATH.name}...")

    butt_art = extract_butt_art(GIF_PATH)
    butt_target = int(ICON_BODY_SIZE * BUTT_SCALE)
    print(
        f"  Master: {CANVAS_SIZE}x{CANVAS_SIZE} "
        f"(squircle {ICON_BODY_SIZE}px, butt {butt_target}px, "
        f"bg #{BG_COLOR[0]:02X}{BG_COLOR[1]:02X}{BG_COLOR[2]:02X})"
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

#!/usr/bin/env python3
"""Extract, convert, and resize animated GIF frames for the app.

Scans the buttsss/ directory for .gif files, extracts each frame,
converts to RGBA (black outlines with alpha-based transparency),
resizes to 160x160 pixels, and saves as PNGs organized into per-butt
subfolders with a manifest.json. The 160px frames serve both the menu
bar (downscaled to icon size setting) and the picker grid (displayed
at 80pt @2x).

Usage:
    cd buttsss/
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    python3 brazilian-butt-lift.py
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageOps

# -- Configuration ----------------------------------------------------------

FRAME_SIZE = (160, 160)
RESAMPLE = Image.LANCZOS

SCRIPT_DIR = Path(__file__).resolve().parent
GIF_DIR = SCRIPT_DIR / "fractured-but-whole"
OUTPUT_DIR = SCRIPT_DIR.parent / "ButtFrames"


# -- Helpers ----------------------------------------------------------------

def slugify(name: str) -> str:
    """Turn a GIF filename into a clean identifier.

    'Alien-Butt.gif' -> 'alien-butt'
    'bouncing-butt-II.gif' -> 'bouncing-butt-ii'
    """
    stem = Path(name).stem
    slug = stem.lower()
    slug = re.sub(r"[_ ]+", "-", slug)
    slug = re.sub(r"[^a-z0-9\-]", "", slug)
    slug = re.sub(r"-{2,}", "-", slug).strip("-")
    return slug


def display_name(name: str) -> str:
    """Turn a GIF filename into a consistent title-case display name.

    'Alien-Butt.gif' -> 'Alien Butt'
    'bouncing-butt-II.gif' -> 'Bouncing Butt II'
    'easterBunny.gif' -> 'Easter Bunny'
    """
    stem = Path(name).stem
    # Split camelCase boundaries before normalizing separators
    spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", stem)
    spaced = re.sub(r"[-_]+", " ", spaced).strip()
    # Capitalize first letter of each word, preserve the rest (keeps "II" intact)
    return " ".join(w[0].upper() + w[1:] for w in spaced.split() if w)


def extract_frames(gif_path: Path) -> tuple[list[Image.Image], list[int]]:
    """Extract all frames and per-frame delays from an animated GIF."""
    img = Image.open(gif_path)
    frames = []
    delays = []

    # Build a canvas to composite frames onto (handles disposal methods)
    canvas = Image.new("RGBA", img.size, (255, 255, 255, 255))

    for i in range(getattr(img, "n_frames", 1)):
        img.seek(i)
        # GIF stores per-frame delay in the Graphic Control Extension block.
        # Pillow exposes it via img.info['duration'] after each seek().
        delay = img.info.get("duration", 100)
        if delay < 10:
            delay = 100
        delays.append(delay)
        frame = img.convert("RGBA")
        canvas.paste(frame, (0, 0), frame)
        frames.append(canvas.copy())

    return frames, delays


def process_frame(frame: Image.Image) -> Image.Image:
    """Convert a single RGBA frame to an RGBA outline image.

    Pipeline:
      1. Convert to grayscale (luminance)
      2. Resize to 160x160
      3. Invert grayscale → alpha, RGB = black
         Dark lines become opaque black, white background becomes transparent.
    """
    grayscale = frame.convert("L")
    resized_gray = grayscale.resize(FRAME_SIZE, resample=RESAMPLE)

    # Resize before alpha conversion to avoid blending artifacts in Lanczos.
    inverted = ImageOps.invert(resized_gray)
    black = Image.new("L", FRAME_SIZE, 0)
    return Image.merge("RGBA", (black, black, black, inverted))


# -- Main -------------------------------------------------------------------

def process_gif(gif_path: Path) -> dict | None:
    """Process a single GIF and return its manifest entry, or None on error."""
    slug = slugify(gif_path.name)
    name = display_name(gif_path.name)
    out_dir = OUTPUT_DIR / slug

    try:
        frames, delays = extract_frames(gif_path)
    except Exception as e:
        print(f"  ERROR extracting {gif_path.name}: {e}", file=sys.stderr)
        return None

    if len(frames) <= 1:
        print(f"  WARNING: {gif_path.name} has only {len(frames)} frame(s) — will not animate", file=sys.stderr)

    out_dir.mkdir(parents=True, exist_ok=True)

    for i, frame in enumerate(frames):
        rgba = process_frame(frame)
        rgba.save(out_dir / f"frame_{i:02d}.png", "PNG")

    return {"id": slug, "name": name, "frameCount": len(frames), "frameDelays": delays}


def main():
    gif_files = sorted(GIF_DIR.glob("*.gif"))

    if not gif_files:
        print(f"No .gif files found in {GIF_DIR}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(gif_files)} GIFs in {GIF_DIR}")

    # Clean output directory
    if OUTPUT_DIR.exists():
        import shutil
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    manifest_entries = []

    for gif_path in gif_files:
        entry = process_gif(gif_path)
        if entry:
            manifest_entries.append(entry)
            print(f"  {entry['id']:30s}  {entry['frameCount']:3d} frames")

    # Sort manifest alphabetically by id
    manifest_entries.sort(key=lambda e: e["id"])

    manifest = {"butts": manifest_entries}
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    total_frames = sum(e["frameCount"] for e in manifest_entries)
    print(f"\nDone: {len(manifest_entries)} butts, {total_frames} frames")
    print(f"Output: {OUTPUT_DIR}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Extract, convert, and resize animated GIF frames for the menu bar icon.

Scans the buttsss/ directory for .gif files, extracts each frame,
converts to grayscale, resizes to 40x40 pixels, and saves as PNGs
organized into per-butt folders with a manifest.json.

Usage:
    cd buttsss/
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    python3 prepare_frames.py
"""

import json
import re
import sys
from pathlib import Path

from PIL import Image

# -- Configuration ----------------------------------------------------------

FRAME_SIZE = (40, 40)
RESAMPLE = Image.LANCZOS

SCRIPT_DIR = Path(__file__).resolve().parent
GIF_DIR = SCRIPT_DIR  # GIFs live alongside this script
OUTPUT_DIR = SCRIPT_DIR.parent / "pattiSpecialButton" / "ButtFrames"


# -- Helpers ----------------------------------------------------------------

def slugify(name: str) -> str:
    """Turn a GIF filename into a clean folder name.

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
    """Turn a GIF filename into a human-readable display name.

    'Alien-Butt.gif' -> 'Alien Butt'
    'bouncing-butt-II.gif' -> 'Bouncing Butt II'
    """
    stem = Path(name).stem
    return re.sub(r"[-_]+", " ", stem).strip()


def extract_frames(gif_path: Path) -> list[Image.Image]:
    """Extract all frames from an animated GIF, handling disposal correctly."""
    img = Image.open(gif_path)
    frames = []

    # Build a canvas to composite frames onto (handles disposal methods)
    canvas = Image.new("RGBA", img.size, (255, 255, 255, 255))

    for i in range(getattr(img, "n_frames", 1)):
        img.seek(i)
        frame = img.convert("RGBA")
        canvas.paste(frame, (0, 0), frame)
        frames.append(canvas.copy())

    return frames


def process_frame(frame: Image.Image) -> Image.Image:
    """Convert a single RGBA frame to a grayscale 40x40 template image.

    Pipeline:
      1. Convert to grayscale (luminance)
      2. Resize to 40x40
      --- TODO: future step ---
      3. Convert to RGBA with alpha-based transparency
         (dark lines -> opaque black, white background -> alpha=0)
         This will give more precise template rendering.
    """
    grayscale = frame.convert("L")

    # TODO: Add alpha-based template conversion here.
    # When enabled, this will:
    #   - Invert grayscale so dark=high, light=low
    #   - Use inverted values as the alpha channel
    #   - Set RGB to (0, 0, 0) for all pixels
    #   - Result: dark lines become opaque black, white becomes transparent
    # For now, grayscale + isTemplate=true in Swift handles rendering.

    resized = grayscale.resize(FRAME_SIZE, resample=RESAMPLE)
    return resized


# -- Main -------------------------------------------------------------------

def process_gif(gif_path: Path) -> dict | None:
    """Process a single GIF and return its manifest entry, or None on error."""
    slug = slugify(gif_path.name)
    name = display_name(gif_path.name)
    out_dir = OUTPUT_DIR / slug

    try:
        frames = extract_frames(gif_path)
    except Exception as e:
        print(f"  ERROR extracting {gif_path.name}: {e}", file=sys.stderr)
        return None

    out_dir.mkdir(parents=True, exist_ok=True)

    for i, frame in enumerate(frames):
        processed = process_frame(frame)
        out_path = out_dir / f"frame_{i:02d}.png"
        processed.save(out_path, "PNG")

    return {"id": slug, "name": name, "frameCount": len(frames)}


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

#!/usr/bin/env python3
"""Manage sound assets for the app.

Scans the sounds/ directory for audio files, converts unsupported formats
(FLAC, OGG, etc.) to WAV, and generates/updates sounds-manifest.json.
Existing manifest entries (names, categories) are preserved — only new
files get auto-generated defaults.

Supported formats (playable by AVAudioPlayer on macOS 12+):
  .wav, .mp3, .m4a, .aiff

Unsupported formats that will be converted to .wav:
  .flac, .ogg, .wma, .opus

Usage:
    cd buttsss/
    python3 sound-check.py            # scan, convert, update manifest
    python3 sound-check.py --dry-run  # show what would happen without changes
"""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

# -- Configuration ----------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
SOUNDS_DIR = SCRIPT_DIR.parent / "sounds"
MANIFEST_PATH = SOUNDS_DIR / "sounds-manifest.json"

SUPPORTED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".aiff"}
CONVERTIBLE_EXTENSIONS = {".flac", ".ogg", ".wma", ".opus"}
ALL_AUDIO_EXTENSIONS = SUPPORTED_EXTENSIONS | CONVERTIBLE_EXTENSIONS

DEFAULT_CATEGORY = "uncategorized"


# -- Helpers ----------------------------------------------------------------

def slugify(filename: str) -> str:
    """Turn an audio filename into a clean identifier.

    '326143__mackaffee__fart.mp3' -> '326143-mackaffee-fart'
    'dramatic-fart_f8Sw6fv.mp3'  -> 'dramatic-fart-f8sw6fv'
    """
    stem = Path(filename).stem
    slug = stem.lower()
    slug = re.sub(r"[_ ]+", "-", slug)
    slug = re.sub(r"[^a-z0-9\-]", "", slug)
    slug = re.sub(r"-{2,}", "-", slug).strip("-")
    return slug


def display_name(filename: str) -> str:
    """Generate a readable display name from a filename.

    '326143__mackaffee__fart.mp3' -> '326143 Mackaffee Fart'
    'dramatic-fart_f8Sw6fv.mp3'  -> 'Dramatic Fart F8Sw6fv'
    """
    stem = Path(filename).stem
    spaced = re.sub(r"([a-z])([A-Z])", r"\1 \2", stem)
    spaced = re.sub(r"[-_]+", " ", spaced).strip()
    return " ".join(w[0].upper() + w[1:] for w in spaced.split() if w)


def has_ffmpeg() -> bool:
    """Check if ffmpeg is available."""
    try:
        subprocess.run(["ffmpeg", "-version"], capture_output=True, check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def convert_to_wav(source: Path) -> Path:
    """Convert an unsupported audio file to WAV using ffmpeg."""
    target = source.with_suffix(".wav")
    print(f"  Converting {source.name} -> {target.name}")
    result = subprocess.run(
        ["ffmpeg", "-y", "-i", str(source), str(target)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"  ERROR converting {source.name}: {result.stderr}", file=sys.stderr)
        return source
    # Remove the original unsupported file
    source.unlink()
    print(f"  Removed original {source.name}")
    return target


def load_manifest() -> list[dict]:
    """Load existing manifest, or return empty list."""
    if MANIFEST_PATH.exists():
        try:
            return json.loads(MANIFEST_PATH.read_text())
        except (json.JSONDecodeError, ValueError):
            print("  WARNING: Could not parse existing manifest, starting fresh",
                  file=sys.stderr)
    return []


def scan_audio_files() -> list[Path]:
    """Find all audio files in the sounds directory."""
    files = []
    for f in sorted(SOUNDS_DIR.iterdir()):
        if f.is_file() and f.suffix.lower() in ALL_AUDIO_EXTENSIONS:
            files.append(f)
    return files


# -- Main -------------------------------------------------------------------

def main():
    dry_run = "--dry-run" in sys.argv

    if not SOUNDS_DIR.exists():
        print(f"Sounds directory not found: {SOUNDS_DIR}", file=sys.stderr)
        sys.exit(1)

    # Step 1: Find audio files
    audio_files = scan_audio_files()
    print(f"Found {len(audio_files)} audio file(s) in {SOUNDS_DIR}")

    if not audio_files:
        print("Nothing to do.")
        return

    # Step 2: Convert unsupported formats
    needs_conversion = [f for f in audio_files if f.suffix.lower() in CONVERTIBLE_EXTENSIONS]
    if needs_conversion:
        if not has_ffmpeg():
            print("ERROR: ffmpeg is required to convert unsupported formats.", file=sys.stderr)
            print("  Install with: brew install ffmpeg", file=sys.stderr)
            sys.exit(1)

        print(f"\n{len(needs_conversion)} file(s) need conversion:")
        for f in needs_conversion:
            if dry_run:
                print(f"  [dry-run] Would convert {f.name} -> {f.stem}.wav")
            else:
                convert_to_wav(f)

    # Re-scan after conversions
    if not dry_run:
        audio_files = scan_audio_files()

    # Step 3: Load existing manifest and build lookup by filename
    existing = load_manifest()
    # Key by "file.ext" so we can match existing entries to files on disk
    existing_by_file = {}
    for entry in existing:
        key = f"{entry['file']}.{entry['ext']}"
        existing_by_file[key] = entry

    # Step 4: Build new manifest
    manifest = []
    new_count = 0

    for audio_path in audio_files:
        if audio_path.name == "sounds-manifest.json":
            continue

        filename = audio_path.stem
        ext = audio_path.suffix.lstrip(".")
        file_key = f"{filename}.{ext}"

        if file_key in existing_by_file:
            # Preserve existing entry (user's custom name, category, etc.)
            manifest.append(existing_by_file[file_key])
        else:
            # New file — generate defaults
            entry = {
                "id": slugify(audio_path.name),
                "name": display_name(audio_path.name),
                "category": DEFAULT_CATEGORY,
                "file": filename,
                "ext": ext,
            }
            manifest.append(entry)
            new_count += 1
            if dry_run:
                print(f"  [dry-run] Would add: {entry['id']} ({file_key})")

    # Sort by category then id
    manifest.sort(key=lambda e: (e["category"].lower(), e["id"]))

    # Step 5: Check for removed files (in manifest but not on disk)
    current_files = {f"{e['file']}.{e['ext']}" for e in manifest}
    removed = [e for e in existing if f"{e['file']}.{e['ext']}" not in current_files]
    if removed:
        print(f"\n{len(removed)} file(s) no longer on disk (removed from manifest):")
        for e in removed:
            print(f"  {e['id']} ({e['file']}.{e['ext']})")

    # Step 6: Write manifest
    if dry_run:
        print(f"\n[dry-run] Would write manifest with {len(manifest)} entries "
              f"({new_count} new)")
    else:
        MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"\nManifest written: {len(manifest)} sounds ({new_count} new)")

    # Summary
    print(f"\n{'=' * 50}")
    categories = {}
    for e in manifest:
        cat = e["category"]
        categories[cat] = categories.get(cat, 0) + 1

    for cat in sorted(categories):
        print(f"  {cat}: {categories[cat]} sounds")

    print(f"  {'─' * 30}")
    print(f"  Total: {len(manifest)} sounds")

    if new_count > 0:
        print(f"\n  {new_count} new sound(s) added with category '{DEFAULT_CATEGORY}'.")
        print("  Edit sounds-manifest.json to set names and categories.")


if __name__ == "__main__":
    main()

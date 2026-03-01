#!/usr/bin/env python3
"""Manage sound assets for the app.

Scans the sounds/ directory for audio files, converts unsupported formats
(FLAC, OGG, etc.) to WAV, splits shuffle_* files into segments, computes
waveform data for all sounds, and generates/updates sounds-manifest.json.
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

from shuffle_segments import split_segments
from waveform_samples import compute_waveform

# -- Configuration ----------------------------------------------------------

SCRIPT_DIR = Path(__file__).resolve().parent
SOUNDS_DIR = SCRIPT_DIR.parent / "sounds"
MANIFEST_PATH = SOUNDS_DIR / "sounds-manifest.json"

SUPPORTED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".aiff"}
CONVERTIBLE_EXTENSIONS = {".flac", ".ogg", ".wma", ".opus"}
ALL_AUDIO_EXTENSIONS = SUPPORTED_EXTENSIONS | CONVERTIBLE_EXTENSIONS

DEFAULT_CATEGORY = "uncategorized"
SHUFFLE_PREFIX = "shuffle_"
SHUFFLE_SOURCES_DIR = SCRIPT_DIR / "shuffle-sources"

# Segment files: shuffle_<name>_NN.ext (two trailing digits after last underscore)
SEGMENT_PATTERN = re.compile(r"^shuffle_.+_\d{2}$")


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


def is_segment_file(path: Path) -> bool:
    """True if the file is a shuffle segment (shuffle_<name>_NN.ext)."""
    return bool(SEGMENT_PATTERN.match(path.stem))


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

    # Step 3: Identify shuffle source files (not segments) and split
    # Shuffle sources: shuffle_<name>.ext, NOT matching shuffle_<name>_NN.ext
    shuffle_sources = [
        f for f in audio_files
        if f.stem.startswith(SHUFFLE_PREFIX) and not is_segment_file(f)
    ]
    # Map from the original name (without shuffle_ prefix) to waveform + segments
    shuffle_data: dict[str, dict] = {}

    if shuffle_sources:
        print(f"\n{len(shuffle_sources)} shuffle source file(s) found:")
        for sf in shuffle_sources:
            print(f"  {sf.name}")
            # The "raw name" is the filename without the shuffle_ prefix
            raw_name = sf.stem[len(SHUFFLE_PREFIX):]

            if dry_run:
                print(f"  [dry-run] Would compute waveform and split {sf.name}")
                continue

            # Compute waveform from the original BEFORE splitting
            waveform = compute_waveform(sf)
            print(f"  Computed waveform ({len(waveform)} bars)")

            # Split into segments
            segments = split_segments(sf, SOUNDS_DIR, raw_name)
            print(f"  Split into {len(segments)} segment(s)")

            shuffle_data[raw_name] = {
                "waveform": waveform,
                "segments": segments,
                "original_ext": sf.suffix.lstrip("."),
            }

            # Move original to shuffle-sources/
            SHUFFLE_SOURCES_DIR.mkdir(parents=True, exist_ok=True)
            dest = SHUFFLE_SOURCES_DIR / sf.name
            shutil.move(str(sf), str(dest))
            print(f"  Moved original to {dest.relative_to(SCRIPT_DIR.parent)}")

    # Re-scan after splitting (now has segments, not originals)
    if not dry_run:
        audio_files = scan_audio_files()

    # Step 4: Load existing manifest and build lookups
    existing = load_manifest()
    # Key by "file.ext" for regular sounds (those with file/ext fields)
    existing_by_file: dict[str, dict] = {}
    existing_by_id: dict[str, dict] = {}
    for entry in existing:
        if entry.get("file") and entry.get("ext"):
            key = f"{entry['file']}.{entry['ext']}"
            existing_by_file[key] = entry
        existing_by_id[entry["id"]] = entry

    # Step 5: Build new manifest
    manifest = []
    new_count = 0

    # Collect all segment filenames to exclude from regular entries
    segment_filenames: set[str] = set()
    for f in audio_files:
        if is_segment_file(f):
            segment_filenames.add(f.name)

    # 5a: Add entries for newly-split shuffle sounds
    for raw_name, data in shuffle_data.items():
        original_ext = data["original_ext"]
        # Look up the pre-existing manifest entry by the original filename
        # (before it was renamed to shuffle_*)
        prev = (
            existing_by_file.get(f"{raw_name}.{original_ext}")
            or existing_by_file.get(f"{raw_name}.wav")
            or existing_by_file.get(f"{raw_name}.mp3")
        )

        segments_list = []
        for seg_path in data["segments"]:
            seg_waveform = compute_waveform(seg_path)
            segments_list.append({
                "file": seg_path.stem,
                "ext": seg_path.suffix.lstrip("."),
                "waveform": seg_waveform,
            })

        entry = {
            "id": prev["id"] if prev else slugify(raw_name),
            "name": prev["name"] if prev else display_name(raw_name),
            "category": prev["category"] if prev else DEFAULT_CATEGORY,
            "shuffle": True,
            "source": f"{raw_name}.{original_ext}",
            "waveform": data["waveform"],
            "segments": segments_list,
        }
        manifest.append(entry)
        if not prev:
            new_count += 1

    # 5b: Carry forward existing shuffle entries that weren't re-processed
    new_shuffle_ids = {e["id"] for e in manifest}
    for entry in existing:
        if entry.get("shuffle") and entry["id"] not in new_shuffle_ids:
            # Backfill per-segment waveforms for entries that lack them
            if entry.get("segments"):
                for seg in entry["segments"]:
                    if "waveform" not in seg:
                        seg_path = SOUNDS_DIR / f"{seg['file']}.{seg['ext']}"
                        if seg_path.exists() and not dry_run:
                            seg["waveform"] = compute_waveform(seg_path)
            manifest.append(entry)

    # 5c: Add regular (non-shuffle, non-segment) audio files
    for audio_path in audio_files:
        if audio_path.name == "sounds-manifest.json":
            continue
        if audio_path.name in segment_filenames:
            continue
        if audio_path.stem.startswith(SHUFFLE_PREFIX):
            continue

        filename = audio_path.stem
        ext = audio_path.suffix.lstrip(".")
        file_key = f"{filename}.{ext}"

        if file_key in existing_by_file:
            entry = dict(existing_by_file[file_key])
        else:
            entry = {
                "id": slugify(audio_path.name),
                "name": display_name(audio_path.name),
                "category": DEFAULT_CATEGORY,
                "file": filename,
                "ext": ext,
            }
            new_count += 1
            if dry_run:
                print(f"  [dry-run] Would add: {entry['id']} ({file_key})")

        # Compute waveform for regular sounds
        if not dry_run:
            entry["waveform"] = compute_waveform(audio_path)

        manifest.append(entry)

    # Sort by category then id
    manifest.sort(key=lambda e: (e["category"].lower(), e["id"]))

    # Step 6: Check for removed entries
    current_ids = {e["id"] for e in manifest}
    removed = [e for e in existing if e["id"] not in current_ids]
    if removed:
        print(f"\n{len(removed)} entry/entries no longer on disk (removed from manifest):")
        for e in removed:
            print(f"  {e['id']}")

    # Step 7: Write manifest
    if dry_run:
        print(f"\n[dry-run] Would write manifest with {len(manifest)} entries "
              f"({new_count} new)")
    else:
        MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"\nManifest written: {len(manifest)} sounds ({new_count} new)")

    # Summary
    print(f"\n{'=' * 50}")
    categories: dict[str, int] = {}
    shuffle_count = 0
    for e in manifest:
        cat = e["category"]
        categories[cat] = categories.get(cat, 0) + 1
        if e.get("shuffle"):
            shuffle_count += 1

    for cat in sorted(categories):
        print(f"  {cat}: {categories[cat]} sounds")

    print(f"  {'─' * 30}")
    print(f"  Total: {len(manifest)} sounds ({shuffle_count} shuffle)")

    if new_count > 0:
        print(f"\n  {new_count} new sound(s) added with category '{DEFAULT_CATEGORY}'.")
        print("  Edit sounds-manifest.json to set names and categories.")


if __name__ == "__main__":
    main()

# scripts

Asset pipeline scripts for pattiSpecialButton.

- **brazilian-butt-lift.py** — Converts animated GIF butts into menu-bar-ready PNG frames
- **sound-check.py** — Manages sound assets: converts formats, splits shuffle sounds into segments, computes waveforms, generates manifest

## Credits

The butt illustrations are by [**Pablo Stanley**](https://twitter.com/pablostanley), from his project [buttsss.com](https://www.buttsss.com/). Licensed under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) -- free for personal and commercial use with attribution.

Thank you Pablo for knowing what it's all about.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) (`brew install uv`)
- ffmpeg (for sound-check.py: `brew install ffmpeg`)

## Setup

```bash
cd scripts/
uv sync
```

## Butt Pipeline

Extracts frames from animated GIFs, converts to RGBA PNGs (black outlines with alpha transparency), resizes to 160x160, and writes a manifest.

```bash
uv run brazilian-butt-lift.py
```

### What it does

```
fractured-but-whole/             ButtFrames/
                                 (Xcode folder reference)
  Alien-Butt.gif ──────────────> alien-butt/
    512x512, RGB, 17 frames        frame_00.png  160x160, RGBA
                                   frame_01.png
                                   ...
                                   frame_16.png

                                 manifest.json

  brazilian-butt-lift.py
  performs the transform:

  1. Extract ─── Pull each frame from the animated GIF
  2. RGBA ────── Convert to black outlines with alpha transparency
  3. Resize ──── Scale from 512x512 down to 160x160 (LANCZOS)
  4. Save ────── Write as PNG into named subfolder
```

### Adding a new butt

1. Drop the GIF into `fractured-but-whole/`
2. Run `uv run brazilian-butt-lift.py`
3. Build the app in Xcode

The GIF should be 512x512 with black line art on a white background for best results.

### Butt manifest format

`ButtFrames/manifest.json`:

```json
{
  "butts": [
    { "id": "alien-butt", "name": "Alien Butt", "frameCount": 16, "frameDelays": [100, ...] }
  ]
}
```

## Sound Pipeline

Scans the `sounds/` directory, converts unsupported formats to WAV, splits shuffle sounds into segments, computes waveform data for all sounds, and generates/updates `sounds-manifest.json`. Existing entries (names, categories) are preserved — only new files get auto-generated defaults.

```bash
uv run sound-check.py            # scan, convert, update manifest
uv run sound-check.py --dry-run  # preview changes without modifying anything
```

Supported formats (playable by AVAudioPlayer on macOS 12+): `.wav`, `.mp3`, `.m4a`, `.aiff`

Unsupported formats (auto-converted to .wav): `.flac`, `.ogg`, `.wma`, `.opus`

### Adding a new sound

1. Drop the audio file into `sounds/`
2. Run `uv run sound-check.py`
3. Edit `sounds/sounds-manifest.json` to set the name and category
4. Build the app in Xcode

### Shuffle sounds

Some sound files contain multiple distinct events (e.g. several farts in one recording). Prefixing a file with `shuffle_` tells the pipeline to split it into individual segments at silence boundaries. The app then plays one random segment per click in round-robin order (all segments heard before any repeat).

To make a sound shuffleable:

1. Rename it with a `shuffle_` prefix: `shuffle_my-sound.wav`
2. Run `uv run sound-check.py`

The pipeline will:
- Compute a waveform from the original file
- Split it into segments (`shuffle_my-sound_00.wav`, `_01.wav`, ...) in `sounds/`
- Move the original to `scripts/shuffle-sources/` for safekeeping
- Add a manifest entry with `"shuffle": true` and a `"segments"` array

Modules: `shuffle_segments.py` (silence detection + splitting), `waveform_samples.py` (amplitude bar computation).

### Sound manifest format

`sounds/sounds-manifest.json`:

```json
[
  { "id": "dry-fart", "name": "Dry Toot", "category": "farts", "file": "dry-fart", "ext": "mp3",
    "waveform": [0.0, 0.55, 0.94, ...] },
  { "id": "spanking", "name": "Spanking", "category": "novelty", "shuffle": true,
    "source": "204805__ezcah__spanking.wav",
    "waveform": [0.0, 0.29, ...],
    "segments": [
      { "file": "shuffle_spanking_00", "ext": "wav", "waveform": [0.12, 0.45, ...] }, ...
    ] }
]
```

## Directory layout

```
scripts/
  README.md                  <- you are here
  brazilian-butt-lift.py     <- butt frame extractor
  sound-check.py             <- sound asset manager
  waveform_samples.py        <- waveform amplitude computation
  shuffle_segments.py        <- silence-based audio splitting
  pyproject.toml             <- dependencies (Pillow, pydub)
  uv.lock                    <- pinned dependency versions
  .python-version            <- Python 3.12 (managed by uv)
  .venv/                     <- virtual environment (gitignored)
  fractured-but-whole/       <- source GIFs
    Alien-Butt.gif
    ...47 GIFs
  shuffle-sources/           <- original shuffle files (before splitting)
```

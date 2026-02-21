# scripts

Asset pipeline scripts for pattiSpecialButton.

- **brazilian-butt-lift.py** — Converts animated GIF butts into menu-bar-ready PNG frames
- **sound-check.py** — Manages sound assets: converts unsupported formats, generates manifest

## Credits

The butt illustrations are by [**Pablo Stanley**](https://twitter.com/pablostanley), from his project [buttsss.com](https://www.buttsss.com/). Licensed under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) -- free for personal and commercial use with attribution.

Thank you Pablo for knowing what it's all about.

## Prerequisites

- Python 3.12+ (managed via pyenv)
- pip
- ffmpeg (for sound-check.py: `brew install ffmpeg`)

## Setup

```bash
cd scripts/
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Butt Pipeline

Extracts frames from animated GIFs, converts to RGBA PNGs (black outlines with alpha transparency), resizes to 160x160, and writes a manifest.

```bash
source .venv/bin/activate
python3 brazilian-butt-lift.py
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
2. Run `python3 brazilian-butt-lift.py`
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

Scans the `sounds/` directory, converts unsupported formats to WAV, and generates/updates `sounds-manifest.json`. Existing entries (names, categories) are preserved — only new files get auto-generated defaults.

```bash
python3 sound-check.py            # scan, convert, update manifest
python3 sound-check.py --dry-run  # preview changes without modifying anything
```

Supported formats (playable by AVAudioPlayer on macOS 12+): `.wav`, `.mp3`, `.m4a`, `.aiff`

Unsupported formats (auto-converted to .wav): `.flac`, `.ogg`, `.wma`, `.opus`

### Adding a new sound

1. Drop the audio file into `sounds/`
2. Run `python3 sound-check.py`
3. Edit `sounds/sounds-manifest.json` to set the name and category
4. Build the app in Xcode

### Sound manifest format

`sounds/sounds-manifest.json`:

```json
[
  { "id": "dry-fart", "name": "Dry Toot", "category": "farts", "file": "dry-fart", "ext": "mp3" }
]
```

## Directory layout

```
scripts/
  README.md                  <- you are here
  brazilian-butt-lift.py     <- butt frame extractor
  sound-check.py             <- sound asset manager
  requirements.txt           <- Pillow (for butt script)
  .python-version            <- pyenv (3.12.8)
  .venv/                     <- virtual environment (gitignored)
  fractured-but-whole/       <- source GIFs
    Alien-Butt.gif
    ...47 GIFs
```

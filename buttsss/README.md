# buttsss

Asset pipeline for pattiSpecialButton. Takes animated GIF butts and produces menu-bar-ready PNG frames.

## Credits

The butt illustrations are by [**Pablo Stanley**](https://twitter.com/pablostanley), from his project [buttsss.com](https://www.buttsss.com/). Licensed under [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) -- free for personal and commercial use with attribution.

Thank you Pablo for knowing what it's all about.

## Prerequisites

- Python 3.12+ (managed via pyenv)
- pip

## Setup

```bash
cd buttsss/
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
source .venv/bin/activate
python3 brazilian-butt-lift.py
```

Output:

```
Found 47 GIFs in /path/to/buttsss/fractured-but-whole
  alien-butt                       16 frames
  async-butt                        6 frames
  pirate-butt                      20 frames
  ...

Done: 47 butts, 457 frames
Output: /path/to/ButtFrames
Manifest: /path/to/ButtFrames/manifest.json
```

## What it does

```
fractured-but-whole/             ButtFrames/
                                 (Xcode folder reference)
  Alien-Butt.gif ──────────────> alien-butt/
    512x512, RGB, 17 frames        frame_00.png  40x40, grayscale
                                   frame_01.png
    ┌───────────────────┐          ...
    │                   │          frame_16.png
    │   ╭──╮ ╭──╮      │
    │   │  ╰─╯  │      │        async-butt/
    │   │       │      │          frame_00.png
    │   ╰──┬──┬──╯      │        ...
    │      │  │         │
    │                   │        manifest.json
    └───────────────────┘
         512x512                     40x40

  brazilian-butt-lift.py
  performs the transform:

  1. Extract ─── Pull each frame from the animated GIF
  2. Grayscale ─ Convert RGB to single-channel luminance
  3. Resize ──── Scale from 512x512 down to 40x40 (LANCZOS)
  4. Save ────── Write as PNG into named subfolder
```

## Why grayscale?

macOS menu bar icons use **template rendering** (`isTemplate = true` in Swift). The system reads the grayscale values directly: dark pixels render in the menu bar tint, white pixels are invisible. No alpha channel manipulation needed.

```
GIF frame (RGB)          After transform (Grayscale)       In menu bar

  ┌──────────┐             ┌──────────┐                  Dark mode: white lines
  │ black    │             │ dark     │ ─── visible ──>  Light mode: black lines
  │ lines on │  ────────>  │ pixels = │                  (system handles tinting
  │ white bg │             │ visible  │                   automatically)
  └──────────┘             └──────────┘
```

## Adding a new butt

1. Drop the GIF into `fractured-but-whole/`
2. Run `python3 brazilian-butt-lift.py`
3. Build the app in Xcode

The GIF should be 512x512 with black line art on a white background for best results.

## Manifest format

`ButtFrames/manifest.json` lists every available butt for the Swift app:

```json
{
  "butts": [
    { "id": "alien-butt", "name": "Alien Butt", "frameCount": 16 },
    { "id": "async-butt", "name": "async butt", "frameCount": 6 },
    ...
  ]
}
```

## Directory layout

```
buttsss/
  README.md                  <- you are here
  brazilian-butt-lift.py     <- the script
  requirements.txt           <- Pillow
  .python-version            <- pyenv (3.12.8)
  .venv/                     <- virtual environment (gitignored)
  fractured-but-whole/       <- source GIFs
    Alien-Butt.gif
    async-butt.gif
    ...47 GIFs
```

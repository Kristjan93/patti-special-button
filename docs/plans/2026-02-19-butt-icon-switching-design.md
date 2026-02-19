# Butt Icon Switching — Design

## Goal

Allow users to choose from 47 different animated butt icons for the menu bar, replacing the single hardcoded async-butt.

## Approach: Pre-processed PNG Folders (Approach C)

A Python script extracts frames from source GIFs, converts to grayscale, resizes to 40x40, and outputs organized PNG folders. These are bundled in the app as folder references and loaded at runtime.

## Python Script (`buttsss/prepare_frames.py`)

**Pipeline per frame:**
1. Extract frame from GIF (Pillow, handling disposal)
2. Convert to grayscale (single-channel luminance)
3. *(Future)* Convert to alpha-based template (white → transparent, dark → opaque)
4. Resize to 40x40 with LANCZOS resampling
5. Save as PNG

**Output structure:**
```
pattiSpecialButton/ButtFrames/
  manifest.json
  alien-butt/
    frame_00.png ... frame_16.png
  async-butt/
    frame_00.png ... frame_05.png
  ...47 folders, ~500 PNGs
```

**manifest.json** lists all butts with id, display name, and frame count so Swift doesn't need to scan directories.

**Setup:** pyenv + venv + requirements.txt (Pillow).

## Swift Integration (Future)

- Add `ButtFrames/` as a folder reference in Xcode
- Read `manifest.json` at launch to discover available butts
- Load selected butt's frames from `Bundle.main.url(forResource:...)`
- Set `isTemplate = true` (same as today — grayscale images work natively)
- Right-click menu gets "Choose Butt" submenu built from manifest
- Persist selection with `UserDefaults`

## Why grayscale works for template rendering

The current `frame_00.png` is a single-channel grayscale image (no alpha). With `isTemplate = true`, macOS uses luminance directly: dark pixels render in the menu bar tint, white pixels are invisible. This avoids any alpha channel manipulation.

## Future enhancement

Convert grayscale frames to RGBA with alpha-based transparency (dark lines → opaque black, white background → alpha=0). This would give more precise template rendering. Structured as an optional processing step in the script.

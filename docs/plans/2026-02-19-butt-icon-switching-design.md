# Butt Icon Switching — Design

## Goal

Allow users to choose from 47 different animated butt icons for the menu bar, replacing the single hardcoded async-butt.

## Status: Phase 1 complete

The asset pipeline and frame loading are done. The app loads frames from `ButtFrames/` at runtime. What remains is the UI for switching butts (Phase 2).

## What was built

### Asset pipeline (`buttsss/brazilian-butt-lift.py`)

A Python script that processes 47 source GIFs into menu-bar-ready PNG frames.

**Pipeline per frame:**
1. Extract frame from animated GIF (Pillow, compositing onto white canvas for correct disposal handling)
2. Convert to grayscale (single-channel luminance)
3. Resize to 40x40 with LANCZOS resampling
4. Save as PNG

**TODO (future step):** Convert to RGBA with alpha-based transparency (dark lines → opaque black, white background → alpha=0) for more precise template rendering. The script is structured with a clear insertion point for this.

**Setup:** pyenv 3.12.8 + venv + Pillow. See `buttsss/README.md`.

### Output structure

```
ButtFrames/                        <- Xcode folder reference at project root
  manifest.json                    <- list of all butts with id, name, frameCount
  alien-butt/
    frame_00.png ... frame_15.png  <- 40x40 grayscale PNGs
  async-butt/
    frame_00.png ... frame_05.png
  pirate-butt/
    frame_00.png ... frame_19.png
  ...47 folders, 457 frames total
```

`ButtFrames/` lives at the project root (outside `pattiSpecialButton/`) because Xcode's `PBXFileSystemSynchronizedRootGroup` flattens resources — files with the same name from different subfolders would collide. As a folder reference added via `PBXFileReference` with `lastKnownFileType = folder`, the full directory hierarchy is preserved in the app bundle at `Contents/Resources/ButtFrames/`.

### Source GIFs

```
buttsss/fractured-but-whole/       <- 47 animated GIFs, 512x512
  Alien-Butt.gif                      black line art on white background
  async-butt.gif                      by Pablo Stanley (buttsss.com, CC BY 4.0)
  ...
```

### Swift integration (done)

`AppDelegate.swift` loads frames dynamically at runtime:

```swift
private let currentButtId = "async-butt"

private func loadFrameImages() {
    guard let buttDir = Bundle.main.url(
        forResource: currentButtId, withExtension: nil, subdirectory: "ButtFrames"
    ) else { ... }

    var i = 0
    while true {
        let url = buttDir.appendingPathComponent(String(format: "frame_%02d.png", i))
        guard FileManager.default.fileExists(atPath: url.path) else { break }
        // load image, set size 20x20, isTemplate = true
        i += 1
    }
}
```

Frame count is dynamic (loop until file not found), not hardcoded. `advanceFrame()` uses `frameImages.count` instead of a constant.

### Old asset catalog removed

- Deleted `Assets.xcassets/ButtFrame0–5.imageset/` (old hardcoded 6-frame imagesets)
- Deleted `Assets/ButtFrames/` and `Assets/async-butt.gif` (old source files)

## Why grayscale works for template rendering

macOS template rendering (`isTemplate = true`) uses grayscale luminance directly when there is no alpha channel. Dark pixels render in the menu bar tint color, white pixels are invisible. The source GIFs are already black line art on white — converting to grayscale is all that's needed.

## Phase 2: Butt picker UI (not yet started)

- Read `manifest.json` at launch to discover available butts
- Right-click menu gets a "Choose Butt" submenu built from the manifest
- Persist selection with `UserDefaults`
- Reload frames when selection changes

## Decisions made

| Decision | Choice | Why |
|---|---|---|
| Frame storage | Pre-processed PNGs in subfolders | Fast runtime loading, no GIF decoding at runtime, clean organization |
| Where ButtFrames lives | Project root as folder reference | Xcode auto-sync flattens resources; folder reference preserves hierarchy |
| Image format | Grayscale, no alpha | macOS template rendering reads luminance directly; matches original working frames |
| Frame size | 40x40 px | 20x20 points at 2x Retina |
| Naming | `frame_00.png` in named subfolders | Clean, sequential, no prefix clutter |
| GIF source location | `buttsss/fractured-but-whole/` | Separates source art from tooling |

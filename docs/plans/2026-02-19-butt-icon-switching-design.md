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
buttsss/fractured-but-wholes/      <- 47 animated GIFs, 512x512
  Alien-Butt.gif                      black line art on white background
  async-butt.gif                      by Pablo Stanley (buttsss.com, CC BY 4.0)
  ...
```

Also added as an Xcode folder reference so GIFs are copied to the app bundle for the preferences picker (see Phase 2).

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

## Phase 2: Butt Picker Preferences Window

### What the user sees

A macOS preferences window with a grid of all 47 animated butts. Each cell shows the butt wiggling at ~80pt with its name below in system font (TODO: Space Mono from Google Fonts in a future pass). The currently selected butt has a subtle background tint. Click any butt to instantly switch the menu bar icon. Selection persists across restarts via UserDefaults.

### How to open preferences

Two entry points:

- **Right-click menu**: "Preferences..." item in the status item context menu.
- **Re-launch the app**: From Spotlight, Launchpad, or Applications folder. macOS calls `applicationShouldHandleReopen(_:hasVisibleWindows:)` which opens the settings window.

### Window lifecycle & activation policy

`LSUIElement = YES` stays — the app normally has no Dock icon.

- When the settings window opens: `NSApp.setActivationPolicy(.regular)` — Dock icon and app menu bar appear temporarily.
- When the settings window closes: `NSApp.setActivationPolicy(.accessory)` — back to invisible. Observed via `NSWindow.willCloseNotification`.
- This matches the behavior of apps like Magnet: pure menu bar normally, full app chrome while preferences are open.

### Architecture

**SwiftUI Settings scene** — The app already has `Settings { EmptyView() }`. Replace `EmptyView()` with `ButtPickerView`. macOS handles window chrome and lifecycle.

**Components:**

- `ButtPickerView` — Top-level settings view. `ScrollView` + `LazyVGrid` of `AnimatedButtCell`s, reads manifest for butt list, reads/writes selected butt id from UserDefaults.
- `AnimatedButtCell` — Single grid cell: animated GIF thumbnail (~80pt) + name label below. Starts/stops animation on `onAppear`/`onDisappear`.
- `GIFAnimator` (ObservableObject) — Loads a GIF from the bundle using `NSBitmapImageRep`, reads frame count and delays, publishes the current frame as an `NSImage` via a `Timer`. Handles GIF frame disposal/compositing natively (unlike raw `CGImageSource`).
- `ButtInfo` — Simple struct (`id`, `name`, `frameCount`, `gifFilename`) decoded from `manifest.json`.

**Data flow:**

1. At launch, load `manifest.json` from `ButtFrames/` → array of `ButtInfo`.
2. Selected butt id stored in `UserDefaults` (key: `"selectedButtId"`, default: `"async-butt"`).
3. `ButtPickerView` displays the grid from the manifest.
4. On tap, writes new id to UserDefaults.
5. `AppDelegate` observes the UserDefaults change → reloads `ButtFrames/<id>/` PNGs for the menu bar icon → restarts animation timer.

**GIF source for the picker:**

- GIFs live in the bundle under `fractured-but-wholes/` (Xcode folder reference).
- `GIFAnimator` maps butt id → GIF filename using the `gifFilename` field in the manifest.
- `NSBitmapImageRep` loads the GIF data, `.frameCount` gives the number of frames, `.currentFrame` property cycles through them with correct compositing.

### File changes

| File | Change |
|---|---|
| `pattiSpecialButtonApp.swift` | Replace `EmptyView()` with `ButtPickerView` in Settings scene |
| `AppDelegate.swift` | Load manifest, make `currentButtId` dynamic from UserDefaults, observe changes, add "Preferences..." to right-click menu, implement `applicationShouldHandleReopen`, switch activation policy on window open/close |
| **New:** `ButtPickerView.swift` | SwiftUI grid view with LazyVGrid of AnimatedButtCells |
| **New:** `AnimatedButtCell.swift` | Single cell view with GIFAnimator |
| **New:** `GIFAnimator.swift` | ObservableObject: NSBitmapImageRep GIF loading + frame cycling |
| **New:** `ButtInfo.swift` | Struct + manifest JSON decoding |
| `buttsss/brazilian-butt-lift.py` | Update path from `fractured-but-whole` to `fractured-but-wholes` |
| Rename `buttsss/fractured-but-whole/` → `buttsss/fractured-but-wholes/` | Folder rename |
| `ButtFrames/manifest.json` | Add `gifFilename` field per butt |
| Xcode project | Add `buttsss/fractured-but-wholes/` as folder reference |

### What we're NOT building

- Sound picker (separate future feature)
- Custom font (TODO: Space Mono later)
- Hover effects or grow-on-hover animations
- Theme/beta channel settings

## Decisions made

| Decision | Choice | Why |
|---|---|---|
| Frame storage | Pre-processed PNGs in subfolders | Fast runtime loading, no GIF decoding at runtime, clean organization |
| Where ButtFrames lives | Project root as folder reference | Xcode auto-sync flattens resources; folder reference preserves hierarchy |
| Image format | Grayscale, no alpha | macOS template rendering reads luminance directly; matches original working frames |
| Frame size | 40x40 px | 20x20 points at 2x Retina |
| Naming | `frame_00.png` in named subfolders | Clean, sequential, no prefix clutter |
| GIF source location | `buttsss/fractured-but-wholes/` | Separates source art from tooling (renamed from `fractured-but-whole`) |
| Picker UI | SwiftUI Settings scene + LazyVGrid | Native macOS preferences pattern; Settings scene already stubbed out |
| Picker thumbnails | Source GIFs via NSBitmapImageRep | Handles GIF compositing natively; no extra asset processing needed |
| Thumbnail size | ~80pt | Slightly larger than Finder icons; good balance of visibility and density |
| Thumbnail animation | Animate on appear (LazyVGrid) | onAppear/onDisappear controls animation; only visible butts animate |
| Selection indicator | Background tint | Subtle, native-feeling highlight on the selected butt |
| Selection behavior | Instant switch | Click a butt, menu bar icon changes immediately; persists via UserDefaults |
| Window stays open | Yes | User closes manually; allows browsing and switching freely |
| Activation policy | Temporary .regular while preferences open | Matches Magnet pattern: Dock icon + app menu while settings are visible |
| Font | System font (SF Pro) | Native look; TODO: Space Mono in a future pass |

# pattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a sound when clicked.

## What it does

- **Menu bar icon**: An animated butt (extracted from `async-butt.gif`) that wiggles continuously in the macOS menu bar.
- **Click action**: Left-click plays a sound.
- **Right-click menu**: Shows a small context menu with a Quit option.
- **No Dock icon**: Pure menu bar app — no Dock presence, no main window.

## Source assets

All source assets live in `pattiSpecialButton/Assets/`:
- GIF source: `async-butt.gif` (512x512, ~6 frames, 0.6s loop)
- Sound file: TBD (system sound or custom file)

## Project structure

Standard Xcode SwiftUI project. Key files:
- `pattiSpecialButtonApp.swift` — App entry point
- `ContentView.swift` — (will be minimal or removed since there's no main window)

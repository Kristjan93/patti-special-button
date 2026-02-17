# pattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a sound when clicked.

## What it does

- **Menu bar icon**: An animated butt that wiggles continuously in the macOS menu bar (6 frames, 0.1s per frame).
- **Left-click**: Plays a system sound ("Funk"). Will be swapped for a custom fart sound later.
- **Right-click menu**: Shows a context menu with a Quit option.
- **No Dock icon**: Pure menu bar app — no Dock presence, no main window. Configured via `LSUIElement = YES`.

## Architecture

Hybrid SwiftUI + AppKit. SwiftUI provides the `@main` app lifecycle, but all menu bar logic is in AppKit via `@NSApplicationDelegateAdaptor`.

- `pattiSpecialButtonApp.swift` — App entry point. Wires up AppDelegate, uses `Settings { EmptyView() }` as a no-window scene.
- `AppDelegate.swift` — Core logic: `NSStatusItem` setup, `DispatchSourceTimer` animation, left/right click handling, `NSSound` playback.

## Assets

- `Assets.xcassets/ButtFrame0–5.imageset/` — 6 animation frames (36x36 PNG, 2x scale, template rendering for light/dark menu bar)
- `Assets/async-butt.gif` — Original source GIF (512x512)
- `Assets/ButtFrames/` — Extracted PNG frames (source files)

## Swapping the sound

1. Drop a sound file (e.g., `fart.aiff`) into the `pattiSpecialButton/` directory
2. Change `soundName` constant in `AppDelegate.swift` from `"Funk"` to `"fart"`
3. `NSSound(named:)` finds bundle resources before system sounds automatically

## Build notes

- macOS 15.4 deployment target, Swift 5
- App sandbox enabled
- Bundle ID: `com.pattiVoice.pattiSpecialButton`
- Signing: may need ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) if certificate is expired

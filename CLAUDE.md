# pattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a fart sound when clicked.

## What it does

- **Menu bar icon**: An animated butt that wiggles continuously in the macOS menu bar (6 frames, 0.1s per frame).
- **Left-click (tap)**: Plays a short fart sound (minimum 0.5s so the first fart always completes).
- **Left-click (hold)**: Keeps playing farts in a loop for as long as the mouse is held. Loops back to start if held past end of file.
- **Right-click menu**: Shows a context menu with a Quit option.
- **No Dock icon**: Pure menu bar app — no Dock presence, no main window. Configured via `LSUIElement = YES`.

## Architecture

Hybrid SwiftUI + AppKit. SwiftUI provides the `@main` app lifecycle, but all menu bar logic is in AppKit via `@NSApplicationDelegateAdaptor`.

- `pattiSpecialButtonApp.swift` — App entry point. Wires up AppDelegate, uses `Settings { EmptyView() }` as a no-window scene.
- `AppDelegate.swift` — Core logic: `NSStatusItem` setup, `DispatchSourceTimer` animation, `AVAudioPlayer` playback with hold-to-play.
- `StatusItemMouseView` (in AppDelegate.swift) — Transparent `NSView` subclass overlaid on the status bar button. Intercepts `mouseDown`/`mouseUp`/`rightMouseUp` to bypass `NSStatusBarButton`'s tracking loop which swallows `mouseUp` events.

### Why StatusItemMouseView exists

`NSStatusBarButton` enters a modal tracking loop on mouseDown that consumes `leftMouseUp` events. Neither `sendAction(on:)`, local event monitors, nor any AppKit event dispatch mechanism receives the mouseUp. The fix is a custom `NSView` added as a subview on top of the button — `NSView` guarantees `mouseUp` is delivered to the same view that received `mouseDown`.

## Sound

- **File**: `556505__jixolros__small-realpoots105-110.wav` — contains multiple short farts with 0.4s gaps, trimmed from original freesound.org recording.
- **Playback**: `AVAudioPlayer` with `numberOfLoops = -1` (infinite loop). Starts on mouseDown, stops on mouseUp with a 0.5s minimum play duration enforced via `DispatchWorkItem`.

### Swapping the sound

1. Drop a new sound file into the `pattiSpecialButton/` directory
2. Update the `Bundle.main.url(forResource:withExtension:)` call in `AppDelegate.swift` to match the new filename
3. Adjust `minimumPlayDuration` if needed to match the new sound's timing

## Assets

- `Assets.xcassets/ButtFrame0–5.imageset/` — 6 animation frames (36x36 PNG, 2x scale, template rendering for light/dark menu bar)
- `Assets/async-butt.gif` — Original source GIF (512x512)
- `Assets/ButtFrames/` — Extracted PNG frames (source files)

## Build notes

- macOS 15.4 deployment target, Swift 5
- App sandbox enabled
- Bundle ID: `com.pattiVoice.pattiSpecialButton`
- Signing: may need ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) if certificate is expired

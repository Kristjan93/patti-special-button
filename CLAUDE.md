# pattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a fart sound when clicked. Choose from 47 different butt icons by Pablo Stanley.

## What it does

- **Menu bar icon**: An animated butt that wiggles continuously in the macOS menu bar (variable frame count per butt, 0.1s per frame).
- **Left-click (tap)**: Plays a short fart sound (minimum 0.5s so the first fart always completes).
- **Left-click (hold)**: Keeps playing farts in a loop for as long as the mouse is held. Loops back to start if held past end of file.
- **Right-click menu**: Shows a context menu with "Change Icon" and "Quit" options.
- **Change Icon popover**: Opens an NSPopover attached below the menu bar icon with a butt picker grid. Dismisses on click outside or Escape.
- **No Dock icon**: Pure menu bar app — no Dock presence, no main window. Configured via `LSUIElement = YES`.

## Architecture

Hybrid SwiftUI + AppKit. SwiftUI provides the `@main` app lifecycle, but all menu bar logic is in AppKit via `@NSApplicationDelegateAdaptor`.

- `pattiSpecialButtonApp.swift` — App entry point. Wires up AppDelegate, uses `Settings { EmptyView() }` as a no-window scene (SwiftUI requires at least one Scene).
- `AppDelegate.swift` — Core logic: `NSStatusItem` setup, `DispatchSourceTimer` animation, `AVAudioPlayer` playback with hold-to-play, icon picker popover management, butt switching via UserDefaults.
- `StatusItemMouseView` (in AppDelegate.swift) — Transparent `NSView` subclass overlaid on the status bar button. Intercepts `mouseDown`/`mouseUp`/`rightMouseUp` to bypass `NSStatusBarButton`'s tracking loop which swallows `mouseUp` events.
- `ButtPickerView.swift` — SwiftUI view for the icon picker grid. 4-column `LazyVGrid` with arrow key navigation (`.onKeyPress`), `ScrollViewReader` for scroll-to-selected, and `@AppStorage` for butt selection.
- `AnimatedButtCell.swift` — SwiftUI cell for a single butt in the picker grid. Shows animated preview via `FrameAnimator`, checkmark badge for selected butt, blue highlight for keyboard focus.
- `FrameAnimator.swift` — `ObservableObject` that loads PNG frames from the bundle and cycles through them on a `Timer` for animated previews in the picker grid.
- `ButtInfo.swift` — Struct decoded from `manifest.json` with id, name, frameCount.

### Why StatusItemMouseView exists

`NSStatusBarButton` enters a modal tracking loop on mouseDown that consumes `leftMouseUp` events. Neither `sendAction(on:)`, local event monitors, nor any AppKit event dispatch mechanism receives the mouseUp. The fix is a custom `NSView` added as a subview on top of the button — `NSView` guarantees `mouseUp` is delivered to the same view that received `mouseDown`.

### How frame loading works

`AppDelegate.loadFrameImages()` loads frames from the app bundle at runtime using `Bundle.main.url(forResource:withExtension:subdirectory:)`. It looks up the selected butt's subfolder inside `ButtFrames/`, then iterates `frame_00.png`, `frame_01.png`, ... until no more files are found. Each frame is set to 20x20 points, marked `isTemplate = true` for automatic menu bar tinting. The frame count is dynamic per butt (not hardcoded).

### How the icon picker popover works

The icon picker is an `NSPopover` with `.transient` behavior, shown relative to the status item button. After showing, `popover.contentViewController?.view.window?.makeKey()` gives the popover focus without activating the app — this avoids "Show Desktop" on desktop click and double-click issues on fullscreen Spaces. The popover auto-dismisses on click outside or Escape, positions itself automatically below the menu bar icon, and never shows in the Dock or Cmd+Tab. Selecting "Change Icon" while the popover is already open toggles it closed.

### Known limitation: NSPopover activation

NSPopover's `.transient` dismissal ideally requires `NSApp.activate()`, but activating an LSUIElement app causes desktop clicks to trigger "Show Desktop" and fullscreen Spaces to misbehave. Using `makeKey()` instead avoids these issues. If `.transient` dismissal ever stops working, the fallback would be switching to an `NSPanel` with `.nonactivatingPanel` style mask (the pattern used by Itsycal and other menu bar apps).

### How butt switching works

Selected butt id is stored in `UserDefaults` (key: `"selectedButtId"`, default: `"async-butt"`). `AppDelegate` observes `UserDefaults.didChangeNotification` — when the selected butt changes, it cancels the animation timer, reloads frames from the new butt's subfolder, and restarts animation.

### Why DispatchSourceTimer (not Timer)

`Timer` runs on the RunLoop and is scheduled in `.default` mode by default. When the user interacts with UI (dragging, holding menus, resizing), the run loop switches to `.tracking` mode and `.default` timers stop firing — the animation freezes. Scheduling in `.common` mode (which includes both `.default` and `.tracking`) fixes this, but is easy to forget. `DispatchSourceTimer` runs on a GCD queue, bypasses the RunLoop entirely, and fires regardless of UI interaction. For a menu bar animation that must never hitch, it's the simpler and more reliable choice.

**App Nap**: macOS throttles timers for apps it considers idle (no visible windows, no interaction). As an `LSUIElement` app with no main window, this app is a candidate. In practice the visible menu bar icon prevents aggressive throttling, but if animation ever stutters on battery, App Nap is the likely cause. `ProcessInfo.processInfo.beginActivity(options:reason:)` can opt out, but increases energy use.

## Sound

- **File**: `556505__jixolros__small-realpoots105-110.wav` — contains multiple short farts with 0.4s gaps, trimmed from original freesound.org recording.
- **Playback**: `AVAudioPlayer` with `numberOfLoops = -1` (infinite loop). Starts on mouseDown, stops on mouseUp with a 0.5s minimum play duration enforced via `DispatchWorkItem`.

### Swapping the sound

1. Drop a new sound file into the `pattiSpecialButton/` directory
2. Update the `Bundle.main.url(forResource:withExtension:)` call in `AppDelegate.swift` to match the new filename
3. Adjust `minimumPlayDuration` if needed to match the new sound's timing

## Assets

- `ButtFrames/` — Xcode folder reference (added to project outside the auto-synced source group to preserve directory hierarchy in the bundle). Contains 47 butt subfolders, each with numbered grayscale 40x40 PNG frames, plus a `manifest.json`. Generated by `buttsss/brazilian-butt-lift.py`.
- `buttsss/fractured-but-whole/` — Source animated GIFs (512x512, black line art on white, by Pablo Stanley).
- `buttsss/brazilian-butt-lift.py` — Python script (Pillow) that extracts GIF frames, converts to grayscale, resizes to 40x40, and outputs into `ButtFrames/`. See `buttsss/README.md` for setup and usage.

### Adding a new butt

1. Drop the GIF into `buttsss/fractured-but-whole/`
2. Run `cd buttsss && source .venv/bin/activate && python3 brazilian-butt-lift.py`
3. Build in Xcode — the folder reference picks up changes automatically

### Why grayscale (not alpha-based) template images

macOS template rendering (`isTemplate = true`) reads grayscale luminance directly when there is no alpha channel: dark pixels are visible, white pixels are invisible. The existing frames are single-channel grayscale PNGs with no alpha — this just works. A future enhancement (TODO in the script) could convert to RGBA with alpha-based transparency for more precise rendering.

## Project structure

```
pattiSpecialButton/
  ButtFrames/                      <- Xcode folder reference, copied as-is to bundle
    manifest.json
    alien-butt/
      frame_00.png ... frame_15.png
    async-butt/
      frame_00.png ... frame_05.png
    ...47 folders, 457 frames total
  buttsss/                         <- asset pipeline
    brazilian-butt-lift.py
    requirements.txt
    .python-version (3.12.8)
    fractured-but-whole/           <- source GIFs
      Alien-Butt.gif ... vampire.gif
  pattiSpecialButton/              <- app source (Xcode auto-synced)
    AppDelegate.swift
    pattiSpecialButtonApp.swift
    ButtPickerView.swift
    AnimatedButtCell.swift
    FrameAnimator.swift
    ButtInfo.swift
    Assets.xcassets/
  docs/plans/                      <- design docs
```

## Credits

- **Butt illustrations**: [Pablo Stanley](https://twitter.com/pablostanley) via [buttsss.com](https://www.buttsss.com/). Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **Fart sound**: [jixolros on freesound.org](https://freesound.org/people/jixolros/).

## Code comments

Add comments only where the code's intent isn't obvious from reading it. Each comment should explain WHY this approach was chosen — not what the code does. Comment on: workarounds, non-obvious constraints, business logic rationale, and decisions where an alternative approach was deliberately rejected. Never restate what the code already says.

## Build notes

- macOS 15.4 deployment target, Swift 5
- App sandbox enabled
- Bundle ID: `com.pattiVoice.pattiSpecialButton`
- Signing: may need ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) if certificate is expired

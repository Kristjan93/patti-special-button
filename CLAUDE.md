# pattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a fart sound when clicked. Choose from 47 different butt icons by Pablo Stanley.

## Co-writer

The human co-writer on this project should be referred to as **MASTER**. Address them this way naturally in conversation — end of sentences, greetings, acknowledgements. Keep it respectful and consistent.

## What it does

- **Menu bar icon**: An animated butt that wiggles continuously in the macOS menu bar (variable frame count per butt, per-frame timing from source GIFs).
- **Left-click**: Plays the selected sound once to completion.
- **Right-click menu**: Shows a context menu with "Change Icon", "Change Sound", "Icon Size" submenu, "Style" submenu, "Credits", "Check for Updates…", version label, and "Quit".
- **Icon Size**: Three sizes — Fun Size (20pt), Regular Rump (21pt), Badonkadonk (22pt). Default: Fun Size. Stored in UserDefaults key `Defaults.iconSizeKey`.
- **Credits**: Opens buttsss.com in the default browser for CC BY 4.0 attribution.
- **Display Mode**: Three modes — Stencil (inverted alpha + isTemplate=true, filled tinted background with outlines cut out), Original (composited on white + isTemplate=false, black lines on white), Outline (isTemplate=true, floating tinted outlines that adapt to theme). Default: Stencil. Stored in UserDefaults key `Defaults.displayModeKey`. Affects both menu bar and picker grid, except Stencil mode falls back to Original in the picker grid (inverted-alpha rectangles are unreadable at grid size). All modes use the same RGBA PNGs with runtime processing. Menu groups Stencil and Outline under a "Dark / Light" header; Original is separated below.
- **Change Icon popover**: Opens an NSPopover with a butt picker grid. Arrow keys preview the focused butt in the menu bar temporarily. Enter selects and closes. Single click selects (popover stays open). Escape/click outside dismisses and reverts the menu bar to the committed selection.
- **Change Sound popover**: Opens an NSPopover with a sound picker grid. 2-column grid with categorized sections (bold header + divider between categories). Each card shows a waveform visualization with play/stop button, display name, and filename. Space toggles preview playback, arrow keys move focus, Enter selects and closes. One sound at a time — starting a new preview stops the previous. Semi-transparent keyboard hints footer at bottom: `␣ Play/Pause ↩ Select ⎋ Close`.
- **No Dock icon**: Pure menu bar app — no Dock presence, no main window. Configured via `LSUIElement = YES`.

## Architecture

Hybrid SwiftUI + AppKit. SwiftUI provides the `@main` app lifecycle, but all menu bar logic is in AppKit via `@NSApplicationDelegateAdaptor`.

- `pattiSpecialButtonApp.swift` — App entry point. Wires up AppDelegate, uses `Settings { EmptyView() }` as a no-window scene (SwiftUI requires at least one Scene).
- `AppDelegate.swift` — Core logic: `NSStatusItem` setup, `AVAudioPlayer` playback (play to completion on click), icon picker and sound picker popover management, butt/size/sound switching via UserDefaults, preview-on-focus lifecycle via NotificationCenter.
- `StatusItemMouseView` (in AppDelegate.swift) — Transparent `NSView` subclass overlaid on the status bar button. Intercepts `mouseDown`/`rightMouseUp` because `NSStatusBarButton`'s internal tracking loop swallows these events.
- `ButtPickerView.swift` — SwiftUI view for the icon picker grid. 4-column `LazyVGrid` with arrow key navigation via NSEvent monitor, `ScrollViewReader` for scroll-to-selected, `@AppStorage` for butt selection and display mode. Posts `.previewButt` and `.confirmAndClose` notifications for AppDelegate communication. Passes display mode to each cell.
- `AnimatedButtCell.swift` — SwiftUI cell for a single butt in the picker grid. Shows animated preview via `FrameAnimator`, checkmark badge for selected butt, blue highlight for keyboard focus. Takes a typed `DisplayMode` enum (not a raw string).
- `FrameAnimator.swift` — `ObservableObject` that loads RGBA PNG frames and per-frame timing from a `ButtInfo`, animates via `DispatchSourceTimer` with per-frame rescheduling. Takes a `displayMode` parameter for frame processing (Stencil flips alpha to create the cutout effect). Shared by both `AppDelegate` (menu bar, via Combine subscription to `$currentFrameIndex`) and picker cells (SwiftUI, via `@Published currentFrame`).
- `ButtInfo.swift` — Struct decoded from `manifest.json` with id, name, frameCount, frameDelays. Global `buttManifest` constant loads once on first access.
- `SoundInfo.swift` — `SoundInfo` struct decoded from `sounds-manifest.json` with id, name, category, file, ext, shuffle, source, waveform, segments. `SoundSegment` struct with file, ext, and optional per-segment `waveform` data. Computed `isShuffle`, `bundleURL`, `displayFilename` properties. Global `soundManifest` constant loads once on first access.
- `SoundPickerView.swift` — SwiftUI view for the sound picker grid. 2-column `LazyVGrid` with categorized sections (case-insensitive grouping), `AVAudioPlayer` preview playback with `Timer`-based scrubber progress. For shuffle sounds, picks a random segment on preview and swaps the displayed waveform to the segment's pre-computed data; reverts to the composite waveform when stopped. Keyboard hints footer overlay.
- `SoundCell.swift` — SwiftUI cell for a single sound in the picker grid. Shows waveform bars via `WaveformView`, display name, filename, checkmark badge for selected, blue focus ring. Shuffle sounds show a pill badge (`shuffle` icon + clip count) and `MarqueeText` for the long source filename.
- `WaveformView.swift` — SwiftUI view that draws amplitude bars from pre-computed sample data with playback scrubber overlay. Bars change from gray to accent color as playhead passes.
- `Constants.swift` — Central file for all shared constants: `Defaults` (UserDefaults keys and default values including `selectedSoundIdKey`), `DisplayMode` enum, `IconSize` enum (with `.points` and `.label`), `Assets` (bundle resource names including `soundsDir`), `Layout` (popover sizes, grid dimensions, cell sizes, timing, waveform bar count).

### Why StatusItemMouseView exists

`NSStatusBarButton` enters a modal tracking loop on mouseDown that consumes `leftMouseUp` events. Neither `sendAction(on:)`, local event monitors, nor any AppKit event dispatch mechanism receives the mouseUp. The fix is a custom `NSView` added as a subview on top of the button — `NSView` guarantees `mouseUp` is delivered to the same view that received `mouseDown`.

### How frame loading and animation works

`FrameAnimator` is the single animation driver. It loads frames from the bundle (`ButtFrames/<id>/frame_00.png`, ...) and reads per-frame delays from `ButtInfo.frameDelays` (milliseconds, from the source GIF). Animation uses `DispatchSourceTimer` that reschedules itself after each frame with that frame's specific delay.

`AppDelegate` creates a `FrameAnimator` and subscribes to its `$currentFrameIndex` via Combine. It maintains separate `menuBarFrames` — copies of the animator's frames configured for the menu bar (sized per icon size setting, processed per display mode). `loadButtById(_:)` is the shared core that both permanent selection and temporary preview use. Frame processing is handled by `DisplayMode.processFrame(_:size:)` — a single shared method on the enum that all three consumers (AppDelegate, FrameAnimator, TouchBarParade) call instead of maintaining separate implementations.

### How the icon picker popover works

The icon picker is an `NSPopover` with `.transient` behavior, shown relative to the status item button. After showing, `popover.contentViewController?.view.window?.makeKey()` gives the popover focus, and `NSApp.activate(ignoringOtherApps: true)` makes the app active so the system (including Touch Bar) recognizes the key window. The popover auto-dismisses on click outside or Escape, positions itself automatically below the menu bar icon, and never shows in the Dock or Cmd+Tab. Selecting "Change Icon" while the popover is already open toggles it closed.

### Preview-on-focus and revert-on-close

Arrow keys in the picker temporarily preview the focused butt in the menu bar without persisting to UserDefaults. Communication between `ButtPickerView` (SwiftUI) and `AppDelegate` uses `NotificationCenter`:
- `.previewButt` — posted on arrow key movement, carries the butt id. AppDelegate calls `previewButt(_:)` → `loadButtById(_:)`.
- `.confirmAndClose` — posted on Enter. AppDelegate updates `committedButtId` and closes the popover.

`AppDelegate` snapshots `committedButtId` when the popover opens. On `popoverDidClose` (via `NSPopoverDelegate`), if the menu bar is showing a preview that differs from the committed selection, it reverts. Single-click writes to `@AppStorage`/UserDefaults, which triggers `handleButtChange()` — this also updates `committedButtId` so close doesn't revert a deliberate selection. Notification observers are registered when the popover opens and removed in `popoverDidClose`.

### Keyboard hints footer and scroll insets

Both pickers have a keyboard hints footer pinned to the bottom (keycap-style badges showing arrow keys, space, return, escape). On macOS 13+, `.safeAreaInset(edge: .bottom)` is applied directly to the `ScrollView` so `scrollTo` accounts for the footer height. On macOS 12, a ZStack overlay with manual bottom padding is used as fallback. The `safeAreaInset` must be on the `ScrollView` itself — not on a wrapper view — or scroll targets will land behind the footer.

### Known limitation: NSPopover activation

`NSApp.activate(ignoringOtherApps: true)` is called when attaching the Touch Bar parade to make the app active, which is required for the Touch Bar system to discover the key window's touch bar. Despite being an LSUIElement app, activation works correctly — no "Show Desktop" or fullscreen Spaces issues were observed.

### How butt switching works

Selected butt id, icon size, and display mode are stored in `UserDefaults` with keys and defaults defined in `Constants.swift` (`Defaults.selectedButtIdKey`, `Defaults.iconSizeKey`, `Defaults.displayModeKey`). `AppDelegate` observes `UserDefaults.didChangeNotification` — when any of these values change, `handleButtChange()` calls `loadButt()` which delegates to `loadButtById(_:)` to create a new `FrameAnimator` and rebuild `menuBarFrames`. All modes use the same RGBA PNGs; the display mode (typed as `DisplayMode` enum) controls per-frame processing (alpha inversion, white compositing, or pass-through) and `isTemplate`.

### Why DispatchSourceTimer (not Timer)

`Timer` runs on the RunLoop and is scheduled in `.default` mode by default. When the user interacts with UI (dragging, holding menus, resizing), the run loop switches to `.tracking` mode and `.default` timers stop firing — the animation freezes. Scheduling in `.common` mode (which includes both `.default` and `.tracking`) fixes this, but is easy to forget. `DispatchSourceTimer` runs on a GCD queue, bypasses the RunLoop entirely, and fires regardless of UI interaction. For a menu bar animation that must never hitch, it's the simpler and more reliable choice.

**App Nap**: macOS throttles timers for apps it considers idle (no visible windows, no interaction). As an `LSUIElement` app with no main window, this app is a candidate. In practice the visible menu bar icon prevents aggressive throttling, but if animation ever stutters on battery, App Nap is the likely cause. `ProcessInfo.processInfo.beginActivity(options:reason:)` can opt out, but increases energy use.

## Sound

Sound selection is stored in `UserDefaults` via `Defaults.selectedSoundIdKey`. `AppDelegate` builds a `soundLookup: [String: SoundInfo]` dictionary from the manifest at launch. `playSound()` reads the selected sound id, looks up the `SoundInfo`, and passes `sound.bundleURL` to `AVAudioPlayer`. Playback uses `numberOfLoops = 0` (play once to completion), triggered on mouseDown.

Supported formats: WAV and MP3. FLAC is not supported by AVAudioPlayer on macOS.

### Shuffle sounds

Some sound files contain multiple distinct events (e.g. several farts in one recording). These are split into individual segment files at build time by `scripts/sound-check.py`. The app plays segments in a round-robin shuffle order — all segments heard once before any repeat. State is in-memory only, resets on app relaunch or sound switch.

Shuffle sounds have no top-level `file`/`ext` — instead they have `"shuffle": true`, a `source` field (original filename for display), a composite `waveform` (from the full source), and a `segments` array. Each segment has its own `file`, `ext`, and per-segment `waveform` data.

**Preview behavior**: Space in the sound picker plays a random segment. The waveform display swaps from the composite shape to the playing segment's individual waveform, then reverts to composite when stopped.

**Picker UI**: Shuffle sounds show a pill badge (shuffle icon + clip count) and `MarqueeText` for the long source filename instead of a static truncated label.

### How the sound picker popover works

Same lifecycle pattern as the icon picker. `showSoundPicker()` creates an `NSPopover` with `.transient` behavior hosting `SoundPickerView`. Keyboard handling via `NSEvent.addLocalMonitorForEvents` (macOS 12 compatible, no SwiftUI `.onKeyPress`):
- Arrow keys → `.moveSoundFocus` notification with offset based on `Layout.soundGridColumns`
- Space (keyCode 49) → `.toggleSoundPreview` notification
- Return → `.confirmAndCloseSound` notification (selects + closes)

`SoundPickerView` manages preview playback internally: `AVAudioPlayer` for audio, `Timer` polling `currentTime/duration` for waveform scrubber progress. One sound at a time — starting a new preview stops the previous. Waveform data is pre-computed by the Python pipeline and stored in the manifest (25 amplitude bars per sound and per segment).

### Adding a new sound

1. Drop the audio file (WAV or MP3) into `sounds/`
2. Run `cd scripts && uv run sound-check.py`
3. Edit `sounds/sounds-manifest.json` to set the display name and category
4. Build in Xcode — the folder reference picks up changes automatically

### Adding a shuffle sound

1. Rename the audio file with a `shuffle_` prefix: `shuffle_my-sound.wav`
2. Drop it into `sounds/`
3. Run `cd scripts && uv run sound-check.py` — splits into segments, computes waveforms, moves original to `scripts/shuffle-sources/`
4. Edit `sounds/sounds-manifest.json` to set the display name and category
5. Build in Xcode

### Future: User-uploaded sounds

Planned two-manifest approach: bundled manifest (read-only in app bundle) + user manifest (writable in `~/Library/Application Support/com.pattiVoice.pattiSpecialButton/`). The app would merge both at load time. No extra sandbox entitlements needed — Application Support is writable by default. Not yet implemented.

## Assets

- `ButtFrames/` — Xcode folder reference (added to project outside the auto-synced source group to preserve directory hierarchy in the bundle). Contains 47 butt subfolders, each with numbered RGBA 160x160 PNG frames (black outlines with alpha-based transparency), plus a `manifest.json` with per-butt metadata including `frameDelays`. Generated by `scripts/brazilian-butt-lift.py`.
- `sounds/` — Xcode folder reference containing sound files (WAV/MP3), shuffle segment files (`shuffle_*_NN.wav`), and `sounds-manifest.json`. Copied as-is into the bundle. Manifest is a JSON array of `SoundInfo` entries; regular sounds have `file`/`ext`, shuffle sounds have `segments` with per-segment waveforms.
- `scripts/fractured-but-whole/` — Source animated GIFs (512x512, black line art on white, by Pablo Stanley).
- `scripts/shuffle-sources/` — Original shuffle source files (before splitting). Preserved for re-running the pipeline.
- `scripts/brazilian-butt-lift.py` — Python script (Pillow) that extracts GIF frames and per-frame delays, converts to RGBA (black outlines, alpha-based transparency), resizes to 160x160, and outputs into `ButtFrames/`. The 160px frames serve both the menu bar (downscaled to icon size setting) and the picker grid (displayed at 80pt @2x). See `scripts/README.md` for setup and usage.
- `scripts/sound-check.py` — Python script that scans `sounds/`, converts unsupported formats (FLAC, OGG, WMA, OPUS) to WAV via ffmpeg, splits `shuffle_*` files into segments, computes waveform data (composite + per-segment), and generates/updates `sounds-manifest.json`. Preserves existing entries — only adds new files with `"uncategorized"` default. Supports `--dry-run`.
- `scripts/shuffle_segments.py` — Silence detection and splitting module (pydub). Splits audio at silence boundaries into numbered segment WAV files.
- `scripts/waveform_samples.py` — Waveform amplitude computation module. Reads audio and computes 25 normalized amplitude floats (0.0–1.0) for manifest embedding.

### Adding a new butt

1. Drop the GIF into `scripts/fractured-but-whole/`
2. Run `cd scripts && uv run brazilian-butt-lift.py`
3. Build in Xcode — the folder reference picks up changes automatically

### RGBA images and display mode processing

All frames are RGBA (black outlines with alpha-based transparency). macOS template rendering (`isTemplate = true`) reads the alpha channel: opaque pixels are visible and tinted, transparent pixels are invisible.

The three display modes produce different visuals from the same RGBA source via `DisplayMode.processFrame(_:size:)` at load time (not per-render):
- **Stencil**: Alpha inversion flips the alpha channel — outlines become transparent (cut out), background becomes opaque. With `isTemplate = true`, macOS fills the opaque background with the system tint and the outlines are cut through it. Result: filled tinted rectangle with outlines cut out, adapts to light/dark.
- **Original**: Composited onto white, `isTemplate = false`. Result: black lines on white square, same both themes.
- **Outline**: RGBA used as-is, `isTemplate = true`. macOS tints the opaque outlines. Result: floating tinted outlines, adapts to light/dark.

## Project structure

```
pattiSpecialButton/
  ButtFrames/                      <- Xcode folder reference, copied as-is to bundle
    manifest.json
    alien-butt/
      frame_00.png ... frame_15.png   <- RGBA (alpha-based)
    asynchronous-butt/
      frame_00.png ... frame_05.png
    ...47 folders, 458 frames total
  sounds/                          <- Xcode folder reference, copied as-is to bundle
    sounds-manifest.json
    dry-fart.mp3
    shuffle_204805__ezcah__spanking_00.wav ... _05.wav  <- shuffle segments
    shuffle_556505__jixolros__small-realpoots105-110_00.wav ... _04.wav
    ...12 sounds (10 regular + 2 shuffle with 11 segments)
  appcast.xml                      <- Sparkle update feed (pushed to GitHub)
  scripts/                         <- build & asset pipeline
    release.sh                     <- full release automation
    create-dmg.sh                  <- DMG packaging
    brazilian-butt-lift.py         <- butt frame extractor
    sound-check.py                 <- sound asset manager
    shuffle_segments.py            <- silence-based audio splitting
    waveform_samples.py            <- waveform amplitude computation
    generate-app-icon.py           <- app icon generator
    dmg-background.png             <- DMG installer background
    pyproject.toml
    .python-version (3.12)
    fractured-but-whole/           <- source GIFs
      Alien-Butt.gif ... vampire-butt.gif
    shuffle-sources/               <- original shuffle files (before splitting)
  pattiSpecialButton/              <- app source (Xcode auto-synced)
    AppDelegate.swift
    pattiSpecialButtonApp.swift
    ButtPickerView.swift
    AnimatedButtCell.swift
    FrameAnimator.swift
    ButtInfo.swift
    SoundInfo.swift
    SoundPickerView.swift
    SoundCell.swift
    WaveformView.swift
    Constants.swift
    TouchBarParade.swift
    CreditsView.swift
    Info.plist                     <- Sparkle keys (SUFeedURL, SUPublicEDKey)
    pattiSpecialButton.entitlements
    Assets.xcassets/
  docs/plans/                      <- design docs
```

## Credits

- **Butt illustrations**: [Pablo Stanley](https://twitter.com/pablostanley) via [buttsss.com](https://www.buttsss.com/). Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **Fart sound**: [jixolros on freesound.org](https://freesound.org/people/jixolros/).

## Code comments

Add comments only where the code's intent isn't obvious from reading it. Each comment should explain WHY this approach was chosen — not what the code does. Comment on: workarounds, non-obvious constraints, business logic rationale, and decisions where an alternative approach was deliberately rejected. Never restate what the code already says.

## Build & release

- macOS 12.0 deployment target, Swift 5
- App Sandbox **disabled** (`com.apple.security.app-sandbox` = false). See "Sandbox" section below.
- Bundle ID: `com.pattiVoice.pattiSpecialButton`
- Signing: ad-hoc (local/friends distribution). Developer ID + notarization required for public release.
- Xcode scheme: `pattiSpecialButton` (the only scheme). Debug for development, Release for distribution.
- Universal Binary: `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO`

### Versioning

Two fields, both set manually in Xcode (target → General → Identity) before releasing:
- **Version** (`MARKETING_VERSION`): Dotted string like `1.0`, `1.1`, `2.0`. Shown to users. Two-part only.
- **Build** (`CURRENT_PROJECT_VERSION`): Integer like `1`, `2`, `3`. Increments by 1 every release. Sparkle uses this to compare updates (`sparkle:version`). Independent of Version — when Version goes from `1.1` to `2.0`, Build just goes from `2` to `3`.

### Release workflow

1. Commit your code changes (normal development)
2. Bump Version and Build in Xcode (target → General → Identity)
3. `./scripts/release.sh` — does everything: build, DMG, sign, appcast, commit, tag, push, GitHub Release upload

Use `--skip-build` to repackage without rebuilding.

### Sparkle auto-updates

- Framework: Sparkle 2.9.0 via Swift Package Manager
- Feed URL: `https://raw.githubusercontent.com/Kristjan93/patti-special-button/main/appcast.xml`
- Signing: EdDSA (Ed25519). Private key in Keychain under account `patti-special-button`.
- Public key in `pattiSpecialButton/Info.plist` (`SUPublicEDKey`).
- `SUFeedURL` and `SUPublicEDKey` live in a supplementary `Info.plist` (not `INFOPLIST_KEY_` build settings, which silently drop custom keys).
- Sign DMGs with: `sign_update MyApp.dmg --account patti-special-button`

### Sandbox

The App Sandbox is **off** for now. Sparkle's installer needs to replace the app bundle on disk, which the sandbox blocks. Sparkle supports sandboxed updates via an XPC installer service, but that requires proper code signing with a Developer ID certificate — not ad-hoc.

**Re-enable the sandbox when**: you get a Developer ID and set up Sparkle's XPC installer (see Sparkle docs on sandboxed apps). Also required for Mac App Store distribution. To re-enable: set `com.apple.security.app-sandbox` to `true` in `pattiSpecialButton.entitlements` and add back `com.apple.security.network.client`.

### DMG packaging

`scripts/create-dmg.sh` — reads version from the built app's Info.plist (not hardcoded). Uses `create-dmg` (brew) with a custom background image. Output: `PattiSpecialButton-v{VERSION}.dmg` in project root.

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/release.sh` | Full release automation: build → DMG → sign → appcast → commit → tag → push → GitHub Release |
| `scripts/create-dmg.sh` | DMG packaging with drag-to-Applications layout |
| `scripts/brazilian-butt-lift.py` | GIF → RGBA PNG frame extraction |
| `scripts/sound-check.py` | Sound format conversion, splitting, waveform computation |
| `scripts/generate-app-icon.py` | App icon generation from butt GIF frame |

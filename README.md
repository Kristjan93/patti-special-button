# PattiSpecialButton

A macOS menu bar app. A wiggling animated butt lives in the menu bar and plays a fart sound when clicked. Choose from 47 different butt icons by Pablo Stanley.

## [Download the latest release](https://github.com/Kristjan93/patti-special-button/releases/latest)

## Features

- **Animated menu bar icon** — a butt that wiggles continuously (variable frame timing from source GIFs)
- **Left-click** plays the selected sound once to completion
- **Right-click** opens a context menu: Change Icon, Change Sound, Icon Size, Display Mode, Credits, Check for Updates, Quit
- **47 butt icons** in a picker grid with arrow-key preview and three display modes (Stencil, Original, Outline)
- **12 sounds** including shuffle sounds that play segments in round-robin order
- **Auto-updates** via Sparkle 2 with EdDSA-signed DMGs
- **Pure menu bar app** — no Dock icon, no main window

## Requirements

- macOS 12.0+
- Xcode 15+ (to build)

## Quick Start

```bash
git clone https://github.com/Kristjan93/patti-special-button.git
cd patti-special-button
open pattiSpecialButton.xcodeproj
# Build & Run (Cmd+R)
```

## Building the App

### Key concepts

An Xcode **project** (`.xcodeproj`) contains all source files, settings, and dependencies. Inside the project, a **scheme** defines what to build and how. This project has one scheme: `pattiSpecialButton`. A scheme picks a **configuration** — think of it as a preset:

| Configuration | What it does | When to use |
|---------------|-------------|-------------|
| **Debug** | No optimizations, includes debug symbols, fast builds | Day-to-day development (Cmd+R in Xcode) |
| **Release** | Optimized, stripped, smaller binary | Distributing to users |

### Building in Xcode (the easy way)

1. Open `pattiSpecialButton.xcodeproj`
2. Make sure the scheme `pattiSpecialButton` is selected in the toolbar (top-left, next to the play button)
3. **Cmd+R** — builds Debug and runs the app
4. **Cmd+B** — builds without running
5. To build Release: menu bar → Product → Scheme → Edit Scheme → Run → Build Configuration → Release

### Building from the terminal

```bash
# Debug build (single architecture, fast)
xcodebuild -scheme pattiSpecialButton -configuration Debug

# Release build — Universal Binary (runs on both Intel and Apple Silicon Macs)
xcodebuild -scheme pattiSpecialButton -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO
```

`ARCHS="arm64 x86_64"` produces a fat binary for both chip architectures.
`ONLY_ACTIVE_ARCH=NO` tells Xcode to build both instead of just your Mac's architecture.

The built `.app` lands in `DerivedData` (Xcode's build cache), or in `build/` if you add `-derivedDataPath build`.

## Build Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                     1. ASSET PIPELINE (one-time)                   │
│                                                                    │
│  GIF files (512×512)              Audio files (WAV/MP3)            │
│  scripts/fractured-but-whole/     sounds/                          │
│         │                                │                         │
│         ▼                                ▼                         │
│  brazilian-butt-lift.py           sound-check.py                   │
│  (Pillow, uv run)                 (pydub, ffmpeg, uv run)         │
│         │                                │                         │
│         ▼                                ▼                         │
│  ButtFrames/                      sounds/                          │
│  ├── manifest.json                ├── sounds-manifest.json         │
│  ├── alien-butt/                  ├── dry-fart.mp3                 │
│  │   ├── frame_00.png (160×160)   ├── shuffle_*_00.wav             │
│  │   └── ...                      └── ...                          │
│  └── ... (47 butts, 458 frames)       (10 regular + 2 shuffle)    │
│                                                                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │ Committed to repo as Xcode folder references
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     2. XCODE BUILD                                 │
│                                                                    │
│  Scheme: pattiSpecialButton                                        │
│  Config: Debug (dev) or Release (distribution)                     │
│                                                                    │
│  Inputs:                                                           │
│  ├── Swift sources (AppDelegate, FrameAnimator, pickers, ...)      │
│  ├── Info.plist (Sparkle keys: SUFeedURL, SUPublicEDKey)           │
│  ├── Entitlements (sandbox + network.client)                       │
│  ├── Sparkle 2.9.0 (Swift Package, fetched automatically)         │
│  ├── ButtFrames/ + sounds/ (copied into app bundle as-is)         │
│  └── Assets.xcassets (app icon)                                    │
│                                                                    │
│  Output: pattiSpecialButton.app                                    │
│                                                                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     3. DMG PACKAGING                               │
│                                                                    │
│  ./scripts/create-dmg.sh                                           │
│  ├── Finds the .app from the build output                          │
│  ├── Reads version from the app's Info.plist (no hardcoded ver)    │
│  └── Produces a drag-to-Applications DMG with background image    │
│                                                                    │
│  Output: PattiSpecialButton-v{VERSION}.dmg                         │
│                                                                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     4. SIGN + PUBLISH                              │
│                                                                    │
│  sign_update signs the DMG with the Sparkle EdDSA private key      │
│  (stored in Keychain as account "patti-special-button")             │
│                                                                    │
│  The signature goes into appcast.xml — an RSS feed that tells      │
│  Sparkle "here's a new version, here's the download URL, here's    │
│  the cryptographic proof that it's legit"                          │
│                                                                    │
│  Upload DMG to GitHub Releases, push appcast.xml to main.          │
│  Running apps check the feed on launch and offer the update.       │
│                                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Releasing a Feature

Example: you just added a new sound. Here's everything from start to finish.

### 1. Write your code and test it

Work normally. Edit files, test with Cmd+R in Xcode, commit when things work:

```bash
git add pattiSpecialButton/AppDelegate.swift sounds/new-fart.wav
git commit -m "Add new fart sound"
```

You can make as many commits as you want. This is just normal development.

### 2. Bump the version numbers in Xcode

When your feature is done and you want to ship it:

1. In Xcode, look at the **left sidebar**. You'll see a blue app icon labeled **pattiSpecialButton** — click it
2. In the middle panel, under **TARGETS**, click **pattiSpecialButton**
3. You should be on the **General** tab (if not, click it)
4. Right at the top there's an **Identity** section with two fields:

```
┌─────────────────────────────────────────────┐
│ Identity                                    │
│                                             │
│ Version    [ 1.0 ]  ← change this to 1.1   │
│ Build      [ 1   ]  ← change this to 2     │
│                                             │
└─────────────────────────────────────────────┘
```

**Version** is what users see in the update dialog ("Version 1.1 is available"). Pick whatever feels right — `1.1`, `1.2`, `2.0`.

**Build** is a counter that goes up by 1 every time you release. Users never see it. Sparkle uses it to decide "is this newer?" If Build says `2` and the user has `1`, Sparkle knows to offer the update.

### 3. Run the release script

From the project root folder (where the `.xcodeproj` is):

```bash
./scripts/release.sh
```

This does everything automatically:
- Builds the app
- Packages it into a DMG
- Signs the DMG
- Updates `appcast.xml` (the update feed)
- Commits and tags the release
- Pushes to GitHub
- Creates a GitHub Release and uploads the DMG

When it's done, it's done. Users with the app installed will see an update prompt on their next launch.

### How auto-updates reach users

1. User launches the app (or clicks "Check for Updates")
2. Sparkle fetches `appcast.xml` from GitHub (`SUFeedURL` in Info.plist)
3. Sparkle compares the build number in the feed vs the running app
4. If newer: shows an update dialog with the version and release notes
5. User clicks "Install" → Sparkle downloads the DMG
6. Sparkle verifies the EdDSA signature matches `SUPublicEDKey`
7. If valid: replaces the app and relaunches. If tampered: rejects the update.

## Asset Pipeline

### Adding a new butt icon

```bash
# Drop GIF into source folder
cp MyButt.gif scripts/fractured-but-whole/

# Extract frames (160×160 RGBA PNGs + manifest)
cd scripts && uv run brazilian-butt-lift.py

# Build in Xcode — folder reference picks up changes automatically
```

### Adding a new sound

```bash
# Drop audio file into sounds/
cp my-sound.wav sounds/

# Process (converts formats, computes waveforms, updates manifest)
cd scripts && uv run sound-check.py

# Edit sounds/sounds-manifest.json to set display name and category
# Build in Xcode
```

### Adding a shuffle sound

Prefix the file with `shuffle_` — the script splits it into segments at silence boundaries:

```bash
cp shuffle_my-collection.wav sounds/
cd scripts && uv run sound-check.py
# Original moves to scripts/shuffle-sources/, segments appear in sounds/
```

## Project Structure

```
pattiSpecialButton/
├── pattiSpecialButton/          # App source (Swift)
│   ├── AppDelegate.swift        # Core: menu bar, playback, popovers
│   ├── pattiSpecialButtonApp.swift
│   ├── ButtPickerView.swift     # Icon picker grid (SwiftUI)
│   ├── SoundPickerView.swift    # Sound picker grid (SwiftUI)
│   ├── FrameAnimator.swift      # Animation driver (DispatchSourceTimer)
│   ├── Constants.swift          # Shared constants, enums, defaults
│   ├── TouchBarParade.swift     # Touch Bar butt scrubber
│   ├── Info.plist               # Sparkle keys (SUFeedURL, SUPublicEDKey)
│   └── ...
├── ButtFrames/                  # 47 animated butt icon sets (folder ref)
├── sounds/                      # 12 sound files + manifest (folder ref)
├── scripts/
│   ├── release.sh               # Full release: build → DMG → sign → appcast
│   ├── create-dmg.sh            # DMG packaging (called by release.sh)
│   ├── brazilian-butt-lift.py   # GIF → RGBA PNG frames
│   ├── sound-check.py           # Sound processing + manifest
│   └── dmg-background.png       # DMG installer background
├── appcast.xml                  # Sparkle update feed
├── docs/plans/                  # Design documents
└── pattiSpecialButton.xcodeproj
```

## Build Dependencies

| Tool | Install | Purpose |
|------|---------|---------|
| Xcode 15+ | Mac App Store | Build the app |
| uv | `brew install uv` | Python package runner (asset scripts) |
| ffmpeg | `brew install ffmpeg` | Audio format conversion |
| create-dmg | `brew install create-dmg` | DMG packaging |
| gh | `brew install gh` | GitHub Releases upload |

Python dependencies (`scripts/pyproject.toml`): Pillow (image processing), pydub (audio processing).

## Credits

- **Butt illustrations**: [Pablo Stanley](https://twitter.com/pablostanley) via [buttsss.com](https://www.buttsss.com/). Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **Fart sounds**: Various artists on [freesound.org](https://freesound.org/).

## License

MIT License (code). CC BY 4.0 (butt art by Pablo Stanley).

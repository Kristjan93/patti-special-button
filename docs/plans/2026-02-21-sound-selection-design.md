# Sound Selection Design

## Summary

Add a sound picker to the right-click menu ("Change Sound") that lets users choose which sound plays on click. Grid of waveform cards with play/stop preview, playback scrubber, and categorized sections.

## Data Model

### sounds-manifest.json

Lives in `sounds/` bundle folder. Array of sound entries:

```json
[
  {
    "id": "small-realpoots",
    "name": "Small Realpoots",
    "category": "farts",
    "file": "556505__jixolros__small-realpoots105-110",
    "ext": "wav"
  },
  {
    "id": "dry-fart",
    "name": "Dry Toot",
    "category": "novelty",
    "file": "dry-fart",
    "ext": "mp3"
  }
]
```

- `id`: unique identifier, used in UserDefaults
- `name`: short, fun display name (e.g. "McFart", not the raw filename)
- `category`: grouping key, compared case-insensitively
- `file`: filename without extension (for Bundle.main.url lookup)
- `ext`: file extension ("wav" or "mp3")

### SoundInfo struct

New file `SoundInfo.swift`, mirrors `ButtInfo`. Decodable with all manifest fields. Computed property for bundle URL.

### Constants.swift additions

- `Defaults.selectedSoundIdKey` — UserDefaults key for selected sound
- `Defaults.defaultSoundId` — fallback sound id
- `Assets.soundsDir` — bundle folder name
- `Assets.soundsManifestFile` — manifest filename

### Supported formats

WAV and MP3 only. FLAC is not supported by AVAudioPlayer on macOS.

## UI Design

### Popover

- Opens from "Change Sound" right-click menu item
- Same pattern as icon picker: NSPopover, `.transient` behavior, `makeKey()` for focus
- 2-column grid
- Popover sizes to fit all content (no scrolling)
- Long names truncated for now (marquee/ticker text is a future enhancement)

### Categories

- Sounds grouped by `category` field, compared case-insensitively
- Bold category header label above each group
- Divider/separator line between groups
- User-defined categories supported (manifest drives grouping)

### Card Layout

```
┌─────────────────────┐
│ ▶ ▮▮▯▯▮▮▯▮▮▯▮▮▯▮▮  │  play/stop button + waveform bars with scrubber
│   Dry Toot           │  display name
│   dry-fart.mp3       │  filename (tiny, muted)
└─────────────────────┘
```

- Play/stop button: small toggle on the left
- Waveform bars: ~25 vertical rectangles sampled from audio amplitude. Played portion in accent color, unplayed in muted gray. Scrubber sweeps as audio plays.
- Display name: primary label, medium weight
- Filename with extension: secondary label, small and muted
- Selection state: checkmark badge (same as butt picker)
- Focus state: blue accent ring (same as butt picker)

### Waveform Rendering

- Sampled at picker open time using `AVAudioFile` + `AVAudioPCMBuffer` (macOS 10.10+)
- Downsample to ~25 amplitude values per sound
- Drawn as SwiftUI `Rectangle`s
- Scrubber progress tracked via Timer polling `AVAudioPlayer.currentTime / duration`
- Samples cached so repeat opens are instant

## Interaction Model

| Action | Result |
|--------|--------|
| Click card | Selects sound, persists to UserDefaults |
| Click play button | Toggles preview playback |
| Space | Play/pause focused sound |
| Arrow keys | Move focus between cards |
| Enter | Select focused sound + close popover |
| Escape / click outside | Close, revert to committed selection |
| Play a new sound | Stops any currently playing sound first |

One sound at a time — starting a new preview stops the previous one.

Keyboard handling via `NSEvent.addLocalMonitorForEvents` (macOS 12 compatible).

## Architecture

### New files

- `SoundInfo.swift` — Decodable struct for manifest entries
- `SoundPickerView.swift` — SwiftUI grid view with categories and keyboard nav
- `SoundCell.swift` — Individual card: waveform, play/stop, labels, selection state
- `WaveformView.swift` — SwiftUI view that draws amplitude bars with playback scrubber
- `sounds/sounds-manifest.json` — Sound metadata

### Changes to existing files

- `Constants.swift` — New keys in `Defaults`, `Assets`, and `Layout`
- `AppDelegate.swift` — "Change Sound" menu item, sound picker popover lifecycle, load selected sound from UserDefaults (replacing hardcoded file), space key in keyboard monitor

### Communication pattern

Same as icon picker: NotificationCenter posts between SwiftUI views and AppDelegate. No direct references.

### Sound loading

AppDelegate reads `selectedSoundIdKey` from UserDefaults, looks up the SoundInfo, and passes the bundle URL to AVAudioPlayer in `startSound()`. The `withExtension` parameter comes from the manifest's `ext` field instead of being hardcoded.

## Sounds

11 files in `sounds/`:

| File | Format | Size |
|------|--------|------|
| 556505__jixolros__small-realpoots105-110.wav | WAV | 696K |
| 27136__zippi1__fart3.wav | WAV | 70K |
| 391468__stereostory__quack_fart_noise_44k.wav | WAV | 30K |
| 104183__ekokubza123__punch.wav | WAV | 205K |
| 204805__ezcah__spanking.wav | WAV | 788K |
| 326143__mackaffee__fart.mp3 | MP3 | 10K |
| dramatic-fart_f8Sw6fv.mp3 | MP3 | 247K |
| dry-fart.mp3 | MP3 | 1.7K |
| fart-meme-sound.mp3 | MP3 | 31K |
| maro-jump-sound-effect_1.mp3 | MP3 | 14K |
| perfect-fart.mp3 | MP3 | 5.9K |
| studio-audience-awwww-sound-fx.mp3 | MP3 | 47K |

Categories and display names to be assigned by MASTER when writing the manifest.

## macOS 12 Compatibility

All APIs used are macOS 12 safe:
- AVAudioFile, AVAudioPCMBuffer (macOS 10.10+)
- AVAudioPlayer (macOS 10.7+)
- NSPopover, NSEvent.addLocalMonitorForEvents (pre-macOS 12)
- SwiftUI LazyVGrid, @AppStorage (macOS 12+)
- No `.onKeyPress` (macOS 14+) — using NSEvent monitor instead

## Future Enhancements

- Marquee/ticker text for long sound names
- User-added custom sounds (drop file + update manifest)

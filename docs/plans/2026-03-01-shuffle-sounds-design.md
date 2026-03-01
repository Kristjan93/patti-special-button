# Shuffle Sounds

Multi-segment sounds that play one random segment per click instead of the full file.

## Problem

Some sound files (Spanking, Small Realpoots) contain multiple distinct sound events back-to-back. Playing the entire file on every click is too long and repetitive. Users should hear one individual sound per click, cycled through in a shuffled order.

## Design

### Concept

Sounds whose filenames start with `shuffle_` are multi-segment sounds. A Python script detects silence gaps, splits them into individual segment files, and writes the segment list into the manifest. The Swift app reads the manifest and plays segments in a round-robin shuffle order (all segments heard once before any repeat).

### Build-Time Pipeline (Python)

**New: `scripts/shuffle_segments.py`** — Silence detection and splitting module.

- Accepts an audio file path, returns list of segment file paths
- Uses `pydub` to detect silence gaps (configurable: silence threshold dB, min silence duration ms, min segment length ms, boundary padding ms)
- Splits audio at silence boundaries into numbered WAV files: `shuffle_spanking_01.wav`, `shuffle_spanking_02.wav`, etc.
- Segment naming: `shuffle_<clean-name>_<NN>.wav`

**New: `scripts/waveform_samples.py`** — Waveform amplitude extraction module.

- Reads any audio file, computes 25 normalized amplitude floats (0.0-1.0)
- Same algorithm as the current Swift `WaveformSampler` but in Python
- Replaces all runtime waveform computation — used for ALL sounds, not just shuffle

**Updated: `scripts/sound-check.py`** — Integrates both modules.

Pipeline order:
1. Scan `sounds/` for audio files (existing behavior)
2. Convert unsupported formats via ffmpeg (existing behavior)
3. **New:** Detect `shuffle_*` files, run `shuffle_segments.py` on each
4. **New:** Move original `shuffle_*` source files to `scripts/shuffle-sources/` (preserved for re-running)
5. **New:** Compute `waveform_samples.py` for every sound file (regular and shuffle segments' source)
6. Build manifest with new fields: `waveform` for all sounds, `shuffle` + `segments` for shuffle sounds
7. Write manifest (existing behavior)

**Updated: `scripts/requirements.txt`** — Add `pydub`.

### Manifest Format

Regular sound gains `waveform`:

```json
{
  "id": "perfect-fart",
  "name": "Perfect Fart",
  "category": "farts",
  "file": "perfect-fart",
  "ext": "mp3",
  "waveform": [0.12, 0.45, 0.78, 0.23, 0.56, 0.89, 0.34, 0.67, 0.12, 0.45, 0.78, 0.23, 0.56, 0.89, 0.34, 0.67, 0.12, 0.45, 0.78, 0.23, 0.56, 0.89, 0.34, 0.67, 0.12]
}
```

Shuffle sound has `shuffle`, `segments`, `waveform` (no top-level `file`/`ext`):

```json
{
  "id": "spanking",
  "name": "Spanking",
  "category": "novelty",
  "shuffle": true,
  "waveform": [0.34, 0.67, 0.91, 0.45, 0.23, 0.78, 0.56, 0.12, 0.89, 0.34, 0.67, 0.91, 0.45, 0.23, 0.78, 0.56, 0.12, 0.89, 0.34, 0.67, 0.91, 0.45, 0.23, 0.78, 0.56],
  "segments": [
    {"file": "shuffle_spanking_01", "ext": "wav"},
    {"file": "shuffle_spanking_02", "ext": "wav"},
    {"file": "shuffle_spanking_03", "ext": "wav"}
  ]
}
```

### Runtime (Swift)

**`SoundInfo.swift`** — New types and optional fields:

```swift
struct SoundSegment: Codable {
    let file: String
    let ext: String

    var bundleURL: URL? {
        Bundle.main.url(forResource: file, withExtension: ext,
                       subdirectory: Assets.soundsDir)
    }
}

struct SoundInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let file: String?        // nil for shuffle sounds
    let ext: String?         // nil for shuffle sounds
    let shuffle: Bool?
    let waveform: [Float]?
    let segments: [SoundSegment]?

    var isShuffle: Bool { shuffle == true && !(segments?.isEmpty ?? true) }

    var bundleURL: URL? {
        guard let file, let ext else { return nil }
        return Bundle.main.url(forResource: file, withExtension: ext,
                              subdirectory: Assets.soundsDir)
    }

    var displayFilename: String {
        guard let file, let ext else { return name }
        return "\(file).\(ext)"
    }
}
```

**`AppDelegate.swift`** — Round-robin shuffle playback:

```swift
// New state
private var shuffleQueue: [Int] = []
private var shuffleIndex: Int = 0
private var lastShuffleSoundId: String?

private func playSound() {
    guard let sound = soundLookup[currentSoundId] else { return }

    let url: URL?
    if sound.isShuffle, let segments = sound.segments, !segments.isEmpty {
        // Reset shuffle when switching sounds
        if lastShuffleSoundId != sound.id {
            lastShuffleSoundId = sound.id
            reshuffleQueue(count: segments.count)
        }
        // Reshuffle when exhausted
        if shuffleIndex >= shuffleQueue.count {
            reshuffleQueue(count: segments.count)
        }
        url = segments[shuffleQueue[shuffleIndex]].bundleURL
        shuffleIndex += 1
    } else {
        url = sound.bundleURL
    }

    guard let url else { return }
    // ... existing AVAudioPlayer code
}

private func reshuffleQueue(count: Int) {
    shuffleQueue = Array(0..<count).shuffled()
    shuffleIndex = 0
}
```

**`WaveformView.swift`** — Delete `WaveformSampler` enum entirely. `WaveformView` struct unchanged (already takes `[Float]`).

**`SoundPickerView.swift`** — Use `sound.waveform ?? []` instead of `WaveformSampler.sampleAudio(url:)`. For shuffle sound preview, pick a random segment's `bundleURL`.

**`SoundCell.swift`** — Add shuffle badge overlay:

```swift
.overlay(alignment: .bottomLeading) {
    if sound.isShuffle {
        Image(systemName: "shuffle")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(4)
    }
}
```

### File Renaming

Two source files get `shuffle_` prefix:

| Current filename | New filename |
|---|---|
| `204805__ezcah__spanking.wav` | `shuffle_204805__ezcah__spanking.wav` |
| `556505__jixolros__small-realpoots105-110.wav` | `shuffle_556505__jixolros__small-realpoots105-110.wav` |

After `sound-check.py` runs, the originals move to `scripts/shuffle-sources/` and `sounds/` contains only the split segments.

### Shuffle Playback Behavior

- **Round-robin shuffle**: All segments shuffled into random order. Each click plays the next. Once all segments played, reshuffle and start over.
- **State is in-memory only**: Resets on app relaunch or sound switch.
- **Preview in picker**: Space plays a random segment (not the full original).

### Sounds Affected

- **Spanking** (novelty) — ~788K WAV, multiple slap events with silence gaps
- **Small Realpoots** (farts) — ~681K WAV, multiple poot events with silence gaps

### Pitfalls and Mitigations

| Pitfall | Mitigation |
|---|---|
| Silence detection cuts too tight, clipping sound edges | Add configurable boundary padding (e.g. 50ms) around each detected segment |
| Different sounds have different noise floors | Tunable threshold per file if needed; sensible defaults first |
| `pydub` dependency adds complexity | `pydub` wraps ffmpeg which is already required for format conversion |
| `file`/`ext` becoming optional breaks existing `SoundInfo` consumers | Make fields optional with fallback computed properties; `bundleURL` returns nil for shuffle sounds |
| Waveform scrubber progress wrong during shuffle preview | Segment files are short, progress tracking works the same way per-file |
| `WaveformSampler` removal is a broader change | WaveformView itself is unchanged — only the data source changes from runtime computation to pre-computed manifest data |

## Implementation Order

1. Python: `waveform_samples.py` + integrate into `sound-check.py` for all sounds
2. Python: `shuffle_segments.py` + integrate into `sound-check.py` for `shuffle_*` files
3. Rename the two sound files, run `sound-check.py`
4. Swift: Update `SoundInfo` model with new optional fields
5. Swift: Replace `WaveformSampler` usage with manifest `waveform` data
6. Swift: Add shuffle playback to `AppDelegate.playSound()`
7. Swift: Add shuffle badge to `SoundCell`
8. Swift: Update `SoundPickerView` preview for shuffle sounds
9. Test: Verify round-robin shuffle, picker preview, waveform display

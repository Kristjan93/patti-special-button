# Known Issues & Improvements

Assessed 2026-02-23. Full code review — Swift best practices, performance, resource management.

## Medium Priority

### Sound picker `loadSamples()` blocks main thread
- `SoundPickerView.swift:213` — `loadSamples()` reads and decodes all audio files synchronously in `onAppear`
- With 12 short files it's ~20-50ms, but it blocks rendering of the picker popover on first open
- Fix: move decoding to a background queue, update `sampleCache` back on main

### Sound scrubber progress timer uses wrong RunLoop mode
- `SoundPickerView.swift:190` — `Timer.scheduledTimer` runs in `.default` RunLoop mode
- When the user scrolls the picker while a sound previews, the scrubber bar freezes until interaction ends
- Fix: add `RunLoop.main.add(timer, forMode: .common)` after scheduling

## Low Priority

### `popoverDidClose` cleanup is broader than necessary
- `AppDelegate.swift:345` — `committedButtId` and `committedSoundId` are both nilled regardless of which popover closed
- Not a bug today since icon/sound pickers are mutually exclusive and credits popover has no delegate
- Fragile if credits popover ever gets a delegate wired up
- Fix: scope the nil to the specific popover via `notification.object` identity check

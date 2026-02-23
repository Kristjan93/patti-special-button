# Future Improvements

## Async waveform sampling

`SoundPickerView.loadSamples()` reads all audio files and computes waveform amplitudes synchronously on the main thread during `onAppear`. With 12 short fart sounds this is imperceptible, but will cause a visible hang as the sound library grows (longer files, more sounds).

**Fix:** Dispatch `WaveformSampler.sampleAudio` to a background queue. Update `sampleCache` on main as results arrive. Cells show empty waveforms briefly, then fill in.

**Files:** `SoundPickerView.swift` (`loadSamples`), `WaveformView.swift` (`WaveformSampler`)

**Priority:** Low — only matters when the sound library grows significantly.

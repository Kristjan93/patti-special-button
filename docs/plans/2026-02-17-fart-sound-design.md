# Hold-to-Play Fart Sound

## Summary

Replace the system "Funk" sound with a fart sound WAV file. Playback starts on mouse-down and stops on mouse-up, with a minimum play duration so a quick click always produces a complete fart.

## Sound file

Use `/Downloads/556505__jixolros__small-realpoots105-110.wav` as-is (7.9s, 44.1kHz stereo, contains multiple short farts). Drop into the app bundle. No splitting or editing needed.

## Playback logic

1. **Mouse down** — start playing from the beginning
2. **Mouse up before minimum (~1.5s)** — let playback continue until minimum duration, then stop
3. **Mouse up after minimum** — stop immediately
4. **Reach end of file while holding** — loop back to start (infinite loop)

## Code changes

All in `AppDelegate.swift`:

- Replace `NSSound` with `AVAudioPlayer`
- Switch click detection from `mouseUp` to tracking both `mouseDown` and `mouseUp`
- Add minimum-duration timer that prevents early cutoff
- Add the WAV file to the Xcode bundle

No changes to animation, right-click menu, or app structure.

## Sound source

File: `556505__jixolros__small-realpoots105-110.wav` from freesound.org.
License: check freesound.org listing for terms.

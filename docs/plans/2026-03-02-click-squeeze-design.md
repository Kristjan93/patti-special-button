# Click-to-Squeeze: Menu Bar Press Feedback

## Summary

Add visual feedback when the user left-clicks the menu bar butt. The icon briefly shrinks to 80% size for ~200ms ("squeeze"), then snaps back. The wiggle animation continues uninterrupted throughout.

## Motivation

Currently, left-clicking the butt plays a fart sound but provides no visual feedback. The icon keeps wiggling identically before, during, and after the click. A subtle squeeze gives the icon a tactile, button-like feel without being gimmicky.

## Behavior

1. User left-clicks the menu bar butt
2. Sound plays (unchanged)
3. Icon immediately renders at 80% of current icon size
4. After ~200ms, icon returns to full size
5. Wiggle animation runs continuously — no pause or interruption

The squeeze is a size change only. The animation keeps its normal frame rate and per-frame timing. Rapid clicks restart the squeeze timer (the icon stays small until 200ms after the last click).

## Implementation

### AppDelegate changes

- Add `isPressed: Bool` flag (default `false`)
- Add `pressResetWork: DispatchWorkItem?` to track the pending reset
- In `playSound()`: set `isPressed = true`, cancel any pending reset, schedule a new `DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)` to set `isPressed = false`
- In the Combine subscriber that updates the status bar button image: read `isPressed` to determine the render size — 80% of normal if pressed, 100% otherwise
- The size calculation feeds into the same `DisplayMode.processFrame(_:size:)` path

### What doesn't change

- Right-click / context menu behavior
- `FrameAnimator` — no changes to animation timing or frame loading
- `DisplayMode.processFrame` — already accepts a `size` parameter
- Sound playback logic
- Picker views

## Future: Per-Butt Press Frames

The system is designed to extend to custom per-butt reactions:

- Check for `ButtFrames/<id>/press_00.png` (etc.) at load time
- If press frames exist, play those on click instead of the scale squeeze
- If not, fall back to universal squeeze
- Per-butt frames can be added one butt at a time with no code changes

Not implemented in this iteration — universal squeeze only.

## Design principles

- **Subtle**: The squeeze is barely noticeable if you're not looking. That's the point.
- **Professional**: Mimics physical button feedback, not a cartoon effect.
- **Reusable**: The press state flag and extensibility hook serve any future press reaction.
- **Non-disruptive**: Animation never pauses, no flicker, no layout shift.

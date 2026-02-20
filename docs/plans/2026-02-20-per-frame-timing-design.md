# Per-Frame Timing

Approved 2026-02-20. Adds per-frame animation delays from source GIFs and unifies the two animation codepaths into a shared `FrameAnimator`.

## Problem

Every GIF stores per-frame delays. The Python pipeline discards them. Both `AppDelegate` and `FrameAnimator` use hardcoded 100ms. 21 of 47 butts play at the wrong speed. See `docs/gif-frame-timing.md` for the full timing audit.

## Approach

Shared animator (Approach A from brainstorming). One `FrameAnimator` drives both the menu bar icon and the picker grid previews. Per-frame timing comes from the manifest, extracted at pipeline time.

## Changes

### 1. Python pipeline (`brazilian-butt-lift.py`)

After each `img.seek(i)`, read `img.info.get('duration', 100)` and collect into a list. Add `frameDelays` to each manifest entry:

```json
{"id": "magic-butt", "name": "Magic Butt", "frameCount": 27, "frameDelays": [100,100,...,1000,100,...]}
```

Every butt gets an explicit array (even uniform-100ms butts). Machine-generated manifest, no readability cost, no optional handling in Swift.

**Vampire fix**: Delete `vampire-butt.gif` (static, 1 frame). Rename `vampire.gif` to `vampire-butt.gif`.

### 2. Data model (`ButtInfo.swift`)

Add `frameDelays: [Int]` (milliseconds per frame) to `ButtInfo`.

### 3. `FrameAnimator` refactor

Becomes the single animation driver for both AppDelegate and picker cells.

**Init**: `init(buttInfo: ButtInfo)`. Loads frames from the bundle, reads `frameDelays` from `ButtInfo`.

**Timer**: `DispatchSourceTimer` on main queue (replaces `Timer`). After each frame advance, reschedules with the next frame's delay. This gives per-frame timing and RunLoop independence.

**Public interface**:
- `frames: [NSImage]` (read-only) — loaded frame images
- `@Published var currentFrameIndex: Int` — drives Combine subscribers and SwiftUI views
- `var currentFrame: NSImage?` (computed) — convenience for SwiftUI
- `start()` / `stop()` — animation control

**Edge cases**:
- Single-frame butts: `start()` is a no-op when `frames.count <= 1`.
- Zero-delay clamp: any delay < 10ms floors to 10ms.
- Cleanup: `deinit` cancels the `DispatchSourceTimer`.

### 4. `AppDelegate` changes

Stops managing frames and animation directly.

**New state**:
- `FrameAnimator` instance (created per butt)
- `menuBarFrames: [NSImage]` — copies of animator's frames configured for menu bar (20x20, `isTemplate = true`)
- `AnyCancellable?` for the Combine subscription
- `[String: ButtInfo]` lookup dict (loaded once from manifest)

**On launch and butt switch**:
1. Look up `ButtInfo` from manifest.
2. Create `FrameAnimator(buttInfo:)`.
3. Build `menuBarFrames` from `animator.frames` (copy, set size + template).
4. Subscribe to `animator.$currentFrameIndex`: update `button.image = menuBarFrames[index]`.
5. Call `animator.start()`.

**Removed**: `frameImages`, `currentFrameIndex`, `frameDuration`, `animationTimer`, `loadFrameImages()`, `startAnimation()`, `advanceFrame()`.

### 5. `AnimatedButtCell` / picker changes

Minimal: change `FrameAnimator(buttId:)` to `FrameAnimator(buttInfo:)`. The cell already has the `ButtInfo` instance. Everything else (SwiftUI binding to `currentFrame`, start/stop lifecycle) stays the same.

## Files touched

| File | Change |
|------|--------|
| `buttsss/brazilian-butt-lift.py` | Extract frame delays, add to manifest |
| `buttsss/fractured-but-whole/` | Vampire fix (delete static, rename animated) |
| `ButtFrames/manifest.json` | Regenerated with `frameDelays` |
| `pattiSpecialButton/ButtInfo.swift` | Add `frameDelays: [Int]` |
| `pattiSpecialButton/FrameAnimator.swift` | Rewrite: `ButtInfo` init, `DispatchSourceTimer`, per-frame rescheduling |
| `pattiSpecialButton/AppDelegate.swift` | Remove animation logic, add Combine subscription to shared `FrameAnimator` |
| `pattiSpecialButton/AnimatedButtCell.swift` | Pass `ButtInfo` to `FrameAnimator` init |

## Build sequence

1. Python: vampire fix + re-run pipeline (generates new manifest + frames)
2. Swift: `ButtInfo` (data model first)
3. Swift: `FrameAnimator` (new implementation)
4. Swift: `AppDelegate` (consume new FrameAnimator)
5. Swift: `AnimatedButtCell` (trivial init change)
6. Build + verify all 47 butts animate correctly

# Touch Bar Butt Parade

## Summary

When the icon picker or sound picker popover is open, the Touch Bar displays a parade of animated butts. Starting from the currently selected butt and continuing forward through the manifest order (wrapping circularly to index 0), as many butts as fit are shown at maximum size with spacing between them. Purely decorative. Follows the current display mode (Fill/Outline/Original). Completely isolated from the main app logic.

## Context

- Touch Bar hardware discontinued October 2023 (last Mac: 13-inch M2 MacBook Pro)
- NSTouchBar API is **not** formally deprecated in macOS 15 SDK
- Functional on macOS 15 and 26 (Tahoe), though buggy on Tahoe
- Expected framework support through ~2030
- This is a fun novelty feature for users with 2016-2022 MacBook Pros

## Architecture

### One new file: `TouchBarParade.swift`

Everything lives in this file. The entire public interface is gated behind `@available(macOS 10.12.2, *)`. Integration with AppDelegate is two single-line calls.

### Why popover-contextual (not always-on)

Touch Bar items are discovered via the responder chain starting from the key window's first responder. As an LSUIElement app with no main window, there is no key window when only the menu bar icon is visible. When a picker popover is open, its internal NSWindow becomes key (we already call `makeKey()` on it), putting the popover's content view controller in the responder chain. This is the clean, supported path.

An always-on Touch Bar would require a hidden 1x1 NSWindow hack. Not worth it for a decorative feature.

## Visual layout

Touch Bar is 30pt tall (60px @2x). Each butt is rendered at **30x30pt** with **4pt spacing** between them.

```
Touch Bar (app region, variable width)
┌──────────────────────────────────────────────────────────────────┐
│  [butt]  [butt]  [butt]  [butt]  [butt]  [butt]  ...  [butt]  │
│  30x30   30x30   30x30   30x30   30x30   30x30         30x30   │
│       4pt    4pt    4pt    4pt    4pt    4pt                    │
└──────────────────────────────────────────────────────────────────┘
```

### Dynamic width calculation

The available Touch Bar width varies based on Control Strip configuration (collapsed, expanded, or hidden) and system items. The container view calculates how many butts fit in `layout()` based on `bounds.width`:

```
buttCount = floor((boundsWidth + spacing) / (buttSize + spacing))
```

If the available width changes (user toggles Control Strip), the view recalculates and adds or removes butt slots.

### Circular ordering

1. Load the full `[ButtInfo]` manifest array (47 butts, ordered)
2. Find the index of the currently selected butt id
3. Starting from that index, iterate forward through the array
4. When reaching the end, wrap to index 0
5. Continue until `buttCount` butts are placed

## Animation

Reuses `FrameAnimator` — the same class that drives the menu bar icon and picker cells. Each butt in the parade gets its own `FrameAnimator` instance, each with its own `DispatchSourceTimer` and per-frame delays. This matches the existing app pattern exactly.

At parade creation:
1. For each butt slot, create a `FrameAnimator(buttInfo:invertAlpha:)` where `invertAlpha` is true only for Fill mode
2. Process frames per display mode (same logic as `AppDelegate.loadButtById`):
   - **Fill**: Use `invertAlpha: true` in FrameAnimator init, set `isTemplate = true` on output frames
   - **Outline**: Use default FrameAnimator (no inversion), set `isTemplate = true`
   - **Original**: Use default FrameAnimator, composite each frame onto white, set `isTemplate = false`
3. Subscribe to each animator's `$currentFrameIndex` via Combine to update the corresponding `NSImageView.image`
4. Call `start()` on all animators

On dealloc, each `FrameAnimator.deinit` cancels its own timer automatically.

### Frame sizing

Source frames are 160x160 RGBA PNGs. For the Touch Bar, frames are resized to 30x30pt (60x60px @2x) at load time. With ~20 butts x ~10 frames average x 30x30pt, memory footprint is negligible.

## Display mode support

Reads `DisplayMode` from `UserDefaults` at parade creation time. The three modes produce different visuals:

| Mode | FrameAnimator init | Post-processing | isTemplate |
|------|-------------------|----------------|------------|
| Fill | `invertAlpha: true` | Size to 30x30pt | `true` |
| Outline | `invertAlpha: false` | Size to 30x30pt | `true` |
| Original | `invertAlpha: false` | Composite on white, size to 30x30pt | `false` |

Fill and Outline adapt to macOS light/dark theme via template rendering. Original shows black lines on white in both themes.

## Integration

### AppDelegate changes (minimal)

Two lines added, one in each popover method:

```swift
// In showIconPicker(), after popover.show():
if #available(macOS 10.12.2, *) {
    TouchBarParade.attach(to: popover, manifest: loadButtManifest(), lookup: buttLookup)
}

// In showSoundPicker(), after popover.show():
if #available(macOS 10.12.2, *) {
    TouchBarParade.attach(to: popover, manifest: loadButtManifest(), lookup: buttLookup)
}
```

### `TouchBarParade.attach(to:manifest:lookup:)` static method

1. Guards that the popover has a `contentViewController`
2. Creates a `TouchBarParade` instance
3. Wraps or swizzles the content view controller to provide a `NSTouchBar` via `makeTouchBar()` — implemented by subclassing `NSHostingController` with a `TouchBarHostingController` that overrides `makeTouchBar()` and delegates to the parade
4. Stores the parade as an associated object on the view controller (retains it for the popover's lifetime)
5. When the popover closes, the view controller is deallocated, the parade is released, all animators stop via `deinit`

**Alternative (simpler)**: Instead of subclassing NSHostingController, set `contentViewController.touchBar` directly after the popover is shown. NSTouchBar has a settable property on NSResponder. This avoids subclassing entirely.

### No changes to

- `FrameAnimator.swift` (used as-is)
- `ButtPickerView.swift`
- `SoundPickerView.swift`
- `Constants.swift`
- Any other existing file besides the two integration lines in AppDelegate

## Safety

| Risk | Mitigation |
|------|-----------|
| No Touch Bar hardware | `makeTouchBar()` is never called by the system if no Touch Bar exists. Zero overhead. |
| macOS < 10.12.2 | All code gated behind `@available(macOS 10.12.2, *)`. Our deployment target is macOS 12, so this is always available, but the gate is there for correctness. |
| Frame loading fails | `FrameAnimator` handles missing frames gracefully (returns empty `frames` array). `guard frames.count > 1` in `start()` means no timer is created for broken butts. Fewer butts in the parade, not a crash. |
| Touch Bar width is zero | `buttCount` calculation yields 0. No animators created. Empty Touch Bar. |
| Memory pressure | ~20 animators with small 30x30pt frames. Each animator's `deinit` cancels its timer. All released when popover closes. |
| Popover closed unexpectedly | Associated object is released with the view controller. `FrameAnimator.deinit` handles cleanup. |

The Touch Bar parade never touches: sound playback, menu bar icon, UserDefaults, status item, or any notification. It's read-only and decorative.

## Testing

- **Xcode Touch Bar simulator**: Window > Show Touch Bar (if available in Xcode 16)
- **Physical hardware**: Any 2016-2022 MacBook Pro
- **Code review**: The isolation means we can verify correctness by reading `TouchBarParade.swift` alone

## Constants

Add to `Constants.swift` under `Layout`:

```swift
static let touchBarButtSize: CGFloat = 30
static let touchBarButtSpacing: CGFloat = 4
```

## File summary

| File | Change |
|------|--------|
| `TouchBarParade.swift` | **New** — entire Touch Bar implementation |
| `AppDelegate.swift` | 2 lines added (one per popover method) |
| `Constants.swift` | 2 constants added to `Layout` |

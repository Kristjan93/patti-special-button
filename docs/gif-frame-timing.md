# GIF Frame Timing: Problem Analysis

Assessed 2026-02-20. Documents the frame timing gap in the asset pipeline and its impact on animation fidelity.

## The problem

Every GIF stores per-frame delay metadata (milliseconds per frame, in the Graphic Control Extension block). The Python pipeline (`brazilian-butt-lift.py`) extracts frames as PNGs but **discards all timing data**. Both `AppDelegate` and `FrameAnimator` use a hardcoded 100ms interval. 21 of 47 butts play at the wrong speed.

## GIF timing is per-frame, not FPS

GIF has no global "frames per second" setting. Each frame carries its own delay value in milliseconds. This means a single animation can have frames that hold for different durations — fast sections, dramatic pauses, and hold frames are all common.

## Measured impact across all 47 source GIFs

**26 butts at uniform 100ms** — play correctly by coincidence.

**8 butts at alternating 120/130ms** — play ~20-30% faster than intended:
- Business, CensoredButt, EasterBunny, EinsteinButt, GlassesButt, HairyButt, PabsButt, SmallButt, Sweaty-butt, ThunderButt

**7 butts with hold frames** — lose their animation character entirely:

| GIF | Intended timing | At 100ms | What's lost |
|-----|----------------|----------|-------------|
| Magic-Butt | Frame 20 holds 1000ms | 100ms | Dramatic pause (magic reveal) |
| Jeans-Butt | Frame 0: 500ms, frame 10: 1000ms | 100ms | Opening pose + pause |
| Werewolf-Putt | 500ms open, 1000ms mid-pause, 500ms close | 100ms | Storytelling rhythm |
| Shivering-butt | Last frame holds 500ms | 100ms | Shiver-then-pause cycle |
| seeing-butt | Every 3rd frame holds 500ms | 100ms | "Looking around" cadence |
| KeynoteButt | 1000ms per frame (slow slides) | 100ms | 10x too fast |
| UX-Designer-Butt | 250ms per frame | 100ms | 2.5x too fast |

**3 butts with opening emphasis** — lose their first-frame pause:
- Superhero-butt: first frame 200ms, rest 100ms
- frida-butthlo: first frame 200ms, rest 100ms
- vampire (6 frames at 80ms): plays 20% slower than intended

## Static GIF: vampire-butt

`vampire-butt.gif` is **not animated** — it has 1 frame, `is_animated=False`. It's the only non-animated source in the collection. The website (buttsss.com) lists only one "Vampire Butt"; we have two files:
- `vampire.gif` — 6 frames, animated (the real one)
- `vampire-butt.gif` — 1 frame, static (duplicate/broken)

**Fix**: delete `vampire-butt.gif`, rename `vampire.gif` to `vampire-butt.gif`.

## Where timing data is available

Pillow exposes per-frame delay after each `img.seek(i)` via `img.info.get('duration')` (returns milliseconds). This data is available at extraction time in `brazilian-butt-lift.py` but is currently not captured.

`NSBitmapImageRep.value(forProperty: .currentFrameDuration)` reads the same data at runtime from GIF files. The now-unused `GIFAnimator.swift` demonstrates this approach — but it requires shipping source GIFs in the bundle, which the Step 2 plan eliminates.

## Data: full timing dump

```
async-butt.gif:       6 frames  [100, 100, 100, 100, 100, 100]
Alien-Butt.gif:      16 frames  [100 x16]
bongo-butt.gif:      17 frames  [100 x17]
bouncing-butt-II.gif: 6 frames  [100 x6]
bouncy-butt.gif:      4 frames  [100 x4]
Business.gif:         4 frames  [130, 120, 130, 130]
CensoredButt.gif:     5 frames  [130, 120, 130, 120, 120]
clapping-butt.gif:    5 frames  [100 x5]
Cow-Butt.gif:         4 frames  [100 x4]
Diver-Butt.gif:      11 frames  [100 x11]
EasterBunny.gif:      4 frames  [130, 120, 130, 130]
EinsteinButt.gif:     5 frames  [130, 120, 130, 120, 120]
flaming-butt.gif:     3 frames  [100 x3]
flexing-butt.gif:     9 frames  [100 x9]
frankenstein-butt.gif:12 frames [100 x12]
frida-butthlo.gif:    4 frames  [200, 100, 100, 100]
GlassesButt.gif:      5 frames  [130, 120, 130, 120, 120]
HairyButt.gif:        5 frames  [130, 120, 130, 120, 120]
Heart-Eyes-Butt.gif:  6 frames  [100 x6]
inception-butt.gif:  17 frames  [100 x17]
infinite-butt.gif:    8 frames  [100 x8]
Jeans-Butt.gif:      16 frames  [500, 100x9, 1000, 100x5]
KeynoteButt.gif:      4 frames  [1000 x4]
kissing-butt.gif:    13 frames  [100 x13]
Magic-Butt.gif:      27 frames  [100x20, 1000, 100x6]
no-butt.gif:         10 frames  [100 x10]
PabsButt.gif:        21 frames  [130, 120, 130, 120 ... alternating]
pirate-butt.gif:     20 frames  [100 x20]
pointing-butt.gif:    6 frames  [100 x6]
Romantic-Butt.gif:   13 frames  [100 x13]
Samba-butt.gif:      20 frames  [100 x20]
seeing-butt.gif:     16 frames  [100, 100, 100, 500, 100, 100, 500, 100, 100, 500, 100, 100, 500, 100, 100, 500]
shiny-butt.gif:      15 frames  [100 x15]
Shivering-butt.gif:   7 frames  [100x6, 500]
SmallButt.gif:        5 frames  [130, 120, 130, 120, 120]
space-butt.gif:       9 frames  [100 x9]
Superhero-butt.gif:  22 frames  [200, 100x21]
Sweaty-butt.gif:      6 frames  [130, 120, 130, 120, 130, 130]
swinging-butt.gif:    7 frames  [100 x7]
ThunderButt.gif:      7 frames  [130, 120, 130, 120, 130, 120, 120]
triple-butt.gif:     10 frames  [100 x10]
underwater-butt.gif: 10 frames  [100 x10]
UX-Designer-Butt.gif: 5 frames  [250 x5]
vampire.gif:          6 frames  [80 x6]
vampire-butt.gif:     1 frame   [0] (static, not animated)
Werewolf-Putt.gif:   18 frames  [500, 100x8, 1000, 100x6, 500]
Zebra-butt.gif:       7 frames  [100 x7]
```

# Right-Click Discovery Hint

## Problem

Left-click plays a sound, right-click opens all settings. This is the opposite of most menu bar apps (where left-click = menu). Users who never right-click might think the app is just a fart button and never find the 47 butts, 12 sounds, and display modes.

## Solution

A small auto-dismissing popover appears near the menu bar icon on app launch. It shows up to 3 times across separate launches, then never again. If the user right-clicks at any point, it stops appearing immediately.

A permanent `statusItem.toolTip` provides a subtle fallback for users who hover.

## Behavior

### Show conditions

Show the popover on launch if **both** are true:
- `hintShowCount < 3` (integer, starts at 0)
- `hasRightClicked == false` (boolean, starts at false)

### Suppression triggers

Never show the popover again once **either** is true:
- The hint has been shown 3 times (across launches)
- The user has right-clicked at least once

### Timing

- Popover appears ~1.5 seconds after launch (after the status item is set up and visible)
- Auto-dismisses after 5 seconds
- Also dismisses on click outside (`.transient` behavior)

### Tracking

- Each time the popover appears, increment `hintShowCount`
- When `showContextMenu()` fires (right-click), set `hasRightClicked = true`

## The popover

- Small `NSPopover` with `.transient` behavior, shown relative to `statusItem.button`
- Minimal SwiftUI content: bold "Right-click for options", smaller subtitle "Change icon, sound, and more"
- No buttons, no close chrome — just text
- Matches native macOS popover appearance

## The tooltip

- `statusItem.toolTip = "Right-click for options"` — always set, regardless of hint state
- Shows on hover after system dwell time — completely native, zero custom UI

## UserDefaults keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hintShowCount` | Int | 0 | How many times the popover has been shown |
| `hasRightClicked` | Bool | false | Whether the user has ever opened the right-click menu |

## Where code lives

| Location | Change |
|----------|--------|
| `Constants.swift` | Add `hintShowCountKey` and `hasRightClickedKey` to `Defaults` |
| `AppDelegate.swift` | Hint check + popover show in `applicationDidFinishLaunching` (after status item setup) |
| `AppDelegate.swift` | Set `hasRightClicked = true` in `showContextMenu()` |
| `AppDelegate.swift` or new `HintPopoverView.swift` | Small SwiftUI view for the popover content |

## Auto-dismiss mechanism

- `DispatchQueue.main.asyncAfter(deadline: .now() + 5)` closes the popover
- If the popover is already closed (user clicked elsewhere or interacted), the close call is a no-op
- Same pattern as existing `triggerHighlight()` debounce

## Research: how other apps handle this

Most popular menu bar apps (Rectangle, Maccy, Ice, iStat Menus) dodge the problem by putting the menu on left-click. For apps with split click behavior, the common patterns are:

- **Tooltip only**: `statusItem.toolTip` — native but easy to miss
- **First-launch popover**: Small bubble near the icon, shown once or a few times — this is what we're doing
- **Apple TipKit**: Official feature discovery framework (macOS 14+ only, too new for our macOS 12 target)
- **Welcome window**: Full onboarding screen — overkill for a novelty app

The first-launch popover is the right balance of visibility and restraint.

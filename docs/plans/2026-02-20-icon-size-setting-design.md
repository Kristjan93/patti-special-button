# Icon Size Setting

Approved 2026-02-20. Adds a menu bar icon size setting to the right-click context menu.

## Feature

Three size options with Pablo Stanley energy names:

| Name | UserDefaults value | Points |
|------|-------------------|--------|
| Fun Size | `fun-size` | 20x20 |
| Regular Rump | `regular-rump` | 22x22 |
| Badonkadonk | `badonkadonk` | 24x24 |

Default: Fun Size.

## UI

NSMenu submenu in the right-click context menu. "Icon Size >" expands to show the three options with a checkmark on the current selection. Matches the native macOS menu pattern (like "Other Networks" in the Wi-Fi dropdown).

Initially explored placing a SwiftUI `Picker` at the top of the butt picker popover, but it cluttered the popover and didn't match the expected macOS interaction pattern. The context menu is the natural home for a setting like this.

## Data flow

`UserDefaults` key `"iconSize"`, default `"fun-size"`. AppDelegate reads it via `currentIconSize` computed property (maps string to CGFloat). `handleButtChange()` detects size changes alongside butt id changes and calls `loadButt()` to rebuild `menuBarFrames` with the new point size.

## Files touched

| File | Change |
|------|--------|
| `AppDelegate.swift` | Add `currentIconSize` computed property, "Icon Size" submenu in `showContextMenu()`, `selectIconSize(_:)` action, `lastLoadedIconSize` for change detection. Size used in `loadButt()` when building `menuBarFrames`. |

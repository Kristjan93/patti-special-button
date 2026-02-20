# Icon Size Setting

Approved 2026-02-20. Adds a menu bar icon size picker to the top of the butt picker popover.

## Feature

Three size options with Pablo Stanley energy names:

| Name | UserDefaults value | Points |
|------|-------------------|--------|
| Fun Size | `fun-size` | 20x20 |
| Regular Rump | `regular-rump` | 22x22 |
| Badonkadonk | `badonkadonk` | 24x24 |

Default: Fun Size.

## UI

SwiftUI `Picker` with `.menu` style, placed at the top of `ButtPickerView` above a `Divider()` and the scroll grid. Renders as a native `NSPopUpButton` dropdown showing the current size name.

## Data flow

Same pattern as butt selection: `@AppStorage("iconSize")` in `ButtPickerView`, default `"fun-size"`. AppDelegate observes `UserDefaults.didChangeNotification` and rebuilds `menuBarFrames` with the new point size when the value changes.

## Files touched

| File | Change |
|------|--------|
| `ButtPickerView.swift` | Add `@AppStorage("iconSize")` picker + `Divider()` above scroll view |
| `AppDelegate.swift` | Read `iconSize` from UserDefaults in `loadButt()`, map value to point size. Extend change detection to handle size-only changes (not just butt id changes). |

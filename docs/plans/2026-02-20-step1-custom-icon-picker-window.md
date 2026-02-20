# Step 1: Custom Icon Picker Window

## Goal

Replace the broken SwiftUI Settings scene with an AppKit-managed NSWindow. The `sendAction(Selector(("showSettingsWindow:")))` hack is blocked on macOS 14+ with the runtime error "Please use SettingsLink for opening the Settings scene." An NSWindow with NSHostingView gives us full control with zero bridging issues.

## Status: not started

## What changes

### `AppDelegate.swift`

- Add `private var iconPickerWindow: NSWindow?`
- New `showIconPicker()` method:
  - First call: create `NSWindow` (500x500, titled/closable/resizable) with `NSHostingView(rootView: ButtPickerView())`, center it, store reference
  - Subsequent calls: bring existing window to front
  - `NSApp.setActivationPolicy(.regular)` — Dock icon + Cmd+Tab appear
  - `NSApp.activate(ignoringOtherApps: true)` + `makeKeyAndOrderFront`
  - Observe `NSWindow.willCloseNotification` on this specific window → `NSApp.setActivationPolicy(.accessory)` (Dock icon disappears)
- Right-click context menu: rename "Preferences..." to **"Change Icon"**, wire to `showIconPicker()`
- `applicationShouldHandleReopen`: call `showIconPicker()` instead of `openSettings()`
- Delete `openSettings()`, `openSettingsFromMenu()`, and the `sendAction(Selector(...))` line
- Remove the old generic `settingsWindowWillClose` observer from `applicationDidFinishLaunching`
- Add `import SwiftUI` (for NSHostingView)

### `pattiSpecialButtonApp.swift`

- Revert `Settings { ButtPickerView() }` back to `Settings { EmptyView() }` (SwiftUI needs at least one Scene, but we don't use it)

### `ButtPickerView.swift`

- Temporarily replace grid content with `Text("TODO: Butt picker")` placeholder so we can verify the window works in isolation

## Done when

- [ ] Right-click the menu bar butt → "Change Icon" menu item appears
- [ ] Click "Change Icon" → a window titled "Change Icon" opens showing "TODO: Butt picker"
- [ ] The app appears in the Dock and Cmd+Tab while the window is open
- [ ] Close the window → Dock icon and Cmd+Tab entry disappear
- [ ] Re-launch app from Spotlight → the picker window opens again
- [ ] Left-click the butt still plays fart sound normally

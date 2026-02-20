# Step 1: Custom Icon Picker Window

## Goal

Replace the broken SwiftUI Settings scene with an AppKit-managed NSWindow. The `sendAction(Selector(("showSettingsWindow:")))` hack is blocked on macOS 14+ with the runtime error "Please use SettingsLink for opening the Settings scene." An NSWindow with NSHostingView gives us full control with zero bridging issues.

## Status: done

## What was built

### `AppDelegate.swift`

- Added `private var iconPickerWindow: NSWindow?`
- New `showIconPicker()` method:
  - First call: creates `NSWindow` (500x500, titled/closable/resizable, minSize 400x300) with `NSHostingView(rootView: ButtPickerView())`, stores reference
  - Subsequent calls: brings existing window to front
  - `NSApp.setActivationPolicy(.regular)` — Dock icon + Cmd+Tab appear
  - `NSApp.activate(ignoringOtherApps: true)` + `makeKeyAndOrderFront`
  - Sets `NSApp.applicationIconImage` to current butt frame as temp Dock icon
  - Observes `NSWindow.willCloseNotification` on this specific window → `NSApp.setActivationPolicy(.accessory)` (Dock icon disappears)
- New `positionWindowBelowStatusItem()` — centers window horizontally under the status item with 8pt padding, clamped to screen edges so it doesn't clip off the right side
- Right-click context menu: "Change Icon" item wired to `showIconPicker()`
- `applicationShouldHandleReopen`: calls `showIconPicker()`
- `UserDefaults.didChangeNotification` observer triggers `handleButtChange()` → `reloadButt()` to swap the menu bar icon at runtime
- Added `import SwiftUI` (for NSHostingView)

### `pattiSpecialButtonApp.swift`

- Settings scene reverted to `EmptyView()` (SwiftUI needs at least one Scene, but we don't use it)

### `ButtPickerView.swift`

- Placeholder `Text("TODO: Butt picker")` with flexible frame (resizable)

### Also added (scaffolding for Step 2)

- `ButtInfo.swift` — Codable struct with id, name, frameCount, gifFilename; `loadButtManifest()` function
- `GIFAnimator.swift` — ObservableObject for GIF animation (will be replaced by FrameAnimator in Step 2)
- `AnimatedButtCell.swift` — SwiftUI grid cell (will use FrameAnimator in Step 2)
- `ButtFrames/manifest.json` — added `gifFilename` field per butt (will be removed in Step 2)
- `buttsss/brazilian-butt-lift.py` — added `gifFilename` to manifest output
- Xcode project — added `fractured-but-whole` folder reference (will be removed in Step 2)

## Verified

- [x] Right-click the menu bar butt → "Change Icon" menu item appears
- [x] Click "Change Icon" → window titled "Change Icon" opens showing "TODO: Butt picker"
- [x] Window spawns centered below the menu bar icon, not clipping off screen
- [x] Window is resizable (min 400x300)
- [x] The app appears in the Dock and Cmd+Tab while the window is open
- [x] Dock icon shows current butt frame as placeholder
- [x] Close the window → Dock icon and Cmd+Tab entry disappear
- [x] Re-launch app from Spotlight → the picker window opens again
- [x] Left-click the butt still plays fart sound normally

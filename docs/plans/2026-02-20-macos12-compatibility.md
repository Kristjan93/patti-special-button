# macOS 12+ Compatibility Design

## Goal

Lower the deployment target from macOS 15.4 to macOS 12.0 (Monterey) so the app runs on Macs from 2021 onward.

## Incompatibilities

All three are in `ButtPickerView.swift` and require macOS 14+ (Sonoma):

| API | Location | Minimum macOS |
|-----|----------|---------------|
| `.onKeyPress()` | ButtPickerView.swift:39–43 | 14.0 |
| `KeyPress.Result` | ButtPickerView.swift:53, 65 | 14.0 |
| `.contentMargins(.vertical, 12)` | ButtPickerView.swift:36 | 14.0 |

Everything else (NSStatusItem, NSPopover, AVAudioPlayer, AppStorage, DispatchSourceTimer, FrameAnimator, AnimatedButtCell, StatusItemMouseView) is macOS 12 compatible.

## Approach: NSEvent monitor for keyboard navigation

Move keyboard handling from SwiftUI (`.onKeyPress`, macOS 14+) to an AppKit `NSEvent` local monitor (all macOS versions). Full keyboard navigation on every supported version, no feature degradation.

### Event flow

```
Key press → NSEvent.addLocalMonitorForEvents (AppDelegate)
         → NotificationCenter.post(.moveFocus / .confirmAndClose)
         → ButtPickerView receives via .onReceive, updates focusedIndex
```

This fits the existing architecture: AppDelegate already manages the popover lifecycle and uses NotificationCenter for `.previewButt` and `.confirmAndClose`.

## Changes

### 1. `project.pbxproj` — deployment target

Replace all `MACOSX_DEPLOYMENT_TARGET = 15.4` with `12.0` (project + target, Debug + Release).

### 2. `AppDelegate.swift` — keyboard monitor

Add a `keyMonitor: Any?` property.

In `showIconPicker()`, after showing the popover, install a local event monitor:
```swift
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    guard let self else { return event }
    switch event.keyCode {
    case 123: // left arrow
        NotificationCenter.default.post(name: .moveFocus, object: nil,
                                        userInfo: ["offset": -1])
        return nil
    case 124: // right arrow
        NotificationCenter.default.post(name: .moveFocus, object: nil,
                                        userInfo: ["offset": 1])
        return nil
    case 126: // up arrow
        NotificationCenter.default.post(name: .moveFocus, object: nil,
                                        userInfo: ["offset": -Layout.gridColumns])
        return nil
    case 125: // down arrow
        NotificationCenter.default.post(name: .moveFocus, object: nil,
                                        userInfo: ["offset": Layout.gridColumns])
        return nil
    case 36: // return
        NotificationCenter.default.post(name: .confirmAndClose, object: nil)
        return nil
    default:
        return event // pass through
    }
}
```

In `popoverDidClose`, remove the monitor:
```swift
if let monitor = keyMonitor {
    NSEvent.removeMonitor(monitor)
    keyMonitor = nil
}
```

### 3. `ButtPickerView.swift` — receive focus via notification

Remove:
- All `.onKeyPress()` modifiers
- `KeyPress.Result` return types
- `.contentMargins(.vertical, 12)` (replace with `.padding(.vertical, 12)`)

Add:
- A `NotificationCenter.default.publisher(for: .moveFocus)` subscription via `.onReceive` that reads the offset from userInfo and updates `focusedIndex`, scrolls to the new position, and posts `.previewButt`.

The `move()` and `selectFocused()` helper functions become plain `Void` functions — no `KeyPress.Result` needed.

### 4. `Notification.Name` extension

Add `.moveFocus` alongside the existing `.previewButt` and `.confirmAndClose`.

## Files changed

| File | Change |
|------|--------|
| `project.pbxproj` | Deployment target → 12.0 |
| `AppDelegate.swift` | Add NSEvent key monitor on popover open/close |
| `ButtPickerView.swift` | Remove .onKeyPress, add .onReceive(.moveFocus), replace .contentMargins |

## Build and transfer

1. Build/archive on current Mac (Xcode 16, targets macOS 12.0)
2. Export as "Copy App" (unsigned)
3. AirDrop or USB to macOS 12 MacBook Pro
4. Right-click → Open to bypass Gatekeeper on first launch

## Risk

Low. Keyboard navigation uses a well-established AppKit API (`NSEvent.addLocalMonitorForEvents`) that predates macOS 10.6. The only visual difference is `.padding` vs `.contentMargins` which is negligible for a 12pt vertical inset.

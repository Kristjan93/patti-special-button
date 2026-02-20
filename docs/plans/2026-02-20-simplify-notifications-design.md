# Simplify Notifications: Eliminate confirmAndClose self-notification

## Problem

The NSEvent key monitor in AppDelegate posts `.confirmAndClose` via NotificationCenter, which AppDelegate itself observes. This is AppDelegate talking to itself through a notification — unnecessary indirection.

## Change

Call `commitAndClosePopover()` directly from the Return key case in the NSEvent monitor instead of posting `.confirmAndClose`.

## Files changed

| File | Change |
|------|--------|
| `AppDelegate.swift` | Return key calls `commitAndClosePopover()` directly; remove `.confirmAndClose` observer registration, cleanup, and `confirmCloseObservation` property |
| `ButtPickerView.swift` | Remove `.confirmAndClose` from `Notification.Name` extension |

## Remaining notifications

- `.moveFocus` — AppDelegate → ButtPickerView (arrow key focus updates)
- `.previewButt` — ButtPickerView → AppDelegate (temporary menu bar preview)

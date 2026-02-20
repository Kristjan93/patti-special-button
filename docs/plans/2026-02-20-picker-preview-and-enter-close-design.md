# Picker Preview & Enter-to-Close

Implemented 2026-02-20. Adds preview-on-focus and Enter-to-select-and-close to the icon picker popover.

## Problem

Arrow keys moved focus visually in the picker grid but didn't affect the menu bar. Users couldn't see how a butt looked in the menu bar without committing to it. No way to dismiss on selection — Enter did nothing to the popover, users had to click outside.

## What was built

### Preview on focus

Arrow keys in the picker temporarily preview the focused butt in the menu bar. The preview is not persisted to UserDefaults. When the popover closes (Escape, click outside), the menu bar reverts to the committed selection.

### Enter-to-select-and-close

Pressing Enter on the focused icon writes the selection to `@AppStorage` and closes the popover. Single click still selects without closing.

### Considered and dropped: double-click-to-close

SwiftUI's `.onTapGesture(count: 2)` alongside `.onTapGesture(count: 1)` adds ~300ms delay to single taps — unacceptable for browsing. An `NSViewRepresentable` with `NSClickGestureRecognizer` would avoid the delay but adds ceremony for a feature that overlaps with Enter. Dropped in favor of simplicity.

## Communication: NotificationCenter

`ButtPickerView` (SwiftUI) has no reference to `AppDelegate` or the `NSPopover`. Two custom notifications bridge the gap:

- `.previewButt` — posted by `move()` on arrow key, carries `["buttId": String]`. AppDelegate calls `previewButt(_:)` → `loadButtById(_:)`.
- `.confirmAndClose` — posted by `selectFocused()` on Enter. AppDelegate updates `committedButtId` and closes the popover.

Observers are registered when the popover opens and removed in `popoverDidClose`.

## Revert lifecycle

1. Popover opens → `committedButtId` snapshots current selection.
2. Arrow keys → `previewButt(_:)` swaps menu bar animator without touching UserDefaults.
3. Single click → `@AppStorage` writes to UserDefaults → `handleButtChange()` fires → updates `committedButtId`.
4. Enter → writes to `@AppStorage` + posts `.confirmAndClose` → `commitAndClosePopover()` updates committed and closes.
5. `popoverDidClose` → if `committedButtId != lastLoadedButtId`, revert via `loadButtById`.

## Files touched

| File | Change |
|------|--------|
| `AppDelegate.swift` | `NSPopoverDelegate` conformance, `committedButtId` tracking, `loadButtById` extraction, `previewButt(_:)`, `commitAndClosePopover()`, notification observers in `showIconPicker()`, revert in `popoverDidClose`. |
| `ButtPickerView.swift` | `Notification.Name` extensions (`.previewButt`, `.confirmAndClose`), post preview in `move()`, post confirmAndClose in `selectFocused()`. |

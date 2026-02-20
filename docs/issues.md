# Known Issues & Improvements

Assessed 2026-02-20. Covers architecture, code quality, and missing features.

## High Priority

### Incomplete icon picker (Phase 2)
- `ButtPickerView.swift` is a placeholder — shows "TODO: Butt picker" text
- `AnimatedButtCell.swift` is defined but never used (no grid layout yet)
- Needs: full grid layout, selection state, persistence, visual selection indicator

## Medium Priority

### Inconsistent timer strategy
- `GIFAnimator` uses `Timer.scheduledTimer` (runloop-dependent)
- `AppDelegate` uses `DispatchSourceTimer` (GCD-based, more reliable)
- Should standardize on `DispatchSourceTimer` throughout

### Inconsistent error handling
- Frame loading uses `fatalError()` for missing GIFs/frames — crashes the app on any asset corruption
- Audio file loading silently returns on failure (`guard ... else { return }`)
- No recovery mechanism or user feedback for missing assets
- Should adopt a consistent strategy (graceful degradation preferred)

### GIFAnimator timer cleanup
- No cleanup on `deinit` — timer may outlive the object if `stop()` is not called
- Mitigated by `onDisappear` in SwiftUI, but fragile for non-SwiftUI usage

## Low Priority

### Hardcoded constants scattered throughout
- Frame duration (0.1s), minimum play duration (0.5s), window size (500x500), cell size (80x80), padding values
- No centralized configuration; refactoring and tuning requires touching multiple files

### Hardcoded UserDefaults key
- `"selectedButtId"` string hardcoded in `AppDelegate`
- Should be a shared constant for safer refactoring and testing

### No selection indicator on picker re-open
- When the icon picker is re-opened, there's no visual feedback showing which butt is currently selected
- Needs checkmark, highlight, or border on the active cell

### No centralized asset manager
- Multiple `Bundle.main.url()` calls with hardcoded paths and subdirectories
- Fragile to renaming; could benefit from an enum or manager for resource access

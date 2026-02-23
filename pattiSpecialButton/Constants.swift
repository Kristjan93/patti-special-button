import AppKit

enum Defaults {
    static let selectedButtIdKey = "selectedButtId"
    static let iconSizeKey = "iconSize"
    static let displayModeKey = "displayMode"

    static let defaultButtId = "asynchronous-butt"
    static let defaultIconSize = "fun-size"
    static let defaultDisplayMode = "stencil"

    static let selectedSoundIdKey = "selectedSoundId"
    static let defaultSoundId = "perfect-fart"
}

enum DisplayMode: String {
    case stencil, outline, original

    func processFrame(_ image: NSImage, size: NSSize) -> NSImage {
        let rect = NSRect(origin: .zero, size: size)
        let result = NSImage(size: size)
        result.lockFocus()
        switch self {
        case .stencil:
            NSColor.white.set()
            rect.fill()
            image.draw(in: rect, from: .zero, operation: .destinationOut, fraction: 1.0)
            result.isTemplate = true
        case .original:
            NSColor.white.drawSwatch(in: rect)
            image.draw(in: rect)
            result.isTemplate = false
        case .outline:
            image.draw(in: rect)
            result.isTemplate = true
        }
        result.unlockFocus()
        return result
    }
}

enum IconSize: String {
    case funSize = "fun-size"
    case regularRump = "regular-rump"
    case badonkadonk = "badonkadonk"

    var points: CGFloat {
        switch self {
        case .funSize: return 20
        case .regularRump: return 21
        case .badonkadonk: return 22
        }
    }

    var label: String {
        switch self {
        case .funSize: return "Fun Size"
        case .regularRump: return "Regular Rump"
        case .badonkadonk: return "Badonkadonk"
        }
    }
}

enum Assets {
    static let buttFramesDir = "ButtFrames"
    static let manifestFile = "manifest"
    static let soundsDir = "sounds"
    static let soundsManifestFile = "sounds-manifest"
}

enum Layout {
    static let popoverSize = NSSize(width: 500, height: 500)
    static let gridColumns = 4
    static let gridSpacing: CGFloat = 12
    static let gridPadding: CGFloat = 16
    static let cellImageSize: CGFloat = 80
    static let cellPadding: CGFloat = 8
    static let cellCornerRadius: CGFloat = 8
    static let creditsPopoverSize = NSSize(width: 250, height: 200)

    static let soundGridColumns = 2
    static let soundPopoverSize = NSSize(width: 420, height: 500)
    static let waveformBarCount = 25

    static let touchBarButtSize: CGFloat = 30
    static let touchBarButtSpacing: CGFloat = 8
}

enum Credits {
    static let buttsssURL = URL(string: "https://www.buttsss.com/")!
    static let freesoundURL = URL(string: "https://freesound.org/people/jixolros/")!
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")!
}

// MARK: - Notification Names

extension Notification.Name {
    // Icon picker
    static let previewButt = Notification.Name("previewButt")
    static let moveFocus = Notification.Name("moveFocus")
    static let selectButtFocus = Notification.Name("selectButtFocus")

    // Sound picker
    static let toggleSoundPreview = Notification.Name("toggleSoundPreview")
    static let moveSoundFocus = Notification.Name("moveSoundFocus")
    static let confirmAndCloseSound = Notification.Name("confirmAndCloseSound")
}

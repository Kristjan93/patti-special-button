import Foundation

enum Defaults {
    static let selectedButtIdKey = "selectedButtId"
    static let iconSizeKey = "iconSize"
    static let displayModeKey = "displayMode"

    static let defaultButtId = "async-butt"
    static let defaultIconSize = "fun-size"
    static let defaultDisplayMode = "fill"
}

enum DisplayMode: String {
    case fill, outline, original
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
    static let fartSoundFile = "556505__jixolros__small-realpoots105-110"
}

enum Layout {
    static let popoverSize = NSSize(width: 500, height: 500)
    static let gridColumns = 4
    static let gridSpacing: CGFloat = 12
    static let gridPadding: CGFloat = 16
    static let cellImageSize: CGFloat = 80
    static let cellPadding: CGFloat = 8
    static let cellCornerRadius: CGFloat = 8
    static let minimumPlayDuration: TimeInterval = 0.5
    static let creditsPopoverSize = NSSize(width: 250, height: 200)
}

enum Credits {
    static let buttsssURL = URL(string: "https://www.buttsss.com/")!
    static let freesoundURL = URL(string: "https://freesound.org/people/jixolros/")!
    static let licenseURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")!
}

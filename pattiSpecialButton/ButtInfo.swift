import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "pattiSpecialButton", category: "ButtInfo")

private let validIdPattern = try! NSRegularExpression(pattern: "^[a-z0-9-]+$")

struct ButtInfo: Codable, Identifiable {
    let id: String
    let name: String
    let frameCount: Int
    let frameDelays: [Int]

    var hasValidId: Bool {
        validIdPattern.firstMatch(in: id, range: NSRange(id.startIndex..., in: id)) != nil
    }
}

struct ButtManifest: Codable {
    let butts: [ButtInfo]
}

// Decoded once on first access, shared across all callers.
// Swift global lets are lazy and thread-safe by default.
let buttManifest: [ButtInfo] = {
    guard let url = Bundle.main.url(
        forResource: Assets.manifestFile, withExtension: "json", subdirectory: Assets.buttFramesDir
    ) else {
        logger.error("Butt manifest not found in bundle")
        return []
    }
    do {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(ButtManifest.self, from: data)
        let valid = manifest.butts.filter { $0.hasValidId }
        if valid.count != manifest.butts.count {
            logger.warning("Filtered \(manifest.butts.count - valid.count) butt(s) with invalid IDs")
        }
        return valid
    } catch {
        logger.error("Failed to load butt manifest: \(error.localizedDescription)")
        return []
    }
}()

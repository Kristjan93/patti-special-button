import Foundation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "pattiSpecialButton", category: "SoundInfo")

private let validFilePattern = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_.-]+$")

private func isValidFilename(_ name: String) -> Bool {
    !name.contains("/") && !name.contains("\\") && !name.isEmpty
        && validFilePattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
}

struct SoundSegment: Codable {
    let file: String
    let ext: String
    let waveform: [Float]?

    var bundleURL: URL? {
        Bundle.main.url(forResource: file, withExtension: ext, subdirectory: Assets.soundsDir)
    }

    var hasValidFilename: Bool { isValidFilename(file) && isValidFilename(ext) }
}

struct SoundInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let file: String?
    let ext: String?
    let shuffle: Bool?
    let source: String?
    let waveform: [Float]?
    let segments: [SoundSegment]?

    var isShuffle: Bool {
        shuffle == true && !(segments?.isEmpty ?? true)
    }

    var bundleURL: URL? {
        guard let file, let ext else { return nil }
        return Bundle.main.url(forResource: file, withExtension: ext, subdirectory: Assets.soundsDir)
    }

    var displayFilename: String {
        if let file, let ext { return "\(file).\(ext)" }
        if let source { return source }
        return name
    }

    var hasValidFiles: Bool {
        if isShuffle {
            return segments?.allSatisfy({ $0.hasValidFilename }) ?? true
        }
        guard let file, let ext else { return true }
        return isValidFilename(file) && isValidFilename(ext)
    }
}

// Decoded once on first access, shared across all callers.
// Swift global lets are lazy and thread-safe by default.
let soundManifest: [SoundInfo] = {
    guard let url = Bundle.main.url(
        forResource: Assets.soundsManifestFile, withExtension: "json", subdirectory: Assets.soundsDir
    ) else {
        logger.error("Sound manifest not found in bundle")
        return []
    }
    do {
        let data = try Data(contentsOf: url)
        let sounds = try JSONDecoder().decode([SoundInfo].self, from: data)
        let valid = sounds.filter { $0.hasValidFiles }
        if valid.count != sounds.count {
            logger.warning("Filtered \(sounds.count - valid.count) sound(s) with invalid filenames")
        }
        return valid
    } catch {
        logger.error("Failed to load sound manifest: \(error.localizedDescription)")
        return []
    }
}()

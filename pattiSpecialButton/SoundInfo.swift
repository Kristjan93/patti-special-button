import Foundation

struct SoundSegment: Codable {
    let file: String
    let ext: String
    let waveform: [Float]?

    var bundleURL: URL? {
        Bundle.main.url(forResource: file, withExtension: ext, subdirectory: Assets.soundsDir)
    }
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
}

// Decoded once on first access, shared across all callers.
let loadSoundManifest: () -> [SoundInfo] = {
    let cached: [SoundInfo] = {
        guard let url = Bundle.main.url(
            forResource: Assets.soundsManifestFile, withExtension: "json", subdirectory: Assets.soundsDir
        ),
        let data = try? Data(contentsOf: url),
        let sounds = try? JSONDecoder().decode([SoundInfo].self, from: data)
        else { return [] }
        return sounds
    }()
    return { cached }
}()

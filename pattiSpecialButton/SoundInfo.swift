import Foundation

struct SoundInfo: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let file: String
    let ext: String

    var bundleURL: URL? {
        Bundle.main.url(forResource: file, withExtension: ext, subdirectory: Assets.soundsDir)
    }

    var displayFilename: String {
        "\(file).\(ext)"
    }
}

func loadSoundManifest() -> [SoundInfo] {
    guard let url = Bundle.main.url(
        forResource: Assets.soundsManifestFile, withExtension: "json", subdirectory: Assets.soundsDir
    ),
    let data = try? Data(contentsOf: url),
    let sounds = try? JSONDecoder().decode([SoundInfo].self, from: data)
    else { return [] }
    return sounds
}

import Foundation

struct ButtInfo: Codable, Identifiable {
    let id: String
    let name: String
    let frameCount: Int
    let frameDelays: [Int]
}

struct ButtManifest: Codable {
    let butts: [ButtInfo]
}

// Decoded once on first access, shared across all callers.
let loadButtManifest: () -> [ButtInfo] = {
    let cached: [ButtInfo] = {
        guard let url = Bundle.main.url(
            forResource: Assets.manifestFile, withExtension: "json", subdirectory: Assets.buttFramesDir
        ),
        let data = try? Data(contentsOf: url),
        let manifest = try? JSONDecoder().decode(ButtManifest.self, from: data)
        else { return [] }
        return manifest.butts
    }()
    return { cached }
}()

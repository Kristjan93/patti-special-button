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

func loadButtManifest() -> [ButtInfo] {
    guard let url = Bundle.main.url(
        forResource: "manifest", withExtension: "json", subdirectory: "ButtFrames"
    ),
    let data = try? Data(contentsOf: url),
    let manifest = try? JSONDecoder().decode(ButtManifest.self, from: data)
    else { return [] }
    return manifest.butts
}

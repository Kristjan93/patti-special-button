import AVFoundation

class SoundPlayer {

    private let soundLookup: [String: SoundInfo]
    private var audioPlayer: AVAudioPlayer?

    private var shuffleQueue: [Int] = []
    private var shuffleIndex: Int = 0
    private var lastShuffleSoundId: String?

    init(soundLookup: [String: SoundInfo]) {
        self.soundLookup = soundLookup
    }

    func play(soundId: String) {
        guard let sound = soundLookup[soundId] else { return }

        let url: URL?
        if sound.isShuffle, let segments = sound.segments, !segments.isEmpty {
            // Reset queue on sound switch or when exhausted
            if lastShuffleSoundId != sound.id || shuffleIndex >= shuffleQueue.count {
                shuffleQueue = reshuffledQueue(count: segments.count)
                shuffleIndex = 0
                lastShuffleSoundId = sound.id
            }
            url = segments[shuffleQueue[shuffleIndex]].bundleURL
            shuffleIndex += 1
        } else {
            url = sound.bundleURL
        }

        guard let url else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.play()
        } catch {
            return
        }
    }

    private func reshuffledQueue(count: Int) -> [Int] {
        var indices = Array(0..<count)
        indices.shuffle()
        return indices
    }
}

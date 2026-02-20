import AppKit
import Combine

class FrameAnimator: ObservableObject {
    @Published var currentFrame: NSImage?

    private var frames: [NSImage] = []
    private var frameIndex = 0
    private var timer: Timer?
    private let frameDuration: TimeInterval = 0.1

    init(buttId: String) {
        loadFrames(buttId: buttId)
    }

    private func loadFrames(buttId: String) {
        guard let buttDir = Bundle.main.url(
            forResource: buttId, withExtension: nil, subdirectory: "ButtFrames"
        ) else { return }

        var i = 0
        while true {
            let url = buttDir.appendingPathComponent(String(format: "frame_%02d.png", i))
            guard FileManager.default.fileExists(atPath: url.path) else { break }
            guard let image = NSImage(contentsOf: url) else { break }
            frames.append(image)
            i += 1
        }

        if !frames.isEmpty {
            currentFrame = frames[0]
        }
    }

    func start() {
        guard frames.count > 1 else { return }
        frameIndex = 0
        let t = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.currentFrame = self.frames[self.frameIndex]
        }
        // .common mode keeps firing during scroll/drag (RunLoop enters .tracking mode during UI interaction)
        RunLoop.current.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

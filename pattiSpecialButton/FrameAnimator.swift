import AppKit
import Combine

class FrameAnimator: ObservableObject {
    @Published var currentFrameIndex: Int = 0

    let frames: [NSImage]
    private let frameDelays: [TimeInterval]
    private var timer: DispatchSourceTimer?

    var currentFrame: NSImage? {
        frames.isEmpty ? nil : frames[currentFrameIndex]
    }

    init(buttInfo: ButtInfo, displayMode: DisplayMode? = nil) {
        var loaded: [NSImage] = []

        if let buttDir = Bundle.main.url(
            forResource: buttInfo.id, withExtension: nil, subdirectory: Assets.buttFramesDir
        ) {
            var i = 0
            while true {
                let url = buttDir.appendingPathComponent(String(format: "frame_%02d.png", i))
                guard FileManager.default.fileExists(atPath: url.path),
                      let image = NSImage(contentsOf: url) else { break }
                loaded.append(image)
                i += 1
            }
        }

        if let mode = displayMode {
            self.frames = loaded.map { mode.processFrame($0, size: $0.size) }
        } else {
            self.frames = loaded
        }
        self.frameDelays = buttInfo.frameDelays.map { max(Double($0) / 1000.0, 0.01) }
    }

    func start() {
        guard frames.count > 1 else { return }
        currentFrameIndex = 0
        scheduleNext()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func scheduleNext() {
        let needsResume = timer == nil
        if needsResume {
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.setEventHandler { [weak self] in self?.advanceFrame() }
            timer = t
        }
        timer?.schedule(deadline: .now() + frameDelays[currentFrameIndex])
        if needsResume {
            timer?.resume()
        }
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        scheduleNext()
    }

    deinit {
        timer?.cancel()
    }
}

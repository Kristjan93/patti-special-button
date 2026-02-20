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

    init(buttInfo: ButtInfo, invertAlpha: Bool = false) {
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

        self.frames = invertAlpha ? loaded.map(Self.withInvertedAlpha) : loaded
        self.frameDelays = buttInfo.frameDelays.map { max(Double($0) / 1000.0, 0.01) }
    }

    // Flips the alpha channel: opaque ↔ transparent. Used by Template mode to
    // turn RGBA outline images into the filled-background-with-cutout effect
    // that grayscale template rendering produces natively.
    private static func withInvertedAlpha(_ image: NSImage) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero,
                   operation: .destinationOut, fraction: 1.0)
        result.unlockFocus()
        return result
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
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + frameDelays[currentFrameIndex])
        t.setEventHandler { [weak self] in self?.advanceFrame() }
        t.resume()
        timer = t
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        // Reschedule with the new frame's delay
        timer?.cancel()
        scheduleNext()
    }

    deinit {
        timer?.cancel()
    }
}

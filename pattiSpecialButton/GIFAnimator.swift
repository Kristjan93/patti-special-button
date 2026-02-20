import AppKit
import Combine

class GIFAnimator: ObservableObject {
    @Published var currentFrame: NSImage?

    private var frames: [NSImage] = []
    private var durations: [TimeInterval] = []
    private var frameIndex = 0
    private var timer: Timer?

    init(gifFilename: String) {
        loadGIF(gifFilename: gifFilename)
    }

    private func loadGIF(gifFilename: String) {
        guard let url = Bundle.main.url(
            forResource: gifFilename,
            withExtension: nil,
            subdirectory: "fractured-but-whole"
        ),
        let data = try? Data(contentsOf: url),
        let imageRep = NSBitmapImageRep(data: data)
        else { return }

        let count = (imageRep.value(forProperty: .frameCount) as? Int) ?? 1

        for i in 0..<count {
            imageRep.setProperty(.currentFrame, withValue: i)

            let frame = NSImage(size: imageRep.size)
            frame.addRepresentation(imageRep.copy() as! NSImageRep)
            frames.append(frame)

            let delay = (imageRep.value(forProperty: .currentFrameDuration) as? TimeInterval) ?? 0.1
            durations.append(max(delay, 0.02))
        }

        if !frames.isEmpty {
            currentFrame = frames[0]
        }
    }

    func start() {
        guard frames.count > 1 else { return }
        frameIndex = 0
        scheduleNext()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleNext() {
        let delay = durations[frameIndex]
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.frameIndex = (self.frameIndex + 1) % self.frames.count
            self.currentFrame = self.frames[self.frameIndex]
            self.scheduleNext()
        }
    }
}

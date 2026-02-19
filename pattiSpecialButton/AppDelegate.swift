import AppKit
import AVFoundation

// Transparent view placed on top of the status bar button to intercept mouse events.
// NSStatusBarButton's internal tracking loop swallows mouseUp, but an NSView
// subclass is guaranteed to receive mouseUp after mouseDown.
class StatusItemMouseView: NSView {
    var onMouseDown: (() -> Void)?
    var onMouseUp: (() -> Void)?
    var onRightMouseUp: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onMouseDown?() }
    override func mouseUp(with event: NSEvent) { onMouseUp?() }
    override func rightMouseUp(with event: NSEvent) { onRightMouseUp?() }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var animationTimer: DispatchSourceTimer?
    private var frameImages: [NSImage] = []
    private var currentFrameIndex = 0

    private let currentButtId = "async-butt"
    private let frameDuration: TimeInterval = 0.1
    private let minimumPlayDuration: TimeInterval = 0.5

    private var audioPlayer: AVAudioPlayer?
    private var playbackStartTime: Date?
    private var pendingStop: DispatchWorkItem?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadFrameImages()
        setupStatusItem()
        startAnimation()
    }

    // MARK: - Frame Loading

    private func loadFrameImages() {
        guard let buttDir = Bundle.main.url(forResource: currentButtId, withExtension: nil, subdirectory: "ButtFrames") else {
            fatalError("Missing ButtFrames/\(currentButtId) in bundle")
        }

        var i = 0
        while true {
            let url = buttDir.appendingPathComponent(String(format: "frame_%02d.png", i))
            guard FileManager.default.fileExists(atPath: url.path) else { break }
            guard let image = NSImage(contentsOf: url) else {
                fatalError("Failed to load frame \(i) for \(currentButtId)")
            }
            image.size = NSSize(width: 20, height: 20)
            image.isTemplate = true
            frameImages.append(image)
            i += 1
        }

        if frameImages.isEmpty {
            fatalError("No frames found in ButtFrames/\(currentButtId)")
        }
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = frameImages[0]
        button.imagePosition = .imageOnly

        let mouseView = StatusItemMouseView(frame: button.bounds)
        mouseView.autoresizingMask = [.width, .height]
        mouseView.onMouseDown = { [weak self] in self?.startSound() }
        mouseView.onMouseUp = { [weak self] in self?.stopSound() }
        mouseView.onRightMouseUp = { [weak self] in self?.showContextMenu() }
        button.addSubview(mouseView)
    }

    // MARK: - Sound Playback

    private func startSound() {
        guard let url = Bundle.main.url(forResource: "556505__jixolros__small-realpoots105-110", withExtension: "wav") else { return }

        // Cancel any pending delayed stop from a previous click.
        pendingStop?.cancel()

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        } catch {
            return
        }

        playbackStartTime = Date()
    }

    private func stopSound() {
        let elapsed = -(playbackStartTime ?? Date()).timeIntervalSinceNow
        let remaining = minimumPlayDuration - elapsed

        if remaining > 0 {
            // Haven't hit the minimum yet — schedule a delayed stop.
            let item = DispatchWorkItem { [weak self] in self?.audioPlayer?.stop() }
            pendingStop = item
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: item)
        } else {
            audioPlayer?.stop()
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: - Animation

    private func startAnimation() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: frameDuration)
        timer.setEventHandler { [weak self] in self?.advanceFrame() }
        timer.resume()
        animationTimer = timer
    }

    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frameImages.count
        statusItem.button?.image = frameImages[currentFrameIndex]
    }
}

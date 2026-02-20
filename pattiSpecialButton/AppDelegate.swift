import AppKit
import AVFoundation
import Combine
import SwiftUI

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
    private var animator: FrameAnimator?
    private var menuBarFrames: [NSImage] = []
    private var animatorSubscription: AnyCancellable?

    private let minimumPlayDuration: TimeInterval = 0.5

    private var audioPlayer: AVAudioPlayer?
    private var playbackStartTime: Date?
    private var pendingStop: DispatchWorkItem?

    private var defaultsObservation: NSObjectProtocol?
    private var iconPickerPopover: NSPopover?

    private var buttLookup: [String: ButtInfo] = [:]

    private var currentButtId: String {
        UserDefaults.standard.string(forKey: "selectedButtId") ?? "async-butt"
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buttLookup = Dictionary(uniqueKeysWithValues: loadButtManifest().map { ($0.id, $0) })
        setupStatusItem()
        loadButt()

        defaultsObservation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleButtChange()
        }

    }

    // MARK: - Butt Switching

    private var lastLoadedButtId: String?

    private func handleButtChange() {
        let newId = currentButtId
        guard newId != lastLoadedButtId else { return }
        loadButt()
    }

    private func loadButt() {
        let buttId = currentButtId
        guard let buttInfo = buttLookup[buttId] else {
            fatalError("Unknown butt id: \(buttId)")
        }

        animator?.stop()

        let newAnimator = FrameAnimator(buttInfo: buttInfo)

        // Build menu-bar-ready copies (20x20, template) from the shared frames
        menuBarFrames = newAnimator.frames.map { original in
            let copy = original.copy() as! NSImage
            copy.size = NSSize(width: 20, height: 20)
            copy.isTemplate = true
            return copy
        }

        animatorSubscription = newAnimator.$currentFrameIndex
            .sink { [weak self] index in
                guard let self, index < self.menuBarFrames.count else { return }
                self.statusItem.button?.image = self.menuBarFrames[index]
            }

        animator = newAnimator
        newAnimator.start()
        lastLoadedButtId = buttId
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = menuBarFrames.first
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

        let changeIconItem = NSMenuItem(title: "Change Icon", action: #selector(changeIconMenuAction), keyEquivalent: "")
        changeIconItem.target = self
        menu.addItem(changeIconItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: - Icon Picker Popover

    @objc private func changeIconMenuAction() {
        showIconPicker()
    }

    private func showIconPicker() {
        if let popover = iconPickerPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 500, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ButtPickerView())
        iconPickerPopover = popover

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make just the popover's window key — gives it focus for interactivity
        // and .transient dismissal without activating the entire app (which causes
        // "Show Desktop" on desktop click and Space-switching on fullscreen).
        popover.contentViewController?.view.window?.makeKey()
    }

}

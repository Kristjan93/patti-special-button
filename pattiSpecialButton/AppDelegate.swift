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

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {

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
    private var committedButtId: String?
    private var previewObservation: NSObjectProtocol?
    private var confirmCloseObservation: NSObjectProtocol?

    private var buttLookup: [String: ButtInfo] = [:]

    private var currentButtId: String {
        UserDefaults.standard.string(forKey: "selectedButtId") ?? "async-butt"
    }

    private var currentIconSize: CGFloat {
        switch UserDefaults.standard.string(forKey: "iconSize") ?? "fun-size" {
        case "regular-rump": return 22
        case "badonkadonk": return 24
        default: return 20
        }
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
    private var lastLoadedIconSize: CGFloat?

    private func handleButtChange() {
        let newId = currentButtId
        let newSize = currentIconSize
        guard newId != lastLoadedButtId || newSize != lastLoadedIconSize else { return }
        // A UserDefaults write while the popover is open means the user clicked to select.
        // Update committedButtId so popover close doesn't revert this selection.
        if iconPickerPopover?.isShown == true {
            committedButtId = newId
        }
        loadButt()
    }

    private func loadButt() {
        loadButtById(currentButtId)
        lastLoadedButtId = currentButtId
        lastLoadedIconSize = currentIconSize
    }

    private func loadButtById(_ buttId: String) {
        guard let buttInfo = buttLookup[buttId] else { return }

        animator?.stop()

        let newAnimator = FrameAnimator(buttInfo: buttInfo)

        let size = currentIconSize
        menuBarFrames = newAnimator.frames.map { original in
            let copy = original.copy() as! NSImage
            copy.size = NSSize(width: size, height: size)
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
    }

    private func previewButt(_ buttId: String) {
        guard buttId != lastLoadedButtId else { return }
        loadButtById(buttId)
        lastLoadedButtId = buttId
    }

    private func commitAndClosePopover() {
        committedButtId = currentButtId
        iconPickerPopover?.performClose(nil)
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

        let sizeItem = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: "")
        let sizeSubmenu = NSMenu()
        let currentSize = UserDefaults.standard.string(forKey: "iconSize") ?? "fun-size"
        for (tag, label) in [("fun-size", "Fun Size"), ("regular-rump", "Regular Rump"), ("badonkadonk", "Badonkadonk")] {
            let item = NSMenuItem(title: label, action: #selector(selectIconSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = tag
            item.state = tag == currentSize ? .on : .off
            sizeSubmenu.addItem(item)
        }
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func selectIconSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? String else { return }
        UserDefaults.standard.set(size, forKey: "iconSize")
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
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: ButtPickerView())
        iconPickerPopover = popover

        committedButtId = currentButtId

        previewObservation = NotificationCenter.default.addObserver(
            forName: .previewButt, object: nil, queue: .main
        ) { [weak self] notification in
            guard let buttId = notification.userInfo?["buttId"] as? String else { return }
            self?.previewButt(buttId)
        }

        confirmCloseObservation = NotificationCenter.default.addObserver(
            forName: .confirmAndClose, object: nil, queue: .main
        ) { [weak self] _ in
            self?.commitAndClosePopover()
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make just the popover's window key — gives it focus for interactivity
        // and .transient dismissal without activating the entire app (which causes
        // "Show Desktop" on desktop click and Space-switching on fullscreen).
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        if let obs = previewObservation {
            NotificationCenter.default.removeObserver(obs)
            previewObservation = nil
        }
        if let obs = confirmCloseObservation {
            NotificationCenter.default.removeObserver(obs)
            confirmCloseObservation = nil
        }

        // Revert to committed butt if we were previewing something else
        if let committed = committedButtId, committed != lastLoadedButtId {
            loadButtById(committed)
            lastLoadedButtId = committed
            lastLoadedIconSize = currentIconSize
        }
        committedButtId = nil
    }

}

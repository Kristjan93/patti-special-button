import AppKit
import AVFoundation
import Combine
import SwiftUI

// Transparent view placed on top of the status bar button to intercept mouse events.
// NSStatusBarButton's internal tracking loop swallows mouseUp, but an NSView
// subclass is guaranteed to receive mouseUp after mouseDown.
class StatusItemMouseView: NSView {
    var onMouseDown: (() -> Void)?
    var onRightMouseUp: (() -> Void)?

    override func mouseDown(with event: NSEvent) { onMouseDown?() }
    override func rightMouseUp(with event: NSEvent) { onRightMouseUp?() }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSPopoverDelegate {

    private var statusItem: NSStatusItem!
    private var animator: FrameAnimator?
    private var menuBarFrames: [NSImage] = []
    private var animatorSubscription: AnyCancellable?

    private var audioPlayer: AVAudioPlayer?

    private var defaultsObservation: NSObjectProtocol?
    private var iconPickerPopover: NSPopover?
    private var soundPickerPopover: NSPopover?
    private var creditsPopover: NSPopover?
    private var committedButtId: String?
    private var committedSoundId: String?
    private var previewObservation: NSObjectProtocol?
    private var keyMonitor: Any?

    private var buttLookup: [String: ButtInfo] = [:]
    private var soundLookup: [String: SoundInfo] = [:]

    private var currentButtId: String {
        UserDefaults.standard.string(forKey: Defaults.selectedButtIdKey) ?? Defaults.defaultButtId
    }

    private var currentIconSize: CGFloat {
        let raw = UserDefaults.standard.string(forKey: Defaults.iconSizeKey) ?? Defaults.defaultIconSize
        return (IconSize(rawValue: raw) ?? .funSize).points
    }

    private var currentDisplayMode: DisplayMode {
        let raw = UserDefaults.standard.string(forKey: Defaults.displayModeKey) ?? Defaults.defaultDisplayMode
        return DisplayMode(rawValue: raw) ?? .fill
    }

    // MARK: - App Lifecycle

    private var currentSoundId: String {
        UserDefaults.standard.string(forKey: Defaults.selectedSoundIdKey) ?? Defaults.defaultSoundId
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buttLookup = Dictionary(uniqueKeysWithValues: loadButtManifest().map { ($0.id, $0) })
        soundLookup = Dictionary(uniqueKeysWithValues: loadSoundManifest().map { ($0.id, $0) })
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
    private var lastLoadedDisplayMode: DisplayMode?

    private func handleButtChange() {
        let newId = currentButtId
        let newSize = currentIconSize
        let newMode = currentDisplayMode
        guard newId != lastLoadedButtId || newSize != lastLoadedIconSize
            || newMode != lastLoadedDisplayMode else { return }
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
        lastLoadedDisplayMode = currentDisplayMode
    }

    private func loadButtById(_ buttId: String) {
        guard let buttInfo = buttLookup[buttId] else { return }

        animator?.stop()

        let mode = currentDisplayMode
        let isTemplate = mode != .original

        let newAnimator = FrameAnimator(buttInfo: buttInfo)

        let size = NSSize(width: currentIconSize, height: currentIconSize)
        menuBarFrames = newAnimator.frames.map { original in
            let base: NSImage
            switch mode {
            case .fill:
                base = invertAlpha(original, size: size)
            case .original:
                base = compositeOnWhite(original, size: size)
            case .outline:
                let copy = original.copy() as! NSImage
                copy.size = size
                base = copy
            }
            base.isTemplate = isTemplate
            return base
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

    private func invertAlpha(_ image: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero,
                   operation: .destinationOut, fraction: 1.0)
        result.unlockFocus()
        return result
    }

    private func compositeOnWhite(_ image: NSImage, size: NSSize) -> NSImage {
        let result = NSImage(size: size)
        result.lockFocus()
        NSColor.white.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.draw(in: NSRect(origin: .zero, size: size))
        result.unlockFocus()
        return result
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = menuBarFrames.first
        button.imagePosition = .imageOnly

        let mouseView = StatusItemMouseView(frame: button.bounds)
        mouseView.autoresizingMask = [.width, .height]
        mouseView.onMouseDown = { [weak self] in self?.playSound() }
        mouseView.onRightMouseUp = { [weak self] in self?.showContextMenu() }
        button.addSubview(mouseView)
    }

    // MARK: - Sound Playback

    private func playSound() {
        guard let sound = soundLookup[currentSoundId],
              let url = sound.bundleURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.play()
        } catch {
            return
        }
    }

    // MARK: - Context Menu

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let changeIconItem = NSMenuItem(title: "Change Icon", action: #selector(changeIconMenuAction), keyEquivalent: "")
        changeIconItem.target = self
        menu.addItem(changeIconItem)

        let changeSoundItem = NSMenuItem(title: "Change Sound", action: #selector(changeSoundMenuAction), keyEquivalent: "")
        changeSoundItem.target = self
        menu.addItem(changeSoundItem)

        let sizeItem = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: "")
        let sizeSubmenu = NSMenu()
        let currentSize = UserDefaults.standard.string(forKey: Defaults.iconSizeKey) ?? Defaults.defaultIconSize
        for size in [IconSize.funSize, .regularRump, .badonkadonk] {
            let item = NSMenuItem(title: size.label, action: #selector(selectIconSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.state = size.rawValue == currentSize ? .on : .off
            sizeSubmenu.addItem(item)
        }
        sizeItem.submenu = sizeSubmenu
        menu.addItem(sizeItem)

        let displayItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let displaySubmenu = NSMenu()
        let currentMode = currentDisplayMode

        for (mode, label) in [(DisplayMode.fill, "Stencil"), (.outline, "Outline")] {
            let item = NSMenuItem(title: label, action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentMode ? .on : .off
            displaySubmenu.addItem(item)
        }

        displaySubmenu.addItem(NSMenuItem.separator())

        let originalItem = NSMenuItem(title: "Original", action: #selector(selectDisplayMode(_:)), keyEquivalent: "")
        originalItem.target = self
        originalItem.representedObject = DisplayMode.original.rawValue
        originalItem.state = currentMode == .original ? .on : .off
        displaySubmenu.addItem(originalItem)
        displayItem.submenu = displaySubmenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        let creditsItem = NSMenuItem(title: "Credits", action: #selector(creditsMenuAction), keyEquivalent: "")
        creditsItem.target = self
        menu.addItem(creditsItem)

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    @objc private func selectIconSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? String else { return }
        UserDefaults.standard.set(size, forKey: Defaults.iconSizeKey)
    }

    @objc private func selectDisplayMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? String else { return }
        UserDefaults.standard.set(mode, forKey: Defaults.displayModeKey)
    }

    @objc private func creditsMenuAction() {
        if let popover = creditsPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = Layout.creditsPopoverSize
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: CreditsView())
        creditsPopover = popover

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
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
        popover.contentSize = Layout.popoverSize
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

        // Arrow keys and Return are handled via NSEvent monitor instead of SwiftUI's
        // .onKeyPress (macOS 14+), so keyboard nav works back to macOS 12.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 123: // left arrow
                NotificationCenter.default.post(name: .moveFocus, object: nil,
                                                userInfo: ["offset": -1])
                return nil
            case 124: // right arrow
                NotificationCenter.default.post(name: .moveFocus, object: nil,
                                                userInfo: ["offset": 1])
                return nil
            case 126: // up arrow
                NotificationCenter.default.post(name: .moveFocus, object: nil,
                                                userInfo: ["offset": -Layout.gridColumns])
                return nil
            case 125: // down arrow
                NotificationCenter.default.post(name: .moveFocus, object: nil,
                                                userInfo: ["offset": Layout.gridColumns])
                return nil
            case 49: // space — select focused butt without closing
                NotificationCenter.default.post(name: .selectButtFocus, object: nil)
                return nil
            case 36: // return
                self.commitAndClosePopover()
                return nil
            default:
                return event
            }
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Make just the popover's window key — gives it focus for interactivity
        // and .transient dismissal without activating the entire app (which causes
        // "Show Desktop" on desktop click and Space-switching on fullscreen).
        popover.contentViewController?.view.window?.makeKey()

        // Async so the context menu's tracking loop fully unwinds before Touch Bar setup
        DispatchQueue.main.async {
            if #available(macOS 10.12.2, *) { TouchBarParade.attach(to: popover) }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let obs = previewObservation {
            NotificationCenter.default.removeObserver(obs)
            previewObservation = nil
        }
        // Revert to committed butt if we were previewing something else
        if let committed = committedButtId, committed != lastLoadedButtId {
            loadButtById(committed)
            lastLoadedButtId = committed
            lastLoadedIconSize = currentIconSize
        }
        committedButtId = nil
        committedSoundId = nil
    }

    // MARK: - Sound Picker Popover

    @objc private func changeSoundMenuAction() {
        showSoundPicker()
    }

    private func showSoundPicker() {
        if let popover = soundPickerPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = NSPopover()
        popover.contentSize = Layout.soundPopoverSize
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: SoundPickerView())
        soundPickerPopover = popover

        committedSoundId = currentSoundId

        previewObservation = NotificationCenter.default.addObserver(
            forName: .confirmAndCloseSound, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.committedSoundId = self.currentSoundId
            self.soundPickerPopover?.performClose(nil)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 49: // space
                NotificationCenter.default.post(name: .toggleSoundPreview, object: nil)
                return nil
            case 123: // left arrow
                NotificationCenter.default.post(name: .moveSoundFocus, object: nil,
                                                userInfo: ["offset": -1])
                return nil
            case 124: // right arrow
                NotificationCenter.default.post(name: .moveSoundFocus, object: nil,
                                                userInfo: ["offset": 1])
                return nil
            case 126: // up arrow
                NotificationCenter.default.post(name: .moveSoundFocus, object: nil,
                                                userInfo: ["offset": -Layout.soundGridColumns])
                return nil
            case 125: // down arrow
                NotificationCenter.default.post(name: .moveSoundFocus, object: nil,
                                                userInfo: ["offset": Layout.soundGridColumns])
                return nil
            case 36: // return
                NotificationCenter.default.post(name: .confirmAndCloseSound, object: nil)
                return nil
            default:
                return event
            }
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        DispatchQueue.main.async {
            if #available(macOS 10.12.2, *) { TouchBarParade.attach(to: popover) }
        }
    }

}

import AppKit
import Combine
import ServiceManagement
import Sparkle
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

    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )

    private var statusItem: NSStatusItem!
    private var animator: FrameAnimator?
    private var menuBarFrames: [NSImage] = []
    private var animatorSubscription: AnyCancellable?

    private var pressResetWork: DispatchWorkItem?
    private var soundPlayer: SoundPlayer!

    private var defaultsObservation: NSObjectProtocol?
    private var iconPickerPopover: NSPopover?
    private var soundPickerPopover: NSPopover?
    private var aboutPopover: NSPopover?
    private var hintPopover: NSPopover?
    private var committedButtId: String?
    private var committedSoundId: String?
    private var iconPickerObservation: NSObjectProtocol?
    private var soundPickerObservation: NSObjectProtocol?
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
        return DisplayMode(rawValue: raw) ?? .stencil
    }

    private var currentLineWeight: LineWeight {
        let raw = UserDefaults.standard.string(forKey: Defaults.lineWeightKey) ?? Defaults.defaultLineWeight
        return LineWeight(rawValue: raw) ?? .regular
    }

    // MARK: - App Lifecycle

    private var currentSoundId: String {
        UserDefaults.standard.string(forKey: Defaults.selectedSoundIdKey) ?? Defaults.defaultSoundId
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buttLookup = Dictionary(uniqueKeysWithValues: buttManifest.map { ($0.id, $0) })
        soundLookup = Dictionary(uniqueKeysWithValues: soundManifest.map { ($0.id, $0) })
        soundPlayer = SoundPlayer(soundLookup: soundLookup)
        setupStatusItem()
        loadButt()

        statusItem.button?.toolTip = "Right-click for options"

        defaultsObservation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleButtChange()
        }

        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
    }

    // MARK: - Butt Switching

    private var lastLoadedButtId: String?
    private var lastLoadedIconSize: CGFloat?
    private var lastLoadedDisplayMode: DisplayMode?
    private var lastLoadedLineWeight: LineWeight?

    private func handleButtChange() {
        let newId = currentButtId
        let newSize = currentIconSize
        let newMode = currentDisplayMode
        let newWeight = currentLineWeight
        guard newId != lastLoadedButtId || newSize != lastLoadedIconSize
            || newMode != lastLoadedDisplayMode || newWeight != lastLoadedLineWeight else { return }
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
        lastLoadedLineWeight = currentLineWeight
    }

    private func loadButtById(_ buttId: String) {
        guard let buttInfo = buttLookup[buttId] else { return }

        animator?.stop()

        let mode = currentDisplayMode
        let newAnimator = FrameAnimator(buttInfo: buttInfo, lineWeight: currentLineWeight)
        let size = NSSize(width: currentIconSize, height: currentIconSize)
        menuBarFrames = newAnimator.frames.map { mode.processFrame($0, size: size) }

        animatorSubscription = newAnimator.$currentFrameIndex
            .receive(on: DispatchQueue.main)
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
        // Arrow-key preview updates the menu bar without writing to UserDefaults.
        // Persist the previewed butt so it becomes the real selection.
        if let previewedId = lastLoadedButtId {
            UserDefaults.standard.set(previewedId, forKey: Defaults.selectedButtIdKey)
        }
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
        mouseView.onMouseDown = { [weak self] in self?.playSound() }
        mouseView.onRightMouseUp = { [weak self] in self?.showContextMenu() }
        button.addSubview(mouseView)
    }

    // MARK: - Sound Playback

    private func playSound() {
        triggerHighlight()

        let defaults = UserDefaults.standard
        let clickCount = defaults.integer(forKey: Defaults.leftClickCountKey) + 1
        defaults.set(clickCount, forKey: Defaults.leftClickCountKey)

        if clickCount == 3 && !defaults.bool(forKey: Defaults.hasRightClickedKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showHint()
            }
        }

        soundPlayer.play(soundId: currentSoundId)
    }

    private func triggerHighlight() {
        pressResetWork?.cancel()
        statusItem.button?.isHighlighted = true

        let resetWork = DispatchWorkItem { [weak self] in
            self?.statusItem.button?.isHighlighted = false
        }
        pressResetWork = resetWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: resetWork)
    }

    // MARK: - Context Menu

    // LSUIElement apps aren't active when the menu opens, so Sparkle's
    // windows appear behind other apps. Activate first.
    @objc func checkForUpdates() {
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    private func showContextMenu() {
        UserDefaults.standard.set(true, forKey: Defaults.hasRightClickedKey)
        hintPopover?.performClose(nil)

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

        for (mode, label) in [(DisplayMode.outline, "Outline"), (.stencil, "Stencil")] {
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

        let weightItem = NSMenuItem(title: "Line Weight", action: nil, keyEquivalent: "")
        let weightSubmenu = NSMenu()
        let currentWeight = UserDefaults.standard.string(forKey: Defaults.lineWeightKey) ?? Defaults.defaultLineWeight
        for weight in [LineWeight.regular, .bold] {
            let item = NSMenuItem(title: weight.label, action: #selector(selectLineWeight(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = weight.rawValue
            item.state = weight.rawValue == currentWeight ? .on : .off
            weightSubmenu.addItem(item)
        }
        weightItem.submenu = weightSubmenu
        menu.addItem(weightItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About", action: #selector(aboutMenuAction), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let updateItem = NSMenuItem(
            title: "Check for Updates\u{2026}",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

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

    @objc private func selectLineWeight(_ sender: NSMenuItem) {
        guard let weight = sender.representedObject as? String else { return }
        UserDefaults.standard.set(weight, forKey: Defaults.lineWeightKey)
    }

    @objc private func aboutMenuAction() {
        if let popover = aboutPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = showPopover(size: Layout.aboutPopoverSize, content: CreditsView())
        aboutPopover = popover
    }

    // MARK: - Popover Helper

    @discardableResult
    private func showPopover<V: View>(
        size: NSSize, content: V, delegate: NSPopoverDelegate? = nil
    ) -> NSPopover {
        let popover = NSPopover()
        popover.contentSize = size
        popover.behavior = .transient
        popover.delegate = delegate
        popover.contentViewController = NSHostingController(rootView: content)

        guard let button = statusItem.button else { return popover }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        return popover
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

        let popover = showPopover(size: Layout.popoverSize, content: ButtPickerView(), delegate: self)
        iconPickerPopover = popover

        committedButtId = currentButtId

        iconPickerObservation = NotificationCenter.default.addObserver(
            forName: .previewButt, object: nil, queue: .main
        ) { [weak self] notification in
            guard let buttId = notification.userInfo?["buttId"] as? String else { return }
            self?.previewButt(buttId)
        }

        keyMonitor = makeKeyMonitor(
            moveNotification: .moveFocus,
            columns: Layout.gridColumns,
            spaceAction: { NotificationCenter.default.post(name: .selectButtFocus, object: nil) },
            returnAction: { [weak self] in self?.commitAndClosePopover() }
        )

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

        let closedPopover = notification.object as? NSPopover

        // Revert butt preview when the icon picker closes
        if closedPopover === iconPickerPopover {
            if let obs = iconPickerObservation {
                NotificationCenter.default.removeObserver(obs)
                iconPickerObservation = nil
            }
            if let committed = committedButtId, committed != lastLoadedButtId {
                loadButtById(committed)
                lastLoadedButtId = committed
                lastLoadedIconSize = currentIconSize
            }
            iconPickerPopover = nil
            committedButtId = nil
        } else if closedPopover === soundPickerPopover {
            if let obs = soundPickerObservation {
                NotificationCenter.default.removeObserver(obs)
                soundPickerObservation = nil
            }
            soundPickerPopover = nil
            committedSoundId = nil
        } else if closedPopover === hintPopover {
            hintPopover = nil
        }
    }

    // MARK: - Keyboard Monitor

    // Arrow keys and Return are handled via NSEvent monitor instead of SwiftUI's
    // .onKeyPress (macOS 14+), so keyboard nav works back to macOS 12.
    private func makeKeyMonitor(
        moveNotification: Notification.Name,
        columns: Int,
        spaceAction: @escaping () -> Void,
        returnAction: @escaping () -> Void
    ) -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case KeyCode.leftArrow:
                NotificationCenter.default.post(name: moveNotification, object: nil,
                                                userInfo: ["offset": -1])
                return nil
            case KeyCode.rightArrow:
                NotificationCenter.default.post(name: moveNotification, object: nil,
                                                userInfo: ["offset": 1])
                return nil
            case KeyCode.upArrow:
                NotificationCenter.default.post(name: moveNotification, object: nil,
                                                userInfo: ["offset": -columns])
                return nil
            case KeyCode.downArrow:
                NotificationCenter.default.post(name: moveNotification, object: nil,
                                                userInfo: ["offset": columns])
                return nil
            case KeyCode.space:
                spaceAction()
                return nil
            case KeyCode.returnKey:
                returnAction()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Sound Picker Popover

    @objc private func changeSoundMenuAction() {
        showSoundPicker()
    }
    
    // MARK: - Sound Picker Popover

    private func showHint() {
        guard hintPopover == nil else { return }

        let popover = showPopover(size: Layout.hintPopoverSize, content: HintView(), delegate: self)
        hintPopover = popover

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak popover] in
            popover?.performClose(nil)
        }
    }

    private func showSoundPicker() {
        if let popover = soundPickerPopover, popover.isShown {
            popover.performClose(nil)
            return
        }

        let popover = showPopover(size: Layout.soundPopoverSize, content: SoundPickerView(), delegate: self)
        soundPickerPopover = popover

        committedSoundId = currentSoundId

        soundPickerObservation = NotificationCenter.default.addObserver(
            forName: .confirmAndCloseSound, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.committedSoundId = self.currentSoundId
            self.soundPickerPopover?.performClose(nil)
        }

        keyMonitor = makeKeyMonitor(
            moveNotification: .moveSoundFocus,
            columns: Layout.soundGridColumns,
            spaceAction: { NotificationCenter.default.post(name: .toggleSoundPreview, object: nil) },
            returnAction: { NotificationCenter.default.post(name: .confirmAndCloseSound, object: nil) }
        )

        DispatchQueue.main.async {
            if #available(macOS 10.12.2, *) { TouchBarParade.attach(to: popover) }
        }
    }

}

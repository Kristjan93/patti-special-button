import AppKit
import Combine
import ObjectiveC

// Touch Bar butt parade: scrollable strip of all animated butts in the Touch Bar
// when a picker popover is open. Tapping a butt selects it (writes to UserDefaults,
// menu bar updates via existing observer). Uses NSScrubber for native scroll + tap.
// Entirely self-contained — AppDelegate calls attach(to:) and forgets about it.

@available(macOS 10.12.2, *)
enum TouchBarParade {

    private static var associatedKey: UInt8 = 0

    fileprivate static let paradeItemIdentifier = NSTouchBarItem.Identifier(
        "com.pattiVoice.pattiSpecialButton.buttParade"
    )

    static func attach(to popover: NSPopover) {
        guard let vc = popover.contentViewController,
              let window = vc.view.window else { return }

        let manifest = loadButtManifest()
        guard !manifest.isEmpty else { return }

        let modeRaw = UserDefaults.standard.string(forKey: Defaults.displayModeKey)
            ?? Defaults.defaultDisplayMode
        let displayMode = DisplayMode(rawValue: modeRaw) ?? .fill
        let size = NSSize(width: Layout.touchBarButtSize, height: Layout.touchBarButtSize)

        var animators: [FrameAnimator] = []
        var allFrames: [[NSImage]] = []

        for info in manifest {
            let animator = FrameAnimator(buttInfo: info)
            let frames = animator.frames.map { Self.processFrame($0, mode: displayMode, size: size) }
            animators.append(animator)
            allFrames.append(frames)
            if animator.frames.count > 1 { animator.start() }
        }

        let selectedId = UserDefaults.standard.string(forKey: Defaults.selectedButtIdKey)
            ?? Defaults.defaultButtId
        let selectedIndex = manifest.firstIndex(where: { $0.id == selectedId }) ?? 0

        let holder = ParadeHolder(
            manifest: manifest,
            animators: animators,
            processedFrames: allFrames,
            initialScrollIndex: selectedIndex
        )

        let touchBar = NSTouchBar()
        touchBar.delegate = holder
        touchBar.defaultItemIdentifiers = [paradeItemIdentifier]
        holder.nsTouchBar = touchBar

        window.touchBar = touchBar

        // Activate the app so the Touch Bar system recognizes our key window.
        // Without this, Touch Bar stays blank when opening via right-click menu.
        NSApp.activate(ignoringOtherApps: true)

        objc_setAssociatedObject(vc, &associatedKey, holder, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Frame processing

    fileprivate static func processFrame(_ image: NSImage, mode: DisplayMode, size: NSSize) -> NSImage {
        let rect = NSRect(origin: .zero, size: size)
        let result = NSImage(size: size)
        result.lockFocus()

        switch mode {
        case .fill:
            NSColor.white.set()
            rect.fill()
            image.draw(in: rect, from: .zero, operation: .destinationOut, fraction: 1.0)
            result.isTemplate = true
        case .original:
            NSColor.white.drawSwatch(in: rect)
            image.draw(in: rect)
            result.isTemplate = false
        case .outline:
            image.draw(in: rect)
            result.isTemplate = true
        }

        result.unlockFocus()
        return result
    }
}

// MARK: - ParadeHolder

@available(macOS 10.12.2, *)
private class ParadeHolder: NSObject, NSTouchBarDelegate, NSScrubberDataSource, NSScrubberDelegate {

    let manifest: [ButtInfo]
    let animators: [FrameAnimator]
    let processedFrames: [[NSImage]]
    let initialScrollIndex: Int
    var nsTouchBar: NSTouchBar?

    private static let scrubberItemId = NSUserInterfaceItemIdentifier("buttScrubberItem")

    init(manifest: [ButtInfo], animators: [FrameAnimator], processedFrames: [[NSImage]], initialScrollIndex: Int) {
        self.manifest = manifest
        self.animators = animators
        self.processedFrames = processedFrames
        self.initialScrollIndex = initialScrollIndex
    }

    // MARK: NSTouchBarDelegate

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == TouchBarParade.paradeItemIdentifier else { return nil }

        let scrubber = NSScrubber()
        scrubber.register(AnimatedButtScrubberItem.self, forItemIdentifier: Self.scrubberItemId)
        scrubber.dataSource = self
        scrubber.delegate = self
        scrubber.mode = .free
        scrubber.selectionBackgroundStyle = nil
        scrubber.showsAdditionalContentIndicators = true

        let layout = NSScrubberFlowLayout()
        layout.itemSize = NSSize(width: Layout.touchBarButtSize, height: Layout.touchBarButtSize)
        layout.itemSpacing = Layout.touchBarButtSpacing
        scrubber.scrubberLayout = layout

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = scrubber

        // Scroll to the currently selected butt after the scrubber lays out
        let scrollIndex = initialScrollIndex
        DispatchQueue.main.async {
            scrubber.scrollItem(at: scrollIndex, to: .center)
        }

        return item
    }

    // MARK: NSScrubberDataSource

    func numberOfItems(for scrubber: NSScrubber) -> Int {
        manifest.count
    }

    func scrubber(_ scrubber: NSScrubber, viewForItemAt index: Int) -> NSScrubberItemView {
        let item = scrubber.makeItem(withIdentifier: Self.scrubberItemId, owner: nil) as! AnimatedButtScrubberItem
        item.configure(animator: animators[index], frames: processedFrames[index])
        return item
    }

    // MARK: NSScrubberDelegate

    func scrubber(_ scrubber: NSScrubber, didSelectItemAt index: Int) {
        guard index >= 0, index < manifest.count else { return }
        UserDefaults.standard.set(manifest[index].id, forKey: Defaults.selectedButtIdKey)
    }

    deinit {
        for animator in animators { animator.stop() }
    }
}

// MARK: - AnimatedButtScrubberItem

@available(macOS 10.12.2, *)
private class AnimatedButtScrubberItem: NSScrubberItemView {

    private let imageView = NSImageView()
    private var subscription: AnyCancellable?

    override init(frame: NSRect) {
        super.init(frame: frame)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func configure(animator: FrameAnimator, frames: [NSImage]) {
        subscription?.cancel()
        if let first = frames.first {
            imageView.image = first
        }
        guard frames.count > 1 else { return }
        subscription = animator.$currentFrameIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self, frames] index in
                guard index < frames.count else { return }
                self?.imageView.image = frames[index]
            }
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }
}

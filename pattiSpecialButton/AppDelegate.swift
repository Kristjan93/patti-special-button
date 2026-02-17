import AppKit

// AppDelegate is the core of the app. It manages the menu bar icon,
// animation, click handling, and sound playback.
// It uses NSApplicationDelegate (AppKit) because SwiftUI's MenuBarExtra
// doesn't support animated icons or left-click custom actions.
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // The menu bar item — this is the clickable icon that lives in the
    // top-right area of the macOS menu bar, next to WiFi, battery, etc.
    private var statusItem: NSStatusItem!

    // A GCD timer that fires every 0.1s to advance the animation frame.
    // We use DispatchSourceTimer instead of Timer/NSTimer because it's
    // more reliable — NSTimer can stall when menus are open.
    private var animationTimer: DispatchSourceTimer?

    // The 6 pre-loaded butt frame images, ready to be swapped in.
    private var frameImages: [NSImage] = []

    // Tracks which frame we're currently showing (0-5).
    private var currentFrameIndex = 0

    // --- Configuration ---
    // Change these to tweak behavior:
    private let frameCount = 6
    private let frameDuration: TimeInterval = 0.1  // 0.6s total / 6 frames

    // The sound to play on left-click. NSSound(named:) looks in:
    //   1. The app bundle (for custom sounds — drop a file here later)
    //   2. ~/Library/Sounds/
    //   3. /System/Library/Sounds/ (system sounds like "Funk", "Pop", etc.)
    // To swap to a custom fart sound later: drop "fart.aiff" in the project
    // folder and change this to "fart".
    private let soundName = "Funk"

    // MARK: - App Lifecycle

    // Called once when the app finishes launching.
    // This is where we set everything up.
    func applicationDidFinishLaunching(_ notification: Notification) {
        loadFrameImages()
        setupStatusItem()
        startAnimation()
    }

    // MARK: - Frame Loading

    // Loads all 6 butt frame PNGs from the Asset Catalog into memory.
    // We do this once at startup so the animation timer doesn't have to
    // load images on every frame (which would be wasteful).
    private func loadFrameImages() {
        for i in 0..<frameCount {
            let name = "ButtFrame\(i)"
            guard let image = NSImage(named: name) else {
                fatalError("Missing image asset: \(name)")
            }
            // Force the image to 18x18 points — the standard menu bar icon size.
            // The PNGs are 36px which is 18pt at 2x Retina.
            image.size = NSSize(width: 18, height: 18)
            // Template mode makes the icon adapt to the menu bar appearance:
            // white icon on dark menu bar, black icon on light menu bar.
            image.isTemplate = true
            frameImages.append(image)
        }
    }

    // MARK: - Status Item Setup

    // Creates the menu bar icon and configures it to receive click events.
    private func setupStatusItem() {
        // Create a square-sized slot in the menu bar.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }

        // Show the first frame as the initial icon.
        button.image = frameImages[0]
        button.imagePosition = .imageOnly

        // Tell the button to notify us on BOTH left-click and right-click.
        // By default, NSStatusBarButton only fires on left-click.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // When clicked, call our statusBarButtonClicked method.
        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
    }

    // MARK: - Click Handling

    // Called when the user clicks the menu bar icon.
    // We check which mouse button was used to decide what to do.
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        switch event.type {
        case .rightMouseUp:
            // Right-click → show the context menu with "Quit"
            showContextMenu()
        default:
            // Left-click (or any other click) → play the sound
            playSound()
        }
    }

    // Shows a small right-click menu with a "Quit" option.
    // Technique: temporarily assign an NSMenu to the status item,
    // trigger a click to show it, then remove it so left-click
    // works normally again. (When statusItem.menu is set, AppKit
    // always shows the menu on ANY click, which we don't want.)
    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self  // So we get notified when the menu closes
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu
        statusItem.button?.performClick(nil)  // Programmatically show the menu
    }

    // NSMenuDelegate method — called when the right-click menu closes.
    // We nil out the menu so that left-click goes back to playing sound
    // instead of showing the menu.
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // Plays the configured sound.
    private func playSound() {
        NSSound(named: NSSound.Name(soundName))?.play()
    }

    // MARK: - Animation

    // Starts a repeating timer that swaps the menu bar icon image
    // every 0.1 seconds, creating the wiggle animation.
    private func startAnimation() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: frameDuration)
        timer.setEventHandler { [weak self] in
            self?.advanceFrame()
        }
        timer.resume()
        animationTimer = timer
    }

    // Advances to the next frame, looping back to 0 after frame 5.
    private func advanceFrame() {
        currentFrameIndex = (currentFrameIndex + 1) % frameCount
        statusItem.button?.image = frameImages[currentFrameIndex]
    }
}

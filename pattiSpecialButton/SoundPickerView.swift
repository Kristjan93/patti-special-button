import AVFoundation
import SwiftUI

extension Notification.Name {
    static let toggleSoundPreview = Notification.Name("toggleSoundPreview")
    static let moveSoundFocus = Notification.Name("moveSoundFocus")
    static let confirmAndCloseSound = Notification.Name("confirmAndCloseSound")
}

struct SoundPickerView: View {
    @AppStorage(Defaults.selectedSoundIdKey) private var selectedSoundId = Defaults.defaultSoundId
    @State private var focusedIndex: Int = 0
    @State private var sampleCache: [String: [Float]] = [:]
    @State private var playingId: String?
    @State private var playbackProgress: Double = 0
    @State private var previewPlayer: AVAudioPlayer?
    @State private var progressTimer: Timer?

    private let allSounds: [SoundInfo] = loadSoundManifest()
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: Layout.gridSpacing),
        count: Layout.soundGridColumns
    )

    /// Sounds grouped by category, preserving manifest order for categories.
    private var groupedSounds: [(category: String, sounds: [SoundInfo])] {
        var order: [String] = []
        var groups: [String: [SoundInfo]] = [:]
        for sound in allSounds {
            let key = sound.category.lowercased()
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(sound)
        }
        return order.map { key in
            (category: key.prefix(1).uppercased() + key.dropFirst(), sounds: groups[key]!)
        }
    }

    /// Flat list of all sounds in display order (category by category).
    private var flatSounds: [SoundInfo] {
        groupedSounds.flatMap { $0.sounds }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.gridSpacing) {
                        ForEach(Array(groupedSounds.enumerated()), id: \.element.category) { groupIndex, group in
                            if groupIndex > 0 {
                                Divider().padding(.horizontal, Layout.gridPadding)
                            }

                            Text(group.category)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, Layout.gridPadding)
                                .padding(.top, groupIndex > 0 ? 4 : 0)

                            LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
                                ForEach(group.sounds) { sound in
                                    let flatIndex = flatSounds.firstIndex(where: { $0.id == sound.id }) ?? 0
                                    SoundCell(
                                        sound: sound,
                                        isSelected: sound.id == selectedSoundId,
                                        isFocused: flatIndex == focusedIndex,
                                        samples: sampleCache[sound.id] ?? [],
                                        isPlaying: sound.id == playingId,
                                        progress: sound.id == playingId ? playbackProgress : 0,
                                        onTap: { selectSound(sound.id) },
                                        onPlayToggle: { togglePreview(sound) }
                                    )
                                    .id(sound.id)
                                }
                            }
                            .padding(.horizontal, Layout.gridPadding)
                        }
                    }
                    .padding(.vertical, 12)
                    // Extra bottom padding so content isn't hidden behind the keyboard hints bar
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onReceive(NotificationCenter.default.publisher(for: .moveSoundFocus)) { notification in
                    guard let offset = notification.userInfo?["offset"] as? Int else { return }
                    moveFocus(offset, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .toggleSoundPreview)) { _ in
                    let sounds = flatSounds
                    guard focusedIndex >= 0, focusedIndex < sounds.count else { return }
                    togglePreview(sounds[focusedIndex])
                }
                .onReceive(NotificationCenter.default.publisher(for: .confirmAndCloseSound)) { _ in
                    let sounds = flatSounds
                    guard focusedIndex >= 0, focusedIndex < sounds.count else { return }
                    selectSound(sounds[focusedIndex].id)
                }
                .onAppear {
                    loadSamples()
                    let sounds = flatSounds
                    if let index = sounds.firstIndex(where: { $0.id == selectedSoundId }) {
                        focusedIndex = index
                        proxy.scrollTo(sounds[index].id)
                    }
                }
                .onDisappear {
                    stopPreview()
                }
            }

            // Keyboard hints footer
            HStack(spacing: 16) {
                keyHint("\u{2423}", "Play/Pause")
                keyHint("\u{21A9}", "Select")
                keyHint("\u{238B}", "Close")
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
    }

    private func keyHint(_ symbol: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(symbol)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            Text(label)
        }
    }

    // MARK: - Focus Navigation

    private func moveFocus(_ offset: Int, proxy: ScrollViewProxy) {
        let sounds = flatSounds
        let newIndex = focusedIndex + offset
        guard newIndex >= 0, newIndex < sounds.count else { return }
        focusedIndex = newIndex
        withAnimation { proxy.scrollTo(sounds[newIndex].id) }
    }

    // MARK: - Selection

    private func selectSound(_ id: String) {
        selectedSoundId = id
    }

    // MARK: - Preview Playback

    private func togglePreview(_ sound: SoundInfo) {
        if playingId == sound.id {
            stopPreview()
            return
        }

        stopPreview()

        guard let url = sound.bundleURL else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.play()
            previewPlayer = player
            playingId = sound.id
            playbackProgress = 0

            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
                guard let player = previewPlayer, player.isPlaying else {
                    stopPreview()
                    return
                }
                playbackProgress = player.currentTime / player.duration
            }
        } catch {
            return
        }
    }

    private func stopPreview() {
        progressTimer?.invalidate()
        progressTimer = nil
        previewPlayer?.stop()
        previewPlayer = nil
        playingId = nil
        playbackProgress = 0
    }

    // MARK: - Waveform Sampling

    private func loadSamples() {
        for sound in allSounds {
            guard sampleCache[sound.id] == nil, let url = sound.bundleURL else { continue }
            sampleCache[sound.id] = WaveformSampler.sampleAudio(url: url)
        }
    }
}

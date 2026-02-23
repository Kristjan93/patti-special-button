import AVFoundation
import SwiftUI

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
        ScrollViewReader { proxy in
            scrollContent(proxy: proxy)
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
    }

    private var soundScrollContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedSounds.enumerated()), id: \.element.category) { groupIndex, group in
                if groupIndex > 0 {
                    Divider()
                        .padding(.vertical, 8)
                }

                Text(group.category)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.bottom, 6)

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
                            onTap: {
                                focusedIndex = flatIndex
                                selectSound(sound.id)
                                togglePreview(sound)
                            }
                        )
                        .id(sound.id)
                    }
                }
            }
        }
        .padding(Layout.gridPadding)
    }

    @ViewBuilder
    private func scrollContent(proxy: ScrollViewProxy) -> some View {
        if #available(macOS 13.0, *) {
            ScrollView { soundScrollContent }
                .safeAreaInset(edge: .bottom) { keyboardHintsBar }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack(alignment: .bottom) {
                ScrollView { soundScrollContent.padding(.bottom, 36) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                keyboardHintsBar
            }
        }
    }

    private var keyboardHintsBar: some View {
        HStack(spacing: 14) {
            keyHint("\u{2190}\u{2192}\u{2191}\u{2193}", "Move")  // ←→↑↓
            keyHint("Space", "Play")
            keyHint("\u{21A9}", "Select + Close")                // ↩
            keyHint("Esc", "Close")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private func keyHint(_ key: String, _ label: String?) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )
            if let label {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
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

import SwiftUI

struct SoundCell: View {
    let sound: SoundInfo
    let isSelected: Bool
    var isFocused: Bool = false
    let samples: [Float]
    let isPlaying: Bool
    let progress: Double
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WaveformView(samples: samples, progress: isPlaying ? progress : 0)
                .frame(height: 24)

            MarqueeText(
                text: sound.name,
                font: .system(size: 12, weight: .medium),
                color: .primary
            )

            HStack(spacing: 5) {
                if sound.isShuffle { shufflePill }
                MarqueeText(
                    text: sound.displayFilename,
                    font: .system(size: 9),
                    color: .secondary
                )
            }
        }
        .padding(Layout.cellPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .fill(isFocused ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cellCornerRadius)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var shufflePill: some View {
        HStack(spacing: 3) {
            Image(systemName: "shuffle")
                .font(.system(size: 7, weight: .bold))
            Text("\(sound.segments?.count ?? 0) clips")
                .font(.system(size: 8, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.secondary.opacity(0.3)))
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

// MARK: - Marquee Text

/// Music-app-style scrolling text that loops when content overflows.
private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var startTime = Date.now

    private let gap: CGFloat = 40
    private let speed: Double = 25
    private let pause: Double = 2.0

    var body: some View {
        GeometryReader { geo in
            let overflows = textWidth > geo.size.width + 1

            if overflows {
                let scrollDist = textWidth + gap
                let scrollDur = scrollDist / speed
                let totalCycle = pause + scrollDur

                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startTime)
                    let cycleTime = elapsed.truncatingRemainder(dividingBy: totalCycle)
                    let offset: CGFloat = cycleTime < pause
                        ? 0
                        : -CGFloat((cycleTime - pause) / scrollDur) * scrollDist

                    HStack(spacing: gap) {
                        label
                        label
                    }
                    .offset(x: offset)
                }
            } else {
                label
            }
        }
        .clipped()
        .frame(height: 12)
        .background(
            label.hidden().fixedSize()
                .background(GeometryReader { g in
                    Color.clear.preference(key: MarqueeTextWidthKey.self, value: g.size.width)
                })
        )
        .onPreferenceChange(MarqueeTextWidthKey.self) { textWidth = $0 }
    }

    private var label: some View {
        Text(text).font(font).foregroundColor(color).fixedSize().lineLimit(1)
    }
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

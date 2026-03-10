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

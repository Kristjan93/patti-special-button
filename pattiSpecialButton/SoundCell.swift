import SwiftUI

struct SoundCell: View {
    let sound: SoundInfo
    let isSelected: Bool
    var isFocused: Bool = false
    let samples: [Float]
    let isPlaying: Bool
    let progress: Double
    let onTap: () -> Void
    let onPlayToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button(action: onPlayToggle) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isPlaying ? .accentColor : .secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)

                WaveformView(samples: samples, progress: isPlaying ? progress : 0)
                    .frame(height: 24)
            }

            Text(sound.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Text(sound.displayFilename)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
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
}

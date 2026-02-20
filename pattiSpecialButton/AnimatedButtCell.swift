import SwiftUI

struct AnimatedButtCell: View {
    let butt: ButtInfo
    let isSelected: Bool
    var isFocused: Bool = false
    let onTap: () -> Void

    @StateObject private var animator: FrameAnimator

    init(butt: ButtInfo, isSelected: Bool, isFocused: Bool = false, onTap: @escaping () -> Void) {
        self.butt = butt
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.onTap = onTap
        _animator = StateObject(wrappedValue: FrameAnimator(buttInfo: butt))
    }

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let frame = animator.currentFrame {
                    Image(nsImage: frame)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.clear
                }
            }
            .frame(width: 80, height: 80)

            Text(butt.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

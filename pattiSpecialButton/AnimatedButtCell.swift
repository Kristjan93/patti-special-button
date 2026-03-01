import SwiftUI

struct AnimatedButtCell: View {
    let butt: ButtInfo
    let isSelected: Bool
    var isFocused: Bool = false
    let displayMode: DisplayMode
    let onTap: () -> Void

    private var isTemplate: Bool { displayMode != .original }

    @StateObject private var animator: FrameAnimator

    init(butt: ButtInfo, isSelected: Bool, isFocused: Bool = false,
         displayMode: DisplayMode = .stencil,
         onTap: @escaping () -> Void) {
        self.butt = butt
        self.isSelected = isSelected
        self.isFocused = isFocused
        self.displayMode = displayMode
        self.onTap = onTap
        // Picker cells use raw frames — display mode is handled visually via
        // SwiftUI .renderingMode and background color, not per-frame image processing.
        _animator = StateObject(wrappedValue: FrameAnimator(buttInfo: butt))
    }

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let frame = animator.currentFrame {
                    Image(nsImage: frame)
                        .renderingMode(isTemplate ? .template : .original)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Color.clear
                }
            }
            .frame(width: Layout.cellImageSize, height: Layout.cellImageSize)
            .background(
                displayMode == .original
                    ? RoundedRectangle(cornerRadius: 4).fill(Color.white)
                    : RoundedRectangle(cornerRadius: 4).fill(Color.clear)
            )

            Text(butt.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(Layout.cellPadding)
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
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

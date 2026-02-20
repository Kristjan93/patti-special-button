import SwiftUI

struct AnimatedButtCell: View {
    let butt: ButtInfo
    let isSelected: Bool
    let onTap: () -> Void

    @StateObject private var animator: FrameAnimator

    init(butt: ButtInfo, isSelected: Bool, onTap: @escaping () -> Void) {
        self.butt = butt
        self.isSelected = isSelected
        self.onTap = onTap
        _animator = StateObject(wrappedValue: FrameAnimator(buttId: butt.id))
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
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear { animator.start() }
        .onDisappear { animator.stop() }
    }
}

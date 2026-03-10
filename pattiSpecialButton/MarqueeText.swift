import SwiftUI

/// Music-app-style scrolling text that loops when content overflows.
struct MarqueeText: View {
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

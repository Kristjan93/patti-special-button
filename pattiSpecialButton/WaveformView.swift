import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let progress: Double
    let barCount: Int

    init(samples: [Float], progress: Double = 0, barCount: Int = Layout.waveformBarCount) {
        self.samples = samples
        self.progress = progress
        self.barCount = barCount
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 1.5
            let totalSpacing = spacing * CGFloat(barCount - 1)
            let barWidth = max(1, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let maxHeight = geo.size.height

            HStack(spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let amplitude = index < samples.count ? CGFloat(samples[index]) : 0
                    let barHeight = max(2, amplitude * maxHeight)
                    let progressThreshold = Double(index) / Double(barCount)
                    let isPlayed = progress > progressThreshold && progress > 0

                    RoundedRectangle(cornerRadius: 1)
                        .fill(isPlayed ? Color.accentColor : Color.secondary.opacity(0.6))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

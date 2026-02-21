import AVFoundation
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
                        .fill(isPlayed ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Audio Sampling

enum WaveformSampler {
    static func sampleAudio(url: URL, barCount: Int = Layout.waveformBarCount) -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return [] }

        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return [] }

        do {
            try audioFile.read(into: buffer)
        } catch {
            return []
        }

        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let totalSamples = Int(buffer.frameLength)
        let samplesPerBar = totalSamples / barCount

        guard samplesPerBar > 0 else { return [] }

        var amplitudes: [Float] = []
        for bar in 0..<barCount {
            let start = bar * samplesPerBar
            let end = min(start + samplesPerBar, totalSamples)
            var sum: Float = 0
            for i in start..<end {
                sum += abs(channelData[i])
            }
            amplitudes.append(sum / Float(end - start))
        }

        // Normalize to 0-1 range
        let maxAmp = amplitudes.max() ?? 1
        if maxAmp > 0 {
            amplitudes = amplitudes.map { $0 / maxAmp }
        }

        return amplitudes
    }
}

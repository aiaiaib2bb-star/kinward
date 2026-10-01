import SwiftUI

/// The shape of a voice. Drawn from real meter samples, not decoration.
struct WaveformView: View {
    var levels: [Double]
    var progress: Double = 0
    var barCount: Int = 58
    var tint: Color = K.sage
    var playedTint: Color = K.sageDeep
    var minBar: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let bars = resample(to: barCount)
            let spacing = max(geo.size.width / CGFloat(barCount) * 0.34, 1.2)
            let w = (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<bars.count, id: \.self) { i in
                    let played = Double(i) / Double(max(bars.count - 1, 1)) <= progress
                    Capsule()
                        .fill(played ? playedTint : tint.opacity(0.38))
                        .frame(width: max(w, 1.2),
                               height: max(minBar, CGFloat(bars[i]) * geo.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func resample(to n: Int) -> [Double] {
        guard !levels.isEmpty else { return Array(repeating: 0.08, count: n) }
        if levels.count <= n {
            return levels + Array(repeating: 0.05, count: n - levels.count)
        }
        let bucket = Double(levels.count) / Double(n)
        return (0..<n).map { i in
            let lo = Int(Double(i) * bucket), hi = min(Int(Double(i + 1) * bucket), levels.count)
            guard lo < hi else { return 0.05 }
            return levels[lo..<hi].max() ?? 0.05
        }
    }
}

/// Live bars while recording — reads from the tail of the buffer so it moves.
struct LiveWaveform: View {
    var levels: [Double]
    var isPaused: Bool
    private let count = 44
    var body: some View {
        let tail = Array(levels.suffix(count))
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                let v = i < count - tail.count ? 0.04 : tail[i - (count - tail.count)]
                Capsule()
                    .fill(isPaused ? K.inkFaint.opacity(0.4) : K.sageDeep.opacity(0.85))
                    .frame(width: 3, height: max(3, CGFloat(v) * 74))
            }
        }
        .frame(height: 78)
        .animation(.linear(duration: 0.06), value: levels.count)
    }
}

/// A playable recording, as it appears everywhere in the archive.
struct VoiceBar: View {
    let recording: VoiceRecording
    var compact: Bool = false
    @State private var player = VoicePlayer.shared

    var body: some View {
        let isMine = player.playingRef == recording.fileRef
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                player.toggle(ref: recording.fileRef)
            } label: {
                Image(systemName: isMine && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(K.onAccent)
                    .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
                    .background(Circle().fill(K.sageDeep))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                if !recording.title.isEmpty && !compact {
                    Text(recording.title).font(KType.body(14).weight(.medium)).foregroundStyle(K.ink).lineLimit(1)
                }
                WaveformView(levels: recording.levels,
                             progress: isMine ? player.progress : 0)
                    .frame(height: compact ? 22 : 30)
            }
            Text(isMine ? timeText(player.currentTime) : recording.durationText)
                .font(.sans(12, .medium).monospacedDigit())
                .foregroundStyle(K.inkSoft)
        }
        .padding(.horizontal, 14).padding(.vertical, compact ? 10 : 14)
        .cardSurface(radius: 18, fill: K.bgDeep.opacity(0.5))
    }
    private func timeText(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

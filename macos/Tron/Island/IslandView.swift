import SwiftUI

struct IslandView: View {
    @ObservedObject var model: IslandController.Model

    private var hasNotch: Bool { model.notch.height > 0 }
    /// Without a notch the island hangs from the top edge of the screen.
    private var topBand: CGFloat { hasNotch ? model.notch.height : 6 }
    private var baseWidth: CGFloat { hasNotch ? model.notch.width : 120 }

    private var size: CGSize {
        switch model.stage {
        case .hidden: return CGSize(width: baseWidth, height: hasNotch ? model.notch.height : 0)
        case .listening, .transcribing: return CGSize(width: baseWidth + 40, height: topBand + 34)
        case .pasted: return CGSize(width: baseWidth + 20, height: topBand + 30)
        case .copied, .error: return CGSize(width: max(baseWidth + 60, 240), height: topBand + 34)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16, style: .continuous)
                    .fill(Color.black)
                content
                    .frame(height: size.height - topBand)
                    .padding(.horizontal, 16)
                    .opacity(model.stage == .hidden ? 0 : 1)
            }
            .frame(width: size.width, height: size.height)
            .opacity(model.stage == .hidden && !hasNotch ? 0 : 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        switch model.stage {
        case .hidden:
            EmptyView()
        case .listening:
            HStack(spacing: 8) {
                Waveform(bands: model.bands)
                if model.locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        case .transcribing:
            TranscribingDots()
        case .pasted:
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.5, green: 0.77, blue: 0.66))
        case .copied:
            HStack(spacing: 6) {
                Text("Copié")
                    .foregroundStyle(.white.opacity(0.7))
                Text("⌘ V")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
            }
            .font(.system(size: 12))
        case .error(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }
}

/// One bar per frequency band of the voice, low pitches on the left. Same width as before (24 bars).
private struct Waveform: View {
    var bands: [Float]
    private let count = Spectrum.bandCount

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 3 + CGFloat(i < bands.count ? bands[i] : 0) * 16)
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.08), value: bands)
    }
}

private struct TranscribingDots: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.white)
                        .frame(width: 5, height: 5)
                        .opacity(0.3 + 0.7 * max(0, sin(t * 5 - Double(i) * 0.7)))
                }
            }
        }
    }
}

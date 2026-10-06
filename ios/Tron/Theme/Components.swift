import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = TronColor.brand
    var text: Color = TronColor.onBrand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TronFont.bodyStrong)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: Radius.md))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TronFont.bodyStrong)
            .foregroundStyle(TronColor.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(TronColor.lineStrong, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = TronColor.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TronFont.bodyStrong)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(TronColor.line, lineWidth: 1))
    }
}

extension View {
    func tronCard() -> some View { modifier(CardModifier()) }
}

/// Mono pill, used for "sur l'appareil" and model info.
struct Badge: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)) }
            Text(text)
        }
        .font(TronFont.meta)
        .foregroundStyle(TronColor.brand)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TronColor.brandTint, in: Capsule())
    }
}

/// The Tron mark: four rounded waveform bars ending in a `live` dot.
/// When `speaking` is on, the bars move like a voice (welcome screen).
struct TronMark: View {
    var height: CGFloat = 44
    var speaking = false

    private let bars: [CGFloat] = [15, 30, 45, 25]

    var body: some View {
        let unit = height / 45
        TimelineView(.animation(paused: !speaking)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3.75 * unit) {
                ForEach(bars.indices, id: \.self) { i in
                    let wobble = speaking ? 0.65 + 0.35 * abs(sin(t * 3.2 + Double(i) * 1.3)) : 1
                    Capsule()
                        .fill(TronColor.brand)
                        .frame(width: 7.5 * unit, height: bars[i] * unit * wobble)
                }
                Circle()
                    .fill(TronColor.live)
                    .frame(width: 11.24 * unit, height: 11.24 * unit)
                    .padding(.leading, 3 * unit)
            }
            .frame(height: height)
        }
        .accessibilityHidden(true)
    }
}

/// Live waveform built from recent input levels (0...1).
struct WaveformView: View {
    let levels: [Float]
    var color: Color = TronColor.live
    var barCount = 28
    var height: CGFloat = 96

    var body: some View {
        let recent = Array(levels.suffix(barCount))
        let padded = Array(repeating: Float(0), count: max(0, barCount - recent.count)) + recent
        HStack(alignment: .center, spacing: 4) {
            ForEach(padded.indices, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(8, CGFloat(padded[i]) * height))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.08), value: levels.count)
        .accessibilityHidden(true)
    }
}

/// Grouped settings-style container.
struct TronGroup<Content: View>: View {
    var header: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                Text(header)
                    .font(TronFont.caption.weight(.medium))
                    .foregroundStyle(TronColor.muted)
                    .padding(.horizontal, Space.s4)
                    .padding(.top, Space.s3)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) { content }
                .tronCard()
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            if let footer {
                Text(footer)
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
                    .padding(.horizontal, Space.s4)
                    .padding(.top, 6)
            }
        }
    }
}

struct RowDivider: View {
    var body: some View { Rectangle().fill(TronColor.line).frame(height: 1) }
}

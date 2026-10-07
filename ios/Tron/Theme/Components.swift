import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
                    .font(TronFont.sans(12, .medium))
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

#if canImport(UIKit)
// iOS navigation chrome (the Mac app has its own window layout).

/// A pushed screen as designed: "‹ Back" text link in brand, then a large title, then the content.
struct TronScreen<Content: View>: View {
    let back: String
    var title: String? = nil
    var spacing: CGFloat = Space.s2
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                if let title {
                    Text(title)
                        .font(TronFont.large)
                        .foregroundStyle(TronColor.ink)
                        .padding(.bottom, 4)
                        .accessibilityAddTraits(.isHeader)
                }
                content
            }
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s8)
        }
        .background(TronColor.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { BackLink(title: back) { dismiss() } }
    }
}

/// A trailing toolbar item without the iOS 26 glass bubble.
struct PlainTrailingItem<Content: View>: ToolbarContent {
    @ViewBuilder var content: Content

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) { content }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) { content }
        }
    }
}

/// "‹ Réglages" in the navigation bar, without the iOS 26 glass bubble.
struct BackLink: ToolbarContent {
    let title: String
    let action: () -> Void

    var body: some ToolbarContent {
        if #available(iOS 26, *) {
            item.sharedBackgroundVisibility(.hidden)
        } else {
            item
        }
    }

    private var item: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    Text(title).font(TronFont.bodyStrong)
                }
                .foregroundStyle(TronColor.brand)
            }
            .accessibilityLabel("Retour, \(title)")
        }
    }
}

/// Keeps the swipe-back gesture when a screen hides the system back button.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif

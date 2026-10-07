import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Dictation in progress, shown in the Dynamic Island and on the Lock Screen.
struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(TronColor.surface)
                .activitySystemActionForegroundColor(TronColor.ink)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniMark(height: 22)
                        .padding(.leading, Space.s1)
                        .padding(.top, Space.s1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.phase == .recording {
                        Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                            .font(TronFont.meta)
                            .monospacedDigit()
                            .foregroundStyle(TronColor.live)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 52)
                            .padding(.top, Space.s1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: Space.s3) {
                        StatusView(state: state, large: true)
                        Spacer(minLength: 0)
                        if state.phase == .recording || state.phase == .ready { StopButton(endsSession: state.phase == .ready) }
                    }
                    .padding(.horizontal, Space.s1)
                }
            } compactLeading: {
                switch state.phase {
                case .recording:
                    // The waveform runs across the whole island: older half on the left, newest on the right.
                    Levels(levels: Array(padded(state.levels, 16).prefix(8)), count: 8, height: 18)
                case .transcribing, .ready:
                    MiniMark(height: 14)
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(TronColor.brand)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(TronColor.danger)
                }
            } compactTrailing: {
                switch state.phase {
                case .recording:
                    Levels(levels: Array(padded(state.levels, 16).suffix(8)), count: 8, height: 18)
                case .transcribing:
                    ProgressView().progressViewStyle(.circular).tint(TronColor.live).scaleEffect(0.7)
                case .ready:
                    Image(systemName: "mic.fill").font(.system(size: 12)).foregroundStyle(TronColor.brand)
                case .done:
                    Text(state.message ?? "Prêt").font(TronFont.label).foregroundStyle(TronColor.brand)
                case .failed:
                    Text("Échec").font(TronFont.label).foregroundStyle(TronColor.danger)
                }
            } minimal: {
                Circle().fill(state.phase == .recording ? TronColor.live : TronColor.brand).frame(width: 10, height: 10)
            }
            .keylineTint(TronColor.live)
        }
    }
}

private struct LockScreenView: View {
    let state: DictationAttributes.ContentState

    var body: some View {
        HStack(spacing: Space.s3) {
            MiniMark(height: 26)
            StatusView(state: state, large: false)
            Spacer(minLength: 0)
            if state.phase == .recording {
                Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                    .font(TronFont.meta)
                    .monospacedDigit()
                    .foregroundStyle(TronColor.live)
                    .frame(width: 44)
                StopButton(endsSession: false)
            } else if state.phase == .ready {
                StopButton(endsSession: true)
            }
        }
        .padding(Space.s4)
    }
}

private struct StatusView: View {
    let state: DictationAttributes.ContentState
    let large: Bool

    var body: some View {
        switch state.phase {
        case .recording:
            HStack(spacing: Space.s2) {
                Levels(levels: state.levels, count: large ? 16 : 12, height: large ? 26 : 20)
                Text("Écoute")
                    .font(TronFont.label)
                    .foregroundStyle(TronColor.ink)
            }
        case .ready:
            label("Micro prêt pour le clavier Tron", color: TronColor.muted)
        case .transcribing:
            label("Transcription…", color: TronColor.muted)
        case .done:
            label(state.message ?? "Texte prêt", color: TronColor.brand)
        case .failed:
            label(state.message ?? "La dictée a échoué", color: TronColor.danger)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text).font(TronFont.label).foregroundStyle(color).lineLimit(1)
    }
}

/// Stops the dictation, or turns the armed mic off when no dictation runs.
private struct StopButton: View {
    let endsSession: Bool

    var body: some View {
        Button(intent: StopDictationIntent()) {
            Image(systemName: endsSession ? "xmark" : "stop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(endsSession ? TronColor.ink : TronColor.onLive)
                .frame(width: 36, height: 36)
                .background(Circle().fill(endsSession ? TronColor.line : TronColor.live))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(endsSession ? "Couper le micro" : "Arrêter la dictée")
    }
}

private func padded(_ levels: [Double], _ count: Int) -> [Double] {
    Array((Array(repeating: 0.0, count: count) + levels).suffix(count))
}

/// Live level bars in the live color.
private struct Levels: View {
    let levels: [Double]
    let count: Int
    let height: CGFloat

    var body: some View {
        let values = Array((Array(repeating: 0.0, count: count) + levels).suffix(count))
        HStack(alignment: .center, spacing: 2) {
            ForEach(values.indices, id: \.self) { i in
                Capsule()
                    .fill(TronColor.live)
                    .frame(width: 3, height: max(3, height * values[i]))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The Tron mark: four brand bars and the live dot.
private struct MiniMark: View {
    let height: CGFloat
    private let bars: [CGFloat] = [15, 30, 45, 25]

    var body: some View {
        let unit = height / 45
        HStack(alignment: .center, spacing: 3.75 * unit) {
            ForEach(bars.indices, id: \.self) { i in
                Capsule()
                    .fill(TronColor.brand)
                    .frame(width: 7.5 * unit, height: bars[i] * unit)
            }
            Circle()
                .fill(TronColor.live)
                .frame(width: 11.24 * unit, height: 11.24 * unit)
                .padding(.leading, 3 * unit)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

import SwiftUI

/// The big round mic. Tap: start, tap again: stop. Hold: records while pressed, release to save,
/// slide up to cancel.
struct RecordButton: View {
    @EnvironmentObject private var dictation: DictationController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Reports whether a press-and-hold is in progress, and whether release would cancel it.
    var onHoldChange: (_ holding: Bool, _ willCancel: Bool) -> Void = { _, _ in }

    @State private var pressStart: Date?
    @State private var wasRecordingAtPress = false
    @State private var holding = false
    @State private var willCancel = false
    @State private var pulse = false

    private let size: CGFloat = 96
    private let holdThreshold: TimeInterval = 0.35

    var body: some View {
        let live = dictation.phase == .recording
        let fill = live ? TronColor.live : TronColor.brand
        ZStack {
            ForEach(0..<2) { i in
                Circle()
                    .stroke(fill, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.6 : 1)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 1.2),
                        value: pulse
                    )
            }
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
            Group {
                switch dictation.phase {
                case .idle:
                    Image(systemName: "mic").font(.system(size: 38, weight: .regular))
                case .recording:
                    RoundedRectangle(cornerRadius: 6).frame(width: 30, height: 30)
                case .finishing:
                    ProgressView().tint(TronColor.onBrand)
                }
            }
            .foregroundStyle(live ? TronColor.onLive : TronColor.onBrand)
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .scaleEffect(holding ? 1.12 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: holding)
        .contentShape(Circle())
        .gesture(press)
        .disabled(dictation.phase == .finishing)
        .onAppear { pulse = true }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(live ? "Terminer la note" : "Nouvelle note vocale")
        .accessibilityAction {
            if dictation.isRecording { dictation.stop() } else { dictation.start(mode: .note) }
        }
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    let now = Date()
                    pressStart = now
                    wasRecordingAtPress = dictation.isRecording
                    if !wasRecordingAtPress {
                        dictation.start(mode: .note)
                        // A finger held still sends no more events: flip to hold mode on a timer.
                        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold) {
                            guard pressStart == now, !holding, dictation.isRecording else { return }
                            holding = true
                            onHoldChange(true, false)
                        }
                    }
                }
                guard !wasRecordingAtPress, let start = pressStart else { return }
                let isHold = Date().timeIntervalSince(start) >= holdThreshold
                let cancel = isHold && value.translation.height < -80
                if isHold != holding || cancel != willCancel {
                    holding = isHold
                    willCancel = cancel
                    onHoldChange(isHold, cancel)
                }
            }
            .onEnded { _ in
                defer {
                    pressStart = nil
                    holding = false
                    willCancel = false
                    onHoldChange(false, false)
                }
                guard let start = pressStart else { return }
                if wasRecordingAtPress {
                    // Second tap: finish.
                    dictation.stop()
                } else if Date().timeIntervalSince(start) >= holdThreshold {
                    // Held: release saves, unless slid up to cancel.
                    if willCancel { dictation.cancel() } else { dictation.stop() }
                }
                // Short tap from idle: keep recording until the next tap.
            }
    }
}

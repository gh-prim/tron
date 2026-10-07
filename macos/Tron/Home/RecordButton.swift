import SwiftUI

/// The big round mic. Click: start, click again: stop. Hold: records while pressed, release to save,
/// drag up to cancel.
struct RecordButton: View {
    @EnvironmentObject private var dictation: MacDictation

    var onHoldChange: (_ holding: Bool, _ willCancel: Bool) -> Void = { _, _ in }

    @State private var pressStart: Date?
    @State private var wasRecordingAtPress = false
    @State private var holding = false
    @State private var willCancel = false
    @State private var pulse = false

    private let size: CGFloat = 96
    private let holdThreshold: TimeInterval = 0.35

    /// Only notes use the button; a dictation from fn shows here as busy.
    private var noteRecording: Bool { dictation.phase == .recording && dictation.mode == .note }
    private var busy: Bool { dictation.phase == .transcribing || (dictation.phase == .recording && dictation.mode == .dictation) }

    var body: some View {
        let fill = noteRecording ? TronColor.live : TronColor.brand
        ZStack {
            ForEach(0..<2) { i in
                Circle()
                    .stroke(fill, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.6 : 1)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 1.2), value: pulse)
            }
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
            Group {
                if noteRecording {
                    RoundedRectangle(cornerRadius: 6).frame(width: 30, height: 30)
                } else if busy {
                    ProgressView().controlSize(.small).tint(TronColor.onBrand)
                } else {
                    Image(systemName: "mic").font(.system(size: 38, weight: .regular))
                }
            }
            .foregroundStyle(noteRecording ? TronColor.onLive : TronColor.onBrand)
        }
        .frame(width: size * 1.7, height: size * 1.7)
        .scaleEffect(holding ? 1.08 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: holding)
        .contentShape(Circle())
        .gesture(press)
        .disabled(busy)
        .onAppear { pulse = true }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(noteRecording ? "Terminer la note" : "Nouvelle note vocale")
        .accessibilityAction {
            if noteRecording { dictation.stop() } else { dictation.start(mode: .note) }
        }
    }

    private var press: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    let now = Date()
                    pressStart = now
                    wasRecordingAtPress = noteRecording
                    if !wasRecordingAtPress {
                        dictation.start(mode: .note)
                        // A mouse held still sends no more events: flip to hold mode on a timer.
                        DispatchQueue.main.asyncAfter(deadline: .now() + holdThreshold) {
                            guard pressStart == now, !holding, noteRecording else { return }
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
                    dictation.stop()
                } else if Date().timeIntervalSince(start) >= holdThreshold {
                    if willCancel { dictation.cancel() } else { dictation.stop() }
                }
                // Short click from idle: keep recording until the next click.
            }
    }
}

import Foundation
import UIKit

/// Drives one recording: mic capture, live preview text, final transcription and saving.
@MainActor
final class DictationController: ObservableObject {
    enum Mode {
        /// Big button in the app: creates a note.
        case note
        /// Started from the Action Button shortcut: text goes to the clipboard and history.
        case actionButton
    }

    enum Phase: Equatable {
        case idle
        case recording
        case finishing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var mode: Mode = .note
    @Published private(set) var levels: [Float] = []
    @Published private(set) var liveText = ""
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var errorMessage: String?
    /// Set when a note was just created, so the UI can open it.
    @Published var lastNote: Note?
    /// Set when an Action Button dictation was copied.
    @Published var lastCopied: HistoryItem?

    private let recorder = AudioRecorder()
    private let engine: TranscriptionEngine
    private weak var store: AppStore?
    private var ticker: Timer?
    private var previewTask: Task<Void, Never>?
    private var startedAt = Date()
    private var lastPreview = Date.distantPast

    init(engine: TranscriptionEngine = .shared) {
        self.engine = engine
        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            self.levels.append(level)
            if self.levels.count > 120 { self.levels.removeFirst(self.levels.count - 120) }
        }
    }

    func attach(_ store: AppStore) { self.store = store }

    var isRecording: Bool { phase == .recording }

    func start(mode: Mode) {
        guard phase == .idle else { return }
        guard AudioRecorder.permissionGranted else {
            errorMessage = "Tron n'a pas accès au micro. Autorisez-le dans Réglages, puis Tron."
            return
        }
        guard engine.isReady else {
            errorMessage = "Le modèle se prépare encore. Réessayez dans un instant."
            return
        }
        do {
            try recorder.start()
        } catch {
            errorMessage = "Le micro n'a pas pu démarrer. \(error.localizedDescription)"
            return
        }
        self.mode = mode
        levels = []
        liveText = ""
        elapsed = 0
        startedAt = Date()
        lastPreview = .distantPast
        phase = .recording
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func cancel() {
        guard phase == .recording else { return }
        stopTimers()
        recorder.stop()
        phase = .idle
        liveText = ""
        levels = []
    }

    func stop() {
        guard phase == .recording else { return }
        stopTimers()
        let samples = recorder.stop()
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        phase = .finishing
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard duration >= 0.4 else {
            phase = .idle
            errorMessage = "Enregistrement trop court."
            return
        }

        let language = store?.language ?? .fr
        let mode = self.mode
        Task {
            await previewTask?.value
            do {
                let raw = try await engine.transcribe(samples, language: language)
                guard !raw.isEmpty else {
                    phase = .idle
                    errorMessage = "Aucune parole détectée. L'audio n'a pas été gardé."
                    return
                }
                let cleaned = TextCleaner.clean(raw)
                switch mode {
                case .note:
                    let id = UUID()
                    let fileName = "\(id.uuidString).wav"
                    try? AudioRecorder.writeWAV(samples, to: AppStore.audioURL(for: fileName))
                    let note = Note(
                        id: id,
                        title: TextCleaner.title(for: cleaned),
                        text: cleaned,
                        rawText: raw,
                        duration: duration,
                        audioFileName: fileName,
                        language: language.rawValue
                    )
                    store?.add(note)
                    lastNote = note
                case .actionButton:
                    UIPasteboard.general.string = cleaned
                    let item = HistoryItem(text: cleaned, duration: duration, source: "Bouton Action")
                    store?.addHistory(item)
                    lastCopied = item
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = "La transcription a échoué. \(error.localizedDescription)"
            }
            liveText = ""
            phase = .idle
        }
    }

    private func tick() {
        guard phase == .recording else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        // Refresh the live text about every 1.5 s, one pass at a time.
        guard previewTask == nil, elapsed >= 1.2, Date().timeIntervalSince(lastPreview) >= 1.5 else { return }
        lastPreview = Date()
        let all = recorder.snapshot()
        // Keep the preview fast on long notes: only the last 40 s are re-read live.
        let maxSamples = Int(40 * AudioRecorder.sampleRate)
        let window = all.count > maxSamples ? Array(all.suffix(maxSamples)) : all
        let trimmed = all.count > maxSamples
        let language = store?.language ?? .fr
        previewTask = Task {
            let text = (try? await engine.transcribe(window, language: language)) ?? ""
            if phase == .recording, !text.isEmpty {
                liveText = trimmed ? "… " + text : text
            }
            previewTask = nil
        }
    }

    private func stopTimers() {
        ticker?.invalidate()
        ticker = nil
    }
}

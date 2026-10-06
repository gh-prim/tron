import Foundation
import UIKit

/// Drives one recording: mic capture, live preview text, final transcription and saving.
@MainActor
final class DictationController: ObservableObject {
    static let shared = DictationController()

    enum Mode {
        /// Big button in the app: creates a note.
        case note
        /// Action Button shortcut, in the background: text goes to the Tron keyboard or the clipboard.
        case actionButton
        /// Mic key of the Tron keyboard (opens the app): text goes back to the keyboard.
        case keyboard
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
    /// Set when an Action Button or keyboard dictation was copied.
    @Published var lastCopied: HistoryItem?

    private let recorder = AudioRecorder()
    private let engine: TranscriptionEngine
    private let activity = LiveActivityController()
    private let store: AppStore
    private var ticker: Timer?
    private var previewTask: Task<Void, Never>?
    private var startedAt = Date()
    private var lastPreview = Date.distantPast
    private var lastHeartbeat = Date.distantPast
    private var stopObserver: DarwinObserver?

    private init() {
        engine = TranscriptionEngine.shared
        store = AppStore.shared
        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            self.levels.append(level)
            if self.levels.count > 120 { self.levels.removeFirst(self.levels.count - 120) }
        }
        // Stop button of the Live Activity.
        stopObserver = DarwinObserver(TronShared.Signal.stop) { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        StopDictationIntent.handler = { await DictationController.shared.stop()?.value }
        activity.endAll()
        publish(.idle)
    }

    var isRecording: Bool { phase == .recording }

    func start(mode: Mode) {
        guard phase == .idle else { return }
        guard AudioRecorder.permissionGranted else {
            errorMessage = "Tron n'a pas accès au micro. Autorisez-le dans Réglages, puis Tron."
            return
        }
        if case .failed = engine.state {
            engine.retry()
        } else {
            // Loads the model from cache when the app was launched in the background.
            engine.prepare()
        }
        let now = Date()
        // In the background, iOS only lets the mic start once the Live Activity is up.
        if mode != .note, !activity.start(startedAt: now), UIApplication.shared.applicationState != .active {
            errorMessage = "Activez les Activités en direct pour Tron dans Réglages, puis Tron."
            return
        }
        do {
            try recorder.start()
        } catch {
            print("[Tron] mic start failed: \(error)")
            if mode != .note { activity.endAll() }
            errorMessage = "Le micro n'a pas pu démarrer. \(error.localizedDescription)"
            return
        }
        print("[Tron] start mode=\(mode) state=\(UIApplication.shared.applicationState.rawValue) engine=\(engine.state)")
        self.mode = mode
        levels = []
        liveText = ""
        elapsed = 0
        startedAt = now
        lastPreview = .distantPast
        phase = .recording
        publish(.recording)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
        activity.endAll()
        publish(.idle)
    }

    /// Returns the transcription task, so an intent can wait for it and write the clipboard while it runs.
    @discardableResult
    func stop() -> Task<Void, Never>? {
        guard phase == .recording else { return nil }
        stopTimers()
        let samples = recorder.stop()
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        let startedAt = self.startedAt
        phase = .finishing
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard duration >= 0.4 else {
            phase = .idle
            errorMessage = "Enregistrement trop court."
            activity.finish(.failed, message: "Enregistrement trop court", startedAt: startedAt)
            publish(.idle)
            return nil
        }

        publish(.transcribing)
        activity.transcribing(startedAt: startedAt)
        let language = store.language
        let mode = self.mode
        // Keeps the process alive while Parakeet runs after the mic stops in the background.
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Transcription") {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        return Task {
            defer {
                if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
            }
            await previewTask?.value
            do {
                let t0 = Date()
                try await engine.waitUntilReady()
                let t1 = Date()
                let raw = try await engine.transcribe(samples, language: language)
                print("[Tron] audio=\(String(format: "%.1f", duration))s wait=\(String(format: "%.2f", t1.timeIntervalSince(t0)))s asr=\(String(format: "%.2f", Date().timeIntervalSince(t1)))s bg=\(UIApplication.shared.applicationState != .active) text=\(raw.prefix(60))")
                guard !raw.isEmpty else {
                    finishFailed("Aucune parole détectée. L'audio n'a pas été gardé.", short: "Aucune parole détectée", startedAt: startedAt)
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
                    store.add(note)
                    lastNote = note
                case .actionButton, .keyboard:
                    UIPasteboard.general.string = cleaned
                    let source = mode == .keyboard ? "Clavier Tron" : "Bouton Action"
                    let item = HistoryItem(text: cleaned, duration: duration, source: source)
                    store.addHistory(item)
                    let forKeyboard = mode == .keyboard || store.actionButtonMode == .miniKeyboard
                    publishResult(item, forKeyboard: forKeyboard)
                    activity.finish(.done, message: forKeyboard ? "Texte prêt" : "Copié, prêt à coller", startedAt: startedAt)
                    lastCopied = item
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                print("[Tron] transcription error: \(error)")
                finishFailed("La transcription a échoué. \(error.localizedDescription)", short: "La transcription a échoué", startedAt: startedAt)
                return
            }
            liveText = ""
            phase = .idle
            publish(.idle)
        }
    }

    private func finishFailed(_ message: String, short: String, startedAt: Date) {
        errorMessage = message
        activity.finish(.failed, message: short, startedAt: startedAt)
        liveText = ""
        phase = .idle
        publish(.idle)
    }

    // MARK: App Group

    private func publish(_ state: TronShared.State) {
        let d = TronShared.defaults
        d.set(state.rawValue, forKey: TronShared.Key.state)
        d.set(Date().timeIntervalSince1970, forKey: TronShared.Key.stateAt)
        DarwinSignal.post(TronShared.Signal.state)
    }

    private func publishResult(_ item: HistoryItem, forKeyboard: Bool) {
        let d = TronShared.defaults
        d.set(item.id.uuidString, forKey: TronShared.Key.resultID)
        d.set(item.text, forKey: TronShared.Key.resultText)
        d.set(Date().timeIntervalSince1970, forKey: TronShared.Key.resultAt)
        d.set(forKeyboard, forKey: TronShared.Key.resultForKeyboard)
        DarwinSignal.post(TronShared.Signal.result)
    }

    private func tick() {
        guard phase == .recording else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        if mode != .note { activity.update(levels: levels, startedAt: startedAt) }
        // Heartbeat for the keyboard, about once a second.
        if Date().timeIntervalSince(lastHeartbeat) >= 1 {
            lastHeartbeat = Date()
            publish(.recording)
        }
        // No live preview in the background: it would only slow down the final pass.
        guard UIApplication.shared.applicationState == .active, engine.isReady else { return }
        // Refresh the live text about every 1.5 s, one pass at a time.
        guard previewTask == nil, elapsed >= 1.2, Date().timeIntervalSince(lastPreview) >= 1.5 else { return }
        lastPreview = Date()
        let all = recorder.snapshot()
        // Keep the preview fast on long notes: only the last 40 s are re-read live.
        let maxSamples = Int(40 * AudioRecorder.sampleRate)
        let window = all.count > maxSamples ? Array(all.suffix(maxSamples)) : all
        let trimmed = all.count > maxSamples
        let language = store.language
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

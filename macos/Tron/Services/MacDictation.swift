import AppKit
import Foundation

/// One dictation into another app: mic while fn is held (or locked), Parakeet, then paste at the cursor.
@MainActor
final class MacDictation: ObservableObject {
    static let shared = MacDictation()

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var levels: [Float] = []
    /// Recording keeps going after fn is released (double press).
    @Published private(set) var locked = false

    let island = IslandController()
    private let recorder = AudioRecorder()
    private let engine = TranscriptionEngine.shared
    private let store = MacStore.shared
    private var showIsland: DispatchWorkItem?

    private init() {
        recorder.onLevel = { [weak self] level in
            guard let self, self.phase == .recording else { return }
            self.levels.append(level)
            if self.levels.count > 64 { self.levels.removeFirst(self.levels.count - 64) }
            self.island.model.levels = self.levels
        }
    }

    func start() {
        guard phase == .idle else { return }
        guard Permissions.microphone else {
            island.flash(.error("Micro non autorisé"))
            return
        }
        if case .failed = engine.state { engine.retry() } else { engine.prepare() }
        do {
            try recorder.start()
        } catch {
            print("[Tron] mic start failed: \(error)")
            island.flash(.error("Le micro n'a pas démarré"))
            return
        }
        levels = []
        locked = false
        phase = .recording
        island.model.levels = []
        island.model.locked = false
        // A quick tap (first half of a double press) should not flash the island.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .recording else { return }
            self.island.show(.listening)
        }
        showIsland = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func lock() {
        guard phase == .recording else { return }
        locked = true
        island.model.locked = true
        island.show(.listening)
    }

    func cancel() {
        guard phase == .recording else { return }
        showIsland?.cancel()
        recorder.stop()
        phase = .idle
        locked = false
        island.hide()
    }

    func stop() {
        guard phase == .recording else { return }
        showIsland?.cancel()
        let samples = recorder.stop()
        locked = false
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        guard duration >= 0.4 else {
            phase = .idle
            island.hide()
            return
        }
        phase = .transcribing
        island.show(.transcribing)
        let language = store.language
        Task {
            defer { phase = .idle }
            do {
                let t0 = Date()
                try await engine.waitUntilReady()
                let t1 = Date()
                let raw = Corrections.apply(try await engine.transcribe(samples, language: language))
                print("[Tron] audio=\(String(format: "%.1f", duration))s wait=\(String(format: "%.2f", t1.timeIntervalSince(t0)))s asr=\(String(format: "%.2f", Date().timeIntervalSince(t1)))s text=\(raw.prefix(60))")
                guard !raw.isEmpty else {
                    island.flash(.error("Aucune parole détectée"))
                    return
                }
                let text = TextCleaner.clean(raw)
                let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Mac"
                store.addHistory(HistoryItem(text: text, duration: duration, source: app))
                switch await Paster.insert(text) {
                case .pasted: island.flash(.pasted)
                case .copied: island.flash(.copied)
                }
            } catch {
                print("[Tron] transcription error: \(error)")
                island.flash(.error(engine.isReady ? "La transcription a échoué" : "Modèle pas encore prêt"))
            }
        }
    }
}

/// fn / 🌐 gestures: hold to talk, double press to lock, one press to finish a locked recording.
@MainActor
final class FnGesture {
    private enum State {
        case idle
        /// fn is down, recording started at that moment.
        case pressed(Date)
        /// A short press just ended: a second press soon locks, otherwise the recording is dropped.
        case waitingSecondPress
        case locked
    }

    private let dictation: MacDictation
    private var state = State.idle
    private var pending: DispatchWorkItem?

    /// Longer than this, a press is a hold (push to talk).
    private let holdThreshold: TimeInterval = 0.3
    private let doublePressWindow: TimeInterval = 0.35

    init(dictation: MacDictation) {
        self.dictation = dictation
    }

    func fnDown() {
        switch state {
        case .idle:
            guard dictation.phase == .idle else { return }
            dictation.start()
            if dictation.phase == .recording { state = .pressed(Date()) }
        case .waitingSecondPress:
            pending?.cancel()
            dictation.lock()
            state = .locked
        case .locked:
            state = .idle
            dictation.stop()
        case .pressed:
            break
        }
    }

    func fnUp() {
        guard case .pressed(let at) = state else { return }
        if Date().timeIntervalSince(at) >= holdThreshold {
            state = .idle
            dictation.stop()
            return
        }
        state = .waitingSecondPress
        let work = DispatchWorkItem { [weak self] in
            guard let self, case .waitingSecondPress = self.state else { return }
            self.state = .idle
            self.dictation.cancel()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doublePressWindow, execute: work)
    }

    /// fn + another key: fn was a modifier, not a dictation.
    func chord() {
        guard case .pressed = state else { return }
        state = .idle
        dictation.cancel()
    }

    /// Escape drops the recording. Returns true when there was one.
    func escape() -> Bool {
        guard dictation.phase == .recording else { return false }
        pending?.cancel()
        state = .idle
        dictation.cancel()
        return true
    }
}

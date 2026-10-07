import AppKit
import Foundation

/// Drives one recording on the Mac.
/// `.dictation`: fn in another app, the text is pasted at the cursor. `.note`: the big button, creates a note.
@MainActor
final class MacDictation: ObservableObject {
    static let shared = MacDictation()

    enum Mode { case dictation, note }

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var mode: Mode = .dictation
    @Published private(set) var levels: [Float] = []
    @Published private(set) var elapsed: TimeInterval = 0
    /// Live transcript of a note, with a stable prefix (only grows).
    @Published private(set) var liveText = ""
    /// Recording keeps going after fn is released (double press).
    @Published private(set) var locked = false
    /// Set when a note was just created, so the window can open it.
    @Published var lastNote: Note?
    @Published var errorMessage: String?

    let island = IslandController()
    private let recorder = AudioRecorder()
    private let spectrum = Spectrum()
    private let engine = TranscriptionEngine.shared
    private let store = AppStore.shared
    private var showIsland: DispatchWorkItem?
    private var ticker: Timer?
    private var startedAt = Date()
    private var live = LiveText()
    private var previewTask: Task<Void, Never>?
    private var lastPreview = Date.distantPast
    private var session = UUID()

    var isRecording: Bool { phase == .recording }

    private init() {
        recorder.onLevel = { [weak self] level in
            guard let self, self.phase == .recording else { return }
            self.levels.append(level)
            if self.levels.count > 120 { self.levels.removeFirst(self.levels.count - 120) }
        }
        let spectrum = self.spectrum
        recorder.onChunk = { chunk in spectrum.feed(chunk) }
        spectrum.onBands = { [weak self] bands in
            guard let self, self.phase == .recording, self.mode == .dictation else { return }
            self.island.model.bands = bands
        }
    }

    func start(mode: Mode = .dictation) {
        guard phase == .idle else { return }
        guard Permissions.microphone else {
            fail("Tron n'a pas accès au micro. Autorisez-le dans Réglages Système.", short: "Micro non autorisé", mode: mode)
            return
        }
        if case .failed = engine.state { engine.retry() } else { engine.prepare() }
        do {
            try recorder.start()
        } catch {
            print("[Tron] mic start failed: \(error)")
            fail("Le micro n'a pas pu démarrer. \(error.localizedDescription)", short: "Le micro n'a pas démarré", mode: mode)
            return
        }
        self.mode = mode
        levels = []
        liveText = ""
        elapsed = 0
        locked = false
        live = LiveText()
        session = UUID()
        startedAt = Date()
        lastPreview = .distantPast
        phase = .recording
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        guard mode == .dictation else { return }
        spectrum.reset()
        island.model.bands = []
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
        guard phase == .recording, mode == .dictation else { return }
        locked = true
        island.model.locked = true
        island.show(.listening)
    }

    func cancel() {
        guard phase == .recording else { return }
        endRecording()
        recorder.stop()
        phase = .idle
        liveText = ""
        if mode == .dictation { island.hide() }
    }

    func stop() {
        guard phase == .recording else { return }
        endRecording()
        let samples = recorder.stop()
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        let mode = self.mode
        guard duration >= 0.4 else {
            phase = .idle
            liveText = ""
            if mode == .dictation { island.hide() } else { errorMessage = "Enregistrement trop court." }
            return
        }
        phase = .transcribing
        if mode == .dictation { island.show(.transcribing) }
        let language = store.language
        Task {
            defer {
                phase = .idle
                liveText = ""
            }
            do {
                let t0 = Date()
                try await engine.waitUntilReady()
                let t1 = Date()
                let raw = Corrections.apply(try await engine.transcribe(samples, language: language))
                print("[Tron] mode=\(mode) audio=\(String(format: "%.1f", duration))s wait=\(String(format: "%.2f", t1.timeIntervalSince(t0)))s asr=\(String(format: "%.2f", Date().timeIntervalSince(t1)))s text=\(raw.prefix(60))")
                guard !raw.isEmpty else {
                    fail("Aucune parole détectée. L'audio n'a pas été gardé.", short: "Aucune parole détectée", mode: mode)
                    return
                }
                let text = TextCleaner.clean(raw)
                switch mode {
                case .note:
                    let id = UUID()
                    let fileName = "\(id.uuidString).wav"
                    try? AudioRecorder.writeWAV(samples, to: AppStore.audioURL(for: fileName))
                    let note = Note(
                        id: id,
                        title: TextCleaner.title(for: text),
                        text: text,
                        rawText: raw,
                        duration: duration,
                        audioFileName: fileName,
                        language: language.rawValue
                    )
                    store.add(note)
                    lastNote = note
                case .dictation:
                    let app = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Mac"
                    store.addHistory(HistoryItem(text: text, duration: duration, source: app))
                    switch await Paster.insert(text) {
                    case .pasted: island.flash(.pasted)
                    case .copied: island.flash(.copied)
                    }
                }
            } catch {
                print("[Tron] transcription error: \(error)")
                fail("La transcription a échoué. \(error.localizedDescription)", short: engine.isReady ? "La transcription a échoué" : "Modèle pas encore prêt", mode: mode)
            }
        }
    }

    private func endRecording() {
        showIsland?.cancel()
        ticker?.invalidate()
        ticker = nil
        locked = false
    }

    private func fail(_ message: String, short: String, mode: Mode) {
        if mode == .dictation { island.flash(.error(short)) } else { errorMessage = message }
    }

    /// Notes show the text live under the waveform; dictations in other apps only show the waveform.
    private func tick() {
        guard phase == .recording else { return }
        elapsed = Date().timeIntervalSince(startedAt)
        guard mode == .note, engine.isReady else { return }
        // Refresh about every 200 ms, one pass at a time (a busy tick is simply skipped).
        guard previewTask == nil, elapsed >= 0.4, Date().timeIntervalSince(lastPreview) >= 0.2 else { return }
        lastPreview = Date()
        guard let window = live.window(of: recorder.snapshot()) else { return }
        let language = store.language
        let session = self.session
        previewTask = Task {
            defer { previewTask = nil }
            guard let words = try? await engine.transcribeWords(window.samples, language: language),
                  phase == .recording, self.session == session else { return }
            guard !live.ingest(words, in: window).isEmpty else { return }
            liveText = Corrections.apply(live.text)
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
            dictation.start(mode: .dictation)
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
        guard dictation.phase == .recording, dictation.mode == .dictation else { return false }
        pending?.cancel()
        state = .idle
        dictation.cancel()
        return true
    }
}

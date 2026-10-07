import FluidAudio
import Foundation

/// NVIDIA Parakeet TDT 0.6B v3 running on device through Core ML (FluidAudio).
/// Weights: huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml, downloaded once, then fully offline.
@MainActor
final class TranscriptionEngine: ObservableObject {
    static let shared = TranscriptionEngine()
    static let modelName = "Parakeet 0.6B v3"

    enum State: Equatable {
        case idle
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var manager: AsrManager?
    private var prepareTask: Task<Void, Never>?

    var isReady: Bool { state == .ready }

    /// Downloads (first launch only) and compiles the model. Safe to call many times.
    func prepare() {
        guard prepareTask == nil, manager == nil else { return }
        prepareTask = Task { [weak self] in
            guard let self else { return }
            do {
                self.state = .downloading(0)
                let models = try await AsrModels.downloadAndLoad(version: .v3) { progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        if case .compiling = progress.phase {
                            self.state = .loading
                        } else {
                            self.state = .downloading(progress.fractionCompleted)
                        }
                    }
                }
                self.state = .loading
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                self.manager = manager
                self.state = .ready
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.prepareTask = nil
        }
    }

    /// Waits for `prepare()` to finish (model loaded from cache in the background path).
    func waitUntilReady(timeout: TimeInterval = 90) async throws {
        prepare()
        let deadline = Date().addingTimeInterval(timeout)
        while !isReady {
            if case .failed(let message) = state { throw EngineError.failed(message) }
            if Date() > deadline { throw EngineError.notReady }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    func retry() {
        guard case .failed = state else { return }
        state = .idle
        prepare()
    }

    /// Transcribes 16 kHz mono samples. Returns an empty string for silence or very short audio.
    func transcribe(_ samples: [Float], language: SpokenLanguage) async throws -> String {
        guard let manager else { throw EngineError.notReady }
        // Parakeet needs at least one second of audio; pad short clips with silence.
        var audio = samples
        if audio.count < 16_000 { audio += [Float](repeating: 0, count: 16_000 - audio.count) }
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(audio, decoderState: &state, language: Language(rawValue: language.rawValue))
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct Word {
        var text: String
        var start: TimeInterval
        var end: TimeInterval
    }

    /// Same pass, as words with their timing in the clip (for the live preview's stable prefix).
    func transcribeWords(_ samples: [Float], language: SpokenLanguage) async throws -> [Word] {
        guard let manager else { throw EngineError.notReady }
        var audio = samples
        if audio.count < 16_000 { audio += [Float](repeating: 0, count: 16_000 - audio.count) }
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(audio, decoderState: &state, language: Language(rawValue: language.rawValue))
        var words: [Word] = []
        for timing in result.tokenTimings ?? [] {
            let piece = timing.token.replacingOccurrences(of: "\u{2581}", with: " ")
            let text = piece.trimmingCharacters(in: .whitespaces)
            if piece.hasPrefix(" ") || words.isEmpty {
                guard !text.isEmpty else { continue }
                words.append(Word(text: text, start: timing.startTime, end: timing.endTime))
            } else {
                words[words.count - 1].text += text
                words[words.count - 1].end = timing.endTime
            }
        }
        return words
    }

    enum EngineError: LocalizedError {
        case notReady
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .notReady: return "Le modèle n'est pas encore prêt."
            case .failed(let message): return message
            }
        }
    }
}

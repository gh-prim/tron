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

    enum EngineError: LocalizedError {
        case notReady
        var errorDescription: String? { "Le modèle n'est pas encore prêt." }
    }
}

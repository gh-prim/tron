import ActivityKit
import AppIntents
import Foundation

/// Live Activity shown while a dictation runs outside the app (Action Button or Tron keyboard).
struct DictationAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case recording, transcribing, done, failed
        }

        var phase: Phase
        var startedAt: Date
        /// Last microphone levels, 0...1, oldest first.
        var levels: [Double]
        var message: String?
    }
}

/// Stop button of the Live Activity. Runs in the app process; the recording side listens to the signal.
struct StopDictationIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Arrêter la dictée"
    static var isDiscoverable = false

    /// Set by the app; runs the stop in-process so the result can reach the clipboard.
    @MainActor static var handler: (() async -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let handler = Self.handler {
            await handler()
        } else {
            DarwinSignal.post(TronShared.Signal.stop)
        }
        return .result()
    }
}

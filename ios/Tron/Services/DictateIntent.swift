import AppIntents
import Foundation

/// "Dicter avec Tron": the shortcut users assign to the Action Button.
/// First press starts listening in the background (Live Activity in the Dynamic Island), second press stops.
/// The text is typed at the cursor by the Tron keyboard when it is shown, and always copied.
struct DictateIntent: AudioRecordingIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Dicter avec Tron"
    static var description = IntentDescription("Démarre ou arrête une dictée Tron sans ouvrir l'app.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let dictation = DictationController.shared
        if dictation.isRecording {
            dictation.stop()
            return .result()
        }
        guard AudioRecorder.permissionGranted else { throw DictateError.noMicrophone }
        dictation.start(mode: .actionButton)
        if let message = dictation.errorMessage, !dictation.isRecording {
            dictation.errorMessage = nil
            throw DictateError.failed(message)
        }
        return .result()
    }

    enum DictateError: Error, CustomLocalizedStringResourceConvertible {
        case noMicrophone
        case failed(String)

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .noMicrophone: return "Ouvrez Tron une fois pour autoriser le micro."
            case .failed(let message): return "\(message)"
            }
        }
    }
}

struct TronShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: ["Dicter avec \(.applicationName)", "Dictate with \(.applicationName)"],
            shortTitle: "Dicter avec Tron",
            systemImageName: "mic.fill"
        )
    }
}

/// Bridges a tron://dictate launch (Tron keyboard mic key) to the UI.
@MainActor
final class PendingLaunch: ObservableObject {
    static let shared = PendingLaunch()
    @Published var dictateRequested = false
}

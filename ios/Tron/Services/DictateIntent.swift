import AppIntents
import Foundation

/// "Dicter avec Tron": the shortcut users assign to the Action Button.
/// It opens Tron and starts listening right away. In this test build the text is copied to the clipboard;
/// the Tron mini keyboard (auto-insert at the cursor) comes with the keyboard extension.
struct DictateIntent: AppIntent {
    static var title: LocalizedStringResource = "Dicter avec Tron"
    static var description = IntentDescription("Démarre une dictée Tron. Le texte est copié, prêt à coller.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingLaunch.shared.dictateRequested = true
        return .result()
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

/// Bridges the intent to the UI.
@MainActor
final class PendingLaunch: ObservableObject {
    static let shared = PendingLaunch()
    @Published var dictateRequested = false
}

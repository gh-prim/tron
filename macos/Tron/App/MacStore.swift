import Foundation

/// Storage for the shared core (Corrections). No App Group on the Mac: the app's own defaults.
enum TronShared {
    static var defaults: UserDefaults { .standard }
}

/// Settings and dictation history, kept on this Mac.
@MainActor
final class MacStore: ObservableObject {
    static let shared = MacStore()

    private enum Key {
        static let language = "language"
        static let history = "history"
        static let onboarded = "onboarded"
    }

    @Published var language: SpokenLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Key.language) }
    }

    /// Everything dictated in other apps, newest first, to recover a text that was not pasted.
    @Published private(set) var history: [HistoryItem]

    var onboarded: Bool {
        get { UserDefaults.standard.bool(forKey: Key.onboarded) }
        set { UserDefaults.standard.set(newValue, forKey: Key.onboarded) }
    }

    private init() {
        let d = UserDefaults.standard
        language = d.string(forKey: Key.language).flatMap(SpokenLanguage.init(rawValue:)) ?? .deviceDefault
        if let data = d.data(forKey: Key.history), let list = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = list
        } else {
            history = []
        }
    }

    func addHistory(_ item: HistoryItem) {
        history.insert(item, at: 0)
        if history.count > 50 { history.removeLast(history.count - 50) }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Key.history)
        }
    }
}

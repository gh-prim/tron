import Foundation

struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var title: String
    /// Cleaned text: punctuation fixed, fillers like "euh" removed.
    var text: String
    /// Exactly what Parakeet returned.
    var rawText: String
    var duration: TimeInterval
    var audioFileName: String?
    var language: String

    var wordCount: Int { text.split(whereSeparator: { $0.isWhitespace }).count }
}

/// Dictations made in other apps (Tron keyboard, Action Button). Kept separate from notes.
struct HistoryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var text: String
    var duration: TimeInterval
    var source: String
}

enum SpokenLanguage: String, CaseIterable, Identifiable, Codable {
    case fr, en, de, es, it

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .it: return "Italiano"
        }
    }

    /// Language of the phone when it is one Tron supports, else French.
    static var deviceDefault: SpokenLanguage {
        let code = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "fr"
        return SpokenLanguage(rawValue: code) ?? .fr
    }
}

enum ActionButtonMode: String, CaseIterable, Identifiable, Codable {
    case miniKeyboard, clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .miniKeyboard: return "Clavier Tron mini"
        case .clipboard: return "Mon clavier habituel"
        }
    }

    var detail: String {
        switch self {
        case .miniKeyboard: return "Le texte s'écrit tout seul au curseur. Le clavier Tron doit être affiché."
        case .clipboard: return "Le texte est copié. Vous touchez le champ, puis Coller."
        }
    }
}

/// How long the mic stays armed in the background after Tron was used, so the keyboard Tron key starts
/// dictating without opening the app.
enum MicSession: String, CaseIterable, Identifiable, Codable {
    case quarter, hour, fourHours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quarter: return "15 minutes"
        case .hour: return "1 heure"
        case .fourHours: return "4 heures"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .quarter: return 15 * 60
        case .hour: return 60 * 60
        case .fourHours: return 4 * 60 * 60
        }
    }
}

enum HistoryRetention: String, CaseIterable, Identifiable, Codable {
    case day, week, month, forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "24 heures"
        case .week: return "7 jours"
        case .month: return "30 jours"
        case .forever: return "Toujours"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .day: return 86_400
        case .week: return 7 * 86_400
        case .month: return 30 * 86_400
        case .forever: return nil
        }
    }
}

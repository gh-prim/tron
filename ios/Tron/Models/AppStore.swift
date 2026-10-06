import Foundation
import SwiftUI

/// Profile, settings, notes and history. Everything stays on the device (no Supabase in this build).
@MainActor
final class AppStore: ObservableObject {
    /// One store for the UI and for dictations started in the background (Action Button).
    static let shared = AppStore()

    private let defaults = UserDefaults.standard

    @Published var onboardingDone: Bool { didSet { defaults.set(onboardingDone, forKey: "onboardingDone") } }
    @Published var firstName: String { didSet { defaults.set(firstName, forKey: "firstName") } }
    @Published var languageCode: String {
        didSet {
            defaults.set(languageCode, forKey: "language")
            TronShared.defaults.set(languageCode, forKey: TronShared.Key.language)
        }
    }
    @Published var micGranted: Bool { didSet { defaults.set(micGranted, forKey: "micGranted") } }
    @Published var actionButtonModeRaw: String {
        didSet {
            defaults.set(actionButtonModeRaw, forKey: "actionButtonMode")
            TronShared.defaults.set(actionButtonModeRaw, forKey: TronShared.Key.actionButtonMode)
        }
    }
    @Published var micSessionRaw: String { didSet { defaults.set(micSessionRaw, forKey: "micSession") } }
    @Published var historyRetentionRaw: String { didSet { defaults.set(historyRetentionRaw, forKey: "historyRetention") } }
    @Published var analyticsOptIn: Bool { didSet { defaults.set(analyticsOptIn, forKey: "analyticsOptIn") } }

    @Published private(set) var notes: [Note] = []
    @Published private(set) var history: [HistoryItem] = []

    var language: SpokenLanguage {
        get { SpokenLanguage(rawValue: languageCode) ?? .fr }
        set { languageCode = newValue.rawValue }
    }

    var actionButtonMode: ActionButtonMode {
        get { ActionButtonMode(rawValue: actionButtonModeRaw) ?? .miniKeyboard }
        set { actionButtonModeRaw = newValue.rawValue }
    }

    var micSession: MicSession {
        get { MicSession(rawValue: micSessionRaw) ?? .hour }
        set { micSessionRaw = newValue.rawValue }
    }

    var historyRetention: HistoryRetention {
        get { HistoryRetention(rawValue: historyRetentionRaw) ?? .month }
        set {
            historyRetentionRaw = newValue.rawValue
            pruneHistory()
        }
    }

    private init() {
        let d = UserDefaults.standard
        onboardingDone = d.bool(forKey: "onboardingDone")
        firstName = d.string(forKey: "firstName") ?? ""
        languageCode = d.string(forKey: "language") ?? SpokenLanguage.deviceDefault.rawValue
        micGranted = d.bool(forKey: "micGranted")
        actionButtonModeRaw = d.string(forKey: "actionButtonMode") ?? ActionButtonMode.miniKeyboard.rawValue
        micSessionRaw = d.string(forKey: "micSession") ?? MicSession.hour.rawValue
        historyRetentionRaw = d.string(forKey: "historyRetention") ?? HistoryRetention.month.rawValue
        analyticsOptIn = d.bool(forKey: "analyticsOptIn")
        TronShared.defaults.set(languageCode, forKey: TronShared.Key.language)
        TronShared.defaults.set(actionButtonModeRaw, forKey: TronShared.Key.actionButtonMode)
        notes = Self.load([Note].self, from: Self.notesURL) ?? []
        history = Self.load([HistoryItem].self, from: Self.historyURL) ?? []
        pruneHistory()
    }

    // MARK: Notes

    func add(_ note: Note) {
        notes.insert(note, at: 0)
        save()
    }

    func update(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i] = note
        save()
    }

    func delete(_ note: Note) {
        if let name = note.audioFileName {
            try? FileManager.default.removeItem(at: Self.audioURL(for: name))
        }
        notes.removeAll { $0.id == note.id }
        save()
    }

    // MARK: History

    func addHistory(_ item: HistoryItem) {
        history.insert(item, at: 0)
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    private func pruneHistory() {
        guard let interval = historyRetention.interval else { return }
        let limit = Date().addingTimeInterval(-interval)
        let before = history.count
        history.removeAll { $0.createdAt < limit }
        if history.count != before { save() }
    }

    // MARK: Stats (computed on device)

    struct WeekStats {
        var words: Int
        var minutesSaved: Int
        var wordsPerMinute: Int
    }

    /// Time saved compares speaking with typing on a phone, about 40 words per minute.
    var weekStats: WeekStats {
        let since = Date().addingTimeInterval(-7 * 86_400)
        var words = 0
        var seconds: TimeInterval = 0
        for note in notes where note.createdAt >= since {
            words += note.wordCount
            seconds += note.duration
        }
        for item in history where item.createdAt >= since {
            words += item.text.split(whereSeparator: \.isWhitespace).count
            seconds += item.duration
        }
        let typingMinutes = Double(words) / 40
        let saved = max(0, Int((typingMinutes - seconds / 60).rounded()))
        let wpm = seconds > 0 ? Int((Double(words) / (seconds / 60)).rounded()) : 0
        return WeekStats(words: words, minutesSaved: saved, wordsPerMinute: wpm)
    }

    // MARK: Reset (Réglages)

    func resetEverything() {
        for note in notes { if let n = note.audioFileName { try? FileManager.default.removeItem(at: Self.audioURL(for: n)) } }
        notes = []
        history = []
        save()
        firstName = ""
        onboardingDone = false
    }

    // MARK: Files

    private func save() {
        Self.write(notes, to: Self.notesURL)
        Self.write(history, to: Self.historyURL)
    }

    static var supportDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tron", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var audioDirectory: URL {
        let url = supportDirectory.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func audioURL(for fileName: String) -> URL { audioDirectory.appendingPathComponent(fileName) }

    private static var notesURL: URL { supportDirectory.appendingPathComponent("notes.json") }
    private static var historyURL: URL { supportDirectory.appendingPathComponent("history.json") }

    private static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

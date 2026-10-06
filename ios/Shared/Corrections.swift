import Foundation

/// One entry of the correction dictionary: what Parakeet writes, and what it should be.
struct Correction: Identifiable, Codable, Hashable {
    var id = UUID()
    var heard: String
    var correct: String
    var createdAt = Date()
}

/// Correction dictionary, shared by the app, the Tron keyboard and the share extension (App Group).
enum Corrections {
    private static let key = "corrections"

    static func all() -> [Correction] {
        guard let data = TronShared.defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([Correction].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [Correction]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        TronShared.defaults.set(data, forKey: key)
    }

    /// Adds or updates the entry for `heard` (case-insensitive). Ignored when both forms are the same.
    static func add(heard: String, correct: String) {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let correct = correct.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !correct.isEmpty, heard != correct else { return }
        var list = all()
        if let i = list.firstIndex(where: { $0.heard.caseInsensitiveCompare(heard) == .orderedSame }) {
            list[i].heard = heard
            list[i].correct = correct
            list[i].createdAt = Date()
        } else {
            list.insert(Correction(heard: heard, correct: correct), at: 0)
        }
        save(list)
    }

    /// Replaces every whole-word (or whole-phrase) occurrence, ignoring case.
    /// A capital at the start of the match is kept ("Tronc" at a sentence start gives "Tron").
    static func apply(_ text: String, using list: [Correction] = all()) -> String {
        guard !list.isEmpty, !text.isEmpty else { return text }
        var result = text
        // Longer forms first, so "tronc ios" wins over "tronc".
        for entry in list.sorted(by: { $0.heard.count > $1.heard.count }) {
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: entry.heard) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
            guard !matches.isEmpty else { continue }
            let mutable = NSMutableString(string: result)
            for match in matches.reversed() {
                let found = ns.substring(with: match.range)
                var replacement = entry.correct
                if let first = found.first, first.isUppercase, let r = replacement.first, r.isLowercase {
                    replacement = r.uppercased() + replacement.dropFirst()
                }
                mutable.replaceCharacters(in: match.range, with: replacement)
            }
            result = mutable as String
        }
        return result
    }
}

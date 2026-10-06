import Foundation

/// Light on-device cleanup. Parakeet v3 already outputs punctuation and capitals;
/// here we drop hesitations ("euh", "hum", "uh"...) and build a short title.
enum TextCleaner {
    private static let fillers = [
        "euh", "heu", "euhm", "hum", "hmm", "hm", "mmh",
        "uh", "uhm", "um", "umm", "erm", "äh", "ähm", "ehm",
    ]

    static func clean(_ raw: String) -> String {
        var text = raw
        let alternation = fillers.joined(separator: "|")
        // A filler as a whole word, with the commas around it ("je voulais, euh, réserver").
        let pattern = "(?i)\\s*,?\\s*(?<![\\p{L}\\p{N}'])(?:\(alternation))(?![\\p{L}\\p{N}'])\\s*[,…]?"
        text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        // Tidy whitespace and stray punctuation left behind.
        text = text.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+([,.])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^[\\s,.]+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: ",\\s*([.?!])", with: "$1", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return capitalizeSentences(text)
    }

    static func title(for text: String, fallbackDate: Date = Date()) -> String {
        let firstSentence = text
            .split(whereSeparator: { ".?!\n".contains($0) })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let words = firstSentence.split(separator: " ")
        guard !words.isEmpty else {
            return "Note du " + fallbackDate.formatted(date: .abbreviated, time: .shortened)
        }
        var title = words.prefix(7).joined(separator: " ")
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: ",;: "))
        if words.count > 7 { title += "…" }
        return title.prefix(1).uppercased() + title.dropFirst()
    }

    private static func capitalizeSentences(_ text: String) -> String {
        var result = ""
        var capitalizeNext = true
        for ch in text {
            if capitalizeNext, ch.isLetter {
                result += ch.uppercased()
                capitalizeNext = false
            } else {
                result.append(ch)
                if ".?!".contains(ch) { capitalizeNext = true }
            }
        }
        return result
    }
}

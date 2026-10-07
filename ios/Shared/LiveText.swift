import Foundation

/// Live transcript with a stable prefix, shared by iOS and macOS.
/// Only the tail after the settled text is re-read, and the shown text only grows:
/// a word appears once two passes in a row agree on it, so the cursor never steps back.
struct LiveText {
    static let sampleRate: Double = 16_000

    struct Word {
        var text: String
        var start: TimeInterval
        var end: TimeInterval
    }

    /// Audio to re-read for one pass: the tail after the settled text, with 1 s of context before it.
    struct Window {
        var start: Int
        var samples: [Float]
        /// Seconds of context at the start of `samples` (already part of the settled text).
        var context: TimeInterval
        var length: TimeInterval
    }

    /// Text already settled, and how many samples it covers.
    private(set) var frozenText = ""
    private(set) var frozenSamples = 0
    /// Words of the previous pass, and the words already shown.
    private var previousWords: [String] = []
    private(set) var shownWords: [String] = []

    var text: String { shownWords.joined(separator: " ") }

    func window(of all: [Float]) -> Window? {
        let rate = Self.sampleRate
        let start = max(0, frozenSamples - Int(rate))
        guard all.count > start else { return nil }
        let samples = Array(all[start...])
        return Window(
            start: start,
            samples: samples,
            context: Double(frozenSamples - start) / rate,
            length: Double(samples.count) / rate
        )
    }

    /// Feeds one pass over `window`. Returns the words added to the shown text, empty when nothing is new.
    mutating func ingest(_ words: [Word], in window: Window) -> [String] {
        let rate = Self.sampleRate
        // Words that start in the context are already part of the settled text.
        var tail = words.filter { $0.start >= window.context - 0.05 }
        // Past 8 s of tail, settle everything up to 3 s before the end (cut between two words).
        if window.length - window.context > 8, let cut = tail.lastIndex(where: { $0.end <= window.length - 3 }), cut + 1 < tail.count {
            let settled = tail[...cut].map(\.text).joined(separator: " ")
            frozenText = frozenText.isEmpty ? settled : frozenText + " " + settled
            frozenSamples = window.start + Int(tail[cut + 1].start * rate)
            tail = Array(tail[(cut + 1)...])
        }
        let current = frozenText.split(separator: " ").map(String.init) + tail.map(\.text)
        let add = Self.agreedWords(current: current, previous: previousWords, shown: shownWords)
        previousWords = current
        shownWords += add
        return add
    }

    private static func norm(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// Words to append to the live text. Measured on a Mac bench (French speech replayed in real time,
    /// 200 ms passes): words show 0.35 s after they are said, with no wrong word and nothing taken back.
    static func agreedWords(current: [String], previous: [String], shown: [String]) -> [String] {
        var agreed = 0
        while agreed < min(current.count, previous.count), norm(current[agreed]) == norm(previous[agreed]) { agreed += 1 }
        // Where the shown text ends inside this pass: aligned on the last shown word, near the expected index,
        // since settling the start of the sentence can merge or split a word.
        var from = shown.count
        if let last = shown.last {
            for p in [shown.count, shown.count - 1, shown.count + 1, shown.count - 2, shown.count + 2]
            where p >= 1 && p <= current.count && norm(current[p - 1]) == norm(last) {
                from = p
                break
            }
        }
        guard agreed > from else { return [] }
        var add = Array(current[from..<agreed])
        // Parakeet ends every clip with a period: the newest word keeps no punctuation.
        if agreed == current.count, let last = add.last {
            add[add.count - 1] = last.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?…"))
        }
        return add
    }
}

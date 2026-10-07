import SwiftUI

// MARK: - Rows

struct StatsRow: View {
    let stats: AppStore.WeekStats

    var body: some View {
        HStack(spacing: Space.s2) {
            cell(stats.words.formatted(), "mots cette semaine")
            cell("\(stats.minutesSaved) min", "gagnées")
            cell("\(stats.wordsPerMinute)", "mots par minute")
        }
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(TronFont.heading).foregroundStyle(TronColor.ink)
            Text(label).font(TronFont.caption).foregroundStyle(TronColor.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s3)
        .tronCard()
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink).lineLimit(1)
            Text(note.text).font(.system(size: 13)).foregroundStyle(TronColor.muted).lineLimit(1)
            Text("\(DateLabel.short(note.createdAt)) · \(DateLabel.duration(note.duration))")
                .font(TronFont.meta)
                .foregroundStyle(TronColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s3)
        .tronCard()
        .contentShape(Rectangle())
    }
}

struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(item.source) · \(DateLabel.short(item.createdAt))")
                .font(TronFont.caption.weight(.medium))
                .foregroundStyle(TronColor.muted)
            Text(item.text).font(.system(size: 14)).foregroundStyle(TronColor.ink).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s3)
        .tronCard()
        .contentShape(Rectangle())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Space.s2) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(TronColor.muted)
            Text(title).font(TronFont.heading).foregroundStyle(TronColor.ink)
            Text(message).font(TronFont.body).foregroundStyle(TronColor.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
        .padding(.horizontal, Space.s4)
    }
}

enum DateLabel {
    static func short(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if cal.isDateInYesterday(date) { return "Hier" }
        if let days = cal.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func duration(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

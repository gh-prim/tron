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
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(TronFont.sans(17, .semibold)).foregroundStyle(TronColor.ink).monospacedDigit()
            Text(label).font(TronFont.sans(11)).foregroundStyle(TronColor.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, Space.s2)
        .tronCard()
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink).lineLimit(1)
            Text(note.text).font(TronFont.sans(13)).foregroundStyle(TronColor.muted).lineLimit(1)
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
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(String(item.source.prefix(1)))
                        .font(TronFont.sans(10, .semibold))
                        .foregroundStyle(TronColor.brand)
                        .frame(width: 16, height: 16)
                        .background(TronColor.brandTint, in: RoundedRectangle(cornerRadius: 5))
                    Text("\(item.source) · \(item.createdAt.formatted(date: .omitted, time: .shortened))")
                        .font(TronFont.sans(12, .medium))
                        .foregroundStyle(TronColor.muted)
                }
                Text(item.text).font(TronFont.sans(14)).foregroundStyle(TronColor.ink).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: copy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 15))
                    .foregroundStyle(TronColor.muted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Copier")
        }
        .padding(.leading, Space.s4)
        .padding(.trailing, Space.s2)
        .padding(.vertical, Space.s3)
        .tronCard()
    }
}

/// Pill segmented control, as designed (Notes / Historique).
struct PillSegments<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { value, title in
                let on = value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = value }
                } label: {
                    Text(title)
                        .font(TronFont.sans(13, on ? .semibold : .medium))
                        .foregroundStyle(on ? TronColor.ink : TronColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if on {
                                Capsule().fill(TronColor.surface).shadow(color: .black.opacity(0.12), radius: 1, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(TronColor.line, in: Capsule())
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

import SwiftUI
import UIKit

struct HomeView: View {
    enum Tab: String, CaseIterable { case notes = "Notes", history = "Historique" }

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @EnvironmentObject private var dictation: DictationController
    @EnvironmentObject private var pending: PendingLaunch

    @State private var tab: Tab = .notes
    @State private var holding = false
    @State private var willCancel = false
    @State private var openedNote: Note?
    @State private var justCreatedID: UUID?
    @State private var showSettings = false
    @State private var toast: String?

    private var busy: Bool { dictation.phase != .idle }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s4) {
                    if busy { recordingHeader } else { header }
                    if !busy { StatsRow(stats: store.weekStats) }
                    if !busy, !engine.isReady { ModelStatusView() }
                    hero
                    if busy { liveArea } else { tabs }
                }
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s8)
            }
            .scrollDisabled(busy)
            .background(TronColor.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $openedNote) { note in
                NoteDetailView(noteID: note.id, justCreated: note.id == justCreatedID)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .overlay(alignment: .bottom) { toastView }
        }
        .onChange(of: dictation.lastNote) { _, note in
            guard let note else { return }
            justCreatedID = note.id
            openedNote = note
            dictation.lastNote = nil
        }
        .onChange(of: dictation.lastCopied) { _, item in
            if item != nil {
                tab = .history
                show("Copié. Retournez dans votre app, touchez le champ, puis Coller.")
            }
        }
        .onChange(of: dictation.errorMessage) { _, message in
            if let message {
                show(message)
                dictation.errorMessage = nil
            }
        }
        .onChange(of: pending.dictateRequested) { _, _ in startPendingDictation() }
        .onChange(of: engine.isReady) { _, _ in startPendingDictation() }
        .onAppear { startPendingDictation() }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            TronMark(height: 26)
            Text("tron")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(TronColor.ink)
                .accessibilityLabel("Tron")
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(TronColor.ink)
            .accessibilityLabel("Réglages")
        }
        .frame(height: 44)
    }

    private var recordingHeader: some View {
        HStack {
            Button("Annuler") { dictation.cancel() }
                .font(TronFont.bodyStrong)
                .foregroundStyle(TronColor.brand)
                .frame(height: 44)
                .opacity(dictation.phase == .recording && !holding ? 1 : 0)
            Spacer()
            HStack(spacing: Space.s2) {
                Circle().fill(TronColor.live).frame(width: 8, height: 8)
                Text(format(dictation.elapsed)).font(TronFont.transcript).foregroundStyle(TronColor.ink)
            }
            .opacity(dictation.phase == .recording ? 1 : 0)
        }
        .frame(height: 44)
    }

    private var hero: some View {
        VStack(spacing: Space.s2) {
            RecordButton { isHolding, cancel in
                holding = isHolding
                willCancel = cancel
            }
            Text(heroTitle)
                .font(TronFont.bodyStrong)
                .foregroundStyle(willCancel ? TronColor.danger : TronColor.ink)
            Text(heroCaption)
                .font(TronFont.caption)
                .foregroundStyle(TronColor.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, Space.s2)
    }

    private var heroTitle: String {
        switch dictation.phase {
        case .idle: return "Nouvelle note"
        case .finishing: return dictation.mode == .actionButton ? "Transcription…" : "Création de la note…"
        case .recording:
            if willCancel { return "Relâchez pour annuler" }
            if holding { return "Relâchez pour enregistrer" }
            return dictation.mode == .actionButton ? "Touchez pour copier" : "Touchez pour terminer"
        }
    }

    private var heroCaption: String {
        switch dictation.phase {
        case .idle: return "Touchez pour démarrer, ou maintenez pour parler"
        case .finishing: return "Sur l'iPhone, rien n'est envoyé."
        case .recording:
            return holding ? "Glissez vers le haut pour annuler" : "Le texte est nettoyé et titré à la fin."
        }
    }

    private var liveArea: some View {
        VStack(spacing: Space.s6) {
            WaveformView(levels: dictation.levels, color: TronColor.live)
                .opacity(dictation.phase == .recording ? 1 : 0.4)
            Group {
                if dictation.liveText.isEmpty {
                    Text("Je vous écoute…").foregroundStyle(TronColor.muted)
                } else {
                    Text(dictation.liveText).foregroundStyle(TronColor.ink)
                }
            }
            .font(TronFont.live)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .padding(Space.s4)
            .tronCard()
            .animation(.easeOut(duration: 0.25), value: dictation.liveText)
        }
        .padding(.top, Space.s2)
    }

    private var tabs: some View {
        VStack(spacing: Space.s4) {
            Picker("Vue", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch tab {
            case .notes: notesList
            case .history: historyList
            }
        }
    }

    private var notesList: some View {
        LazyVStack(spacing: Space.s2) {
            if store.notes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "Aucune note pour l'instant",
                    message: "Touchez le bouton et parlez. La note est titrée et nettoyée toute seule."
                )
            }
            ForEach(store.notes) { note in
                Button {
                    justCreatedID = nil
                    openedNote = note
                } label: { NoteRow(note: note) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var historyList: some View {
        LazyVStack(spacing: Space.s2) {
            if store.history.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Rien dans l'historique",
                    message: "Ce que vous dictez avec le bouton Action apparaît ici. Le clavier Tron arrive dans une prochaine version."
                )
            }
            ForEach(store.history) { item in
                Button {
                    UIPasteboard.general.string = item.text
                    show("Copié.")
                } label: { HistoryRow(item: item) }
                    .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(TronFont.label)
                .foregroundStyle(TronColor.ink)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
                .background(TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(TronColor.line))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Helpers

    private func show(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if toast == message { withAnimation { toast = nil } }
        }
    }

    private func startPendingDictation() {
        guard pending.dictateRequested, engine.isReady, dictation.phase == .idle else { return }
        pending.dictateRequested = false
        dictation.start(mode: .actionButton)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

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

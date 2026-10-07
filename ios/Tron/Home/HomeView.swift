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
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
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
                if dictation.mode == .keyboard {
                    show("Texte prêt. Retournez dans votre app, le clavier Tron l'écrit au curseur.")
                } else {
                    show("Copié. Retournez dans votre app, touchez le champ, puis Coller.")
                }
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
            TronLogo(height: 22)
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(TronFont.sans(20))
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
        case .finishing: return dictation.mode != .note ? "Transcription…" : "Création de la note…"
        case .recording:
            if willCancel { return "Relâchez pour annuler" }
            if holding { return "Relâchez pour enregistrer" }
            return dictation.mode != .note ? "Touchez pour copier" : "Touchez pour terminer"
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
            PillSegments(items: Tab.allCases.map { ($0, $0.rawValue) }, selection: $tab)

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
                    message: "Ce que vous dictez avec le clavier Tron ou le bouton Action apparaît ici."
                )
            }
            ForEach(historyDays, id: \.title) { day in
                Text(day.title)
                    .font(TronFont.sans(12, .medium))
                    .foregroundStyle(TronColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                ForEach(day.items) { item in
                    HistoryRow(item: item) {
                        UIPasteboard.general.string = item.text
                        show("Copié.")
                    }
                }
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

    /// History grouped by day: "Aujourd'hui", "Hier", then the date.
    private var historyDays: [(title: String, items: [HistoryItem])] {
        let cal = Calendar.current
        var days: [(title: String, items: [HistoryItem])] = []
        for item in store.history {
            let title: String
            if cal.isDateInToday(item.createdAt) {
                title = "Aujourd'hui"
            } else if cal.isDateInYesterday(item.createdAt) {
                title = "Hier"
            } else {
                title = item.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
            }
            if days.last?.title == title {
                days[days.count - 1].items.append(item)
            } else {
                days.append((title, [item]))
            }
        }
        return days
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if toast == message { withAnimation { toast = nil } }
        }
    }

    private func startPendingDictation() {
        guard pending.dictateRequested, dictation.phase == .idle else { return }
        pending.dictateRequested = false
        dictation.start(mode: .keyboard)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

import AppKit
import SwiftUI

/// Main window: the big mic for voice notes on the left, notes and history on the right.
struct MainView: View {
    enum Tab: String, CaseIterable { case notes = "Notes", history = "Historique" }

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @EnvironmentObject private var dictation: MacDictation

    @State private var tab: Tab = .notes
    @State private var holding = false
    @State private var willCancel = false
    @State private var path: [UUID] = []
    @State private var justCreatedID: UUID?
    @State private var toast: String?

    private var noteBusy: Bool { dictation.mode == .note && dictation.phase != .idle }

    var body: some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                leftColumn
                    .frame(width: 380)
                Rectangle().fill(TronColor.line).frame(width: 1)
                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .background(TronColor.paper)
            .navigationDestination(for: UUID.self) { id in
                NoteDetailView(noteID: id, justCreated: id == justCreatedID)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .overlay(alignment: .bottom) { toastView }
        .onChange(of: dictation.lastNote) { _, note in
            guard let note else { return }
            justCreatedID = note.id
            tab = .notes
            path = [note.id]
            dictation.lastNote = nil
        }
        .onChange(of: dictation.errorMessage) { _, message in
            guard let message else { return }
            show(message)
            dictation.errorMessage = nil
        }
    }

    // MARK: Left: new note

    private var leftColumn: some View {
        VStack(spacing: Space.s4) {
            HStack(spacing: Space.s2) {
                TronMark(height: 22, speaking: dictation.phase == .recording)
                Text("tron")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(TronColor.ink)
                Spacer()
                if noteBusy, dictation.phase == .recording {
                    HStack(spacing: Space.s2) {
                        Circle().fill(TronColor.live).frame(width: 8, height: 8)
                        Text(DateLabel.duration(dictation.elapsed)).font(TronFont.transcript).foregroundStyle(TronColor.ink)
                    }
                }
            }
            if !noteBusy { StatsRow(stats: store.weekStats) }
            if !engine.isReady { ModelStatusView() }
            Spacer(minLength: 0)
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
            if noteBusy { liveArea } else { Spacer(minLength: 0) }
            if noteBusy, dictation.phase == .recording, !holding {
                Button("Annuler") { dictation.cancel() }
                    .buttonStyle(GhostButtonStyle())
                    .keyboardShortcut(.cancelAction)
            } else if !noteBusy {
                Text("Dans les autres apps : maintenez fn pour dicter.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
            }
        }
        .padding(Space.s6)
    }

    private var heroTitle: String {
        if dictation.mode == .dictation, dictation.phase != .idle { return "Dictée en cours…" }
        switch dictation.phase {
        case .idle: return "Nouvelle note"
        case .transcribing: return "Création de la note…"
        case .recording:
            if willCancel { return "Relâchez pour annuler" }
            if holding { return "Relâchez pour enregistrer" }
            return "Cliquez pour terminer"
        }
    }

    private var heroCaption: String {
        switch dictation.phase {
        case .idle: return "Cliquez pour démarrer, ou maintenez pour parler"
        case .transcribing: return "Sur ce Mac, rien n'est envoyé."
        case .recording:
            if dictation.mode == .dictation { return "Le texte sera collé dans votre app." }
            return holding ? "Glissez vers le haut pour annuler" : "Le texte est nettoyé et titré à la fin."
        }
    }

    private var liveArea: some View {
        VStack(spacing: Space.s4) {
            WaveformView(levels: dictation.levels, color: TronColor.live, barCount: 32, height: 56)
                .opacity(dictation.phase == .recording ? 1 : 0.4)
            ScrollView {
                Group {
                    if dictation.liveText.isEmpty {
                        Text("Je vous écoute…").foregroundStyle(TronColor.muted)
                    } else {
                        Text(dictation.liveText).foregroundStyle(TronColor.ink)
                    }
                }
                .font(TronFont.live)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .animation(.easeOut(duration: 0.25), value: dictation.liveText)
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxHeight: .infinity)
            .padding(Space.s4)
            .tronCard()
        }
    }

    // MARK: Right: notes and history

    private var rightColumn: some View {
        VStack(spacing: Space.s4) {
            Picker("Vue", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            ScrollView {
                LazyVStack(spacing: Space.s2) {
                    switch tab {
                    case .notes: notesList
                    case .history: historyList
                    }
                }
                .padding(.bottom, Space.s6)
            }
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, Space.s6)
    }

    @ViewBuilder private var notesList: some View {
        if store.notes.isEmpty {
            EmptyStateView(
                icon: "note.text",
                title: "Aucune note pour l'instant",
                message: "Cliquez sur le bouton et parlez. La note est titrée et nettoyée toute seule."
            )
        }
        ForEach(store.notes) { note in
            Button {
                justCreatedID = nil
                path = [note.id]
            } label: { NoteRow(note: note) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var historyList: some View {
        if store.history.isEmpty {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "Rien dans l'historique",
                message: "Ce que vous dictez avec fn dans les autres apps apparaît ici. Cliquez pour recopier un texte."
            )
        }
        ForEach(store.history) { item in
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.text, forType: .string)
                show("Copié.")
            } label: { HistoryRow(item: item) }
                .buttonStyle(.plain)
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
                .padding(Space.s4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if toast == message { withAnimation { toast = nil } }
        }
    }
}

struct ModelStatusView: View {
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        HStack(spacing: Space.s3) {
            switch engine.state {
            case .failed:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(TronColor.danger)
                Text("Le modèle n'a pas pu se charger.").font(TronFont.caption)
                Spacer()
                Button("Réessayer") { engine.retry() }
            case .downloading(let p):
                ProgressView(value: p).frame(width: 80)
                Text("Téléchargement du modèle, une seule fois : \(Int(p * 100)) %").font(TronFont.caption)
            default:
                ProgressView().controlSize(.small)
                Text("Préparation du modèle…").font(TronFont.caption)
            }
        }
        .foregroundStyle(TronColor.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s3)
        .tronCard()
    }
}

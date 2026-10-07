import AVFoundation
import AppKit
import SwiftUI

struct NoteDetailView: View {
    let noteID: UUID
    var justCreated = false

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = NotePlayer()
    @State private var showOriginal = false
    @State private var confirmDelete = false
    @State private var copied = false
    @State private var showSaved = false

    private var note: Note? { store.notes.first { $0.id == noteID } }

    var body: some View {
        Group {
            if let note {
                content(note)
            } else {
                EmptyStateView(icon: "trash", title: "Note supprimée", message: "")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TronColor.paper)
        .navigationTitle(note?.title ?? "Note")
        .onAppear {
            if let name = note?.audioFileName { player.load(AppStore.audioURL(for: name)) }
            if justCreated {
                withAnimation(.easeOut(duration: 0.3)) { showSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { showSaved = false } }
            }
        }
        .onDisappear { player.stop() }
    }

    private func content(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                if showSaved {
                    Label("Note enregistrée", systemImage: "checkmark.circle.fill")
                        .font(TronFont.label)
                        .foregroundStyle(TronColor.brand)
                        .padding(.horizontal, Space.s3)
                        .padding(.vertical, Space.s2)
                        .background(TronColor.brandTint, in: Capsule())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                TextField("Titre", text: titleBinding(note), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(TronFont.title)
                    .foregroundStyle(TronColor.ink)

                Text("\(note.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(DateLabel.duration(note.duration))")
                    .font(TronFont.meta)
                    .foregroundStyle(TronColor.muted)

                if note.audioFileName != nil { PlayerBar(player: player) }

                Picker("Version", selection: $showOriginal) {
                    Text("Texte nettoyé").tag(false)
                    Text("Original").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280)

                Text(showOriginal ? note.rawText : note.text)
                    .font(showOriginal ? TronFont.transcript : .system(size: 15))
                    .lineSpacing(5)
                    .foregroundStyle(TronColor.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.s4)
                    .tronCard()

                HStack(spacing: Space.s2) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(showOriginal ? note.rawText : note.text, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    ShareLink(item: "\(note.title)\n\n\(note.text)") {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .foregroundStyle(TronColor.danger)
                }
                .frame(maxWidth: 480)
            }
            .padding(Space.s6)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("Supprimer cette note ?", isPresented: $confirmDelete) {
            Button("Supprimer", role: .destructive) {
                player.stop()
                store.delete(note)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le texte et l'audio sont effacés de ce Mac.")
        }
    }

    private func titleBinding(_ note: Note) -> Binding<String> {
        Binding(
            get: { store.notes.first { $0.id == note.id }?.title ?? note.title },
            set: { newValue in
                var updated = store.notes.first { $0.id == note.id } ?? note
                updated.title = newValue.replacingOccurrences(of: "\n", with: " ")
                store.update(updated)
            }
        )
    }
}

struct PlayerBar: View {
    @ObservedObject var player: NotePlayer

    var body: some View {
        HStack(spacing: Space.s3) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TronColor.onBrand)
                    .frame(width: 34, height: 34)
                    .background(TronColor.brand, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Écouter")
            Slider(
                value: Binding(get: { player.progress }, set: { player.seek(to: $0) }),
                in: 0...1
            )
            .tint(TronColor.brand)
            Text("\(DateLabel.duration(player.currentTime)) / \(DateLabel.duration(player.duration))")
                .font(TronFont.meta)
                .foregroundStyle(TronColor.muted)
                .monospacedDigit()
        }
        .padding(Space.s3)
        .tronCard()
    }
}

@MainActor
final class NotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    func load(_ url: URL) {
        guard player == nil else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.currentTime = self?.player?.currentTime ?? 0 }
            }
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        player.currentTime = fraction * player.duration
        currentTime = player.currentTime
    }

    func stop() {
        player?.stop()
        isPlaying = false
        timer?.invalidate()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.timer?.invalidate()
            self.currentTime = 0
        }
    }
}

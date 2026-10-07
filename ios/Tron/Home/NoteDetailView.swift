import AVFoundation
import SwiftUI
import UIKit

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
        .background(TronColor.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            BackLink(title: "Notes") { dismiss() }
            if let note {
                PlainTrailingItem {
                    Menu {
                        Button {
                            UIPasteboard.general.string = note.rawText
                        } label: { Label("Copier le texte original", systemImage: "doc.on.doc") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Supprimer", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(TronColor.ink)
                    }
                    .accessibilityLabel("Plus d'options")
                }
            }
        }
        .overlay(alignment: .top) {
            if showSaved {
                Label("Note enregistrée", systemImage: "checkmark")
                    .font(TronFont.sans(13, .semibold))
                    .foregroundStyle(TronColor.paper)
                    .padding(.horizontal, Space.s4)
                    .padding(.vertical, 10)
                    .background(TronColor.ink, in: Capsule())
                    .padding(.top, Space.s1)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            if let name = note?.audioFileName { player.load(AppStore.audioURL(for: name)) }
            if justCreated {
                withAnimation(.easeOut(duration: 0.3)) { showSaved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { withAnimation { showSaved = false } }
            }
        }
        .onDisappear { player.stop() }
    }

    private func content(_ note: Note) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: Space.s2) {
                        TextField("Titre", text: titleBinding(note), axis: .vertical)
                            .font(TronFont.sans(26, .semibold))
                            .foregroundStyle(TronColor.ink)
                        HStack(spacing: Space.s2) {
                            Text("\(dayLabel(note.createdAt)) · \(DateLabel.duration(note.duration))")
                                .font(TronFont.meta)
                                .foregroundStyle(TronColor.muted)
                            Text("Titre automatique")
                                .font(TronFont.meta)
                                .foregroundStyle(TronColor.brand)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(TronColor.brandTint, in: Capsule())
                        }
                    }

                    if note.audioFileName != nil { PlayerBar(player: player) }

                    PillSegments(items: [(false, "Texte nettoyé"), (true, "Original")], selection: $showOriginal)

                    Text(showOriginal ? note.rawText : note.text)
                        .font(showOriginal ? TronFont.transcript : TronFont.body)
                        .lineSpacing(showOriginal ? 4 : 7)
                        .foregroundStyle(TronColor.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s2)
                .padding(.bottom, Space.s6)
            }
            toolbar(note)
        }
        .confirmationDialog("Supprimer cette note ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                player.stop()
                store.delete(note)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Le texte et l'audio sont effacés de cet iPhone.")
        }
    }

    /// Copier, Partager, Supprimer at the bottom, as designed.
    private func toolbar(_ note: Note) -> some View {
        HStack(spacing: Space.s2) {
            Button {
                UIPasteboard.general.string = showOriginal ? note.rawText : note.text
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                tool(copied ? "Copié" : "Copier", copied ? "checkmark" : "doc.on.doc", TronColor.ink)
            }
            ShareLink(item: "\(note.title)\n\n\(note.text)") {
                tool("Partager", "square.and.arrow.up", TronColor.ink)
            }
            Button { confirmDelete = true } label: {
                tool("Supprimer", "trash", TronColor.danger)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
        .overlay(alignment: .top) { RowDivider() }
        .background(TronColor.paper)
    }

    private func tool(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18))
            Text(title).font(TronFont.sans(12, .medium))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
    }

    private func dayLabel(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Aujourd'hui, \(time)" }
        if cal.isDateInYesterday(date) { return "Hier, \(time)" }
        return "\(date.formatted(.dateTime.day().month(.abbreviated))), \(time)"
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
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TronColor.onBrand)
                    .frame(width: 40, height: 40)
                    .background(TronColor.brand, in: Circle())
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Écouter")
            GeometryReader { geo in
                let bars = player.bars
                HStack(alignment: .center, spacing: 0) {
                    ForEach(bars.indices, id: \.self) { i in
                        let played = Double(i) / Double(max(1, bars.count)) < player.progress
                        Capsule()
                            .fill(played ? TronColor.brand : TronColor.lineStrong.opacity(0.7))
                            .frame(width: 3, height: max(4, 28 * bars[i]))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    player.seek(to: min(1, max(0, value.location.x / geo.size.width)))
                })
            }
            .frame(height: 28)
            .accessibilityElement()
            .accessibilityLabel("Position de lecture")
            .accessibilityValue("\(Int(player.progress * 100)) %")
            Text("\(DateLabel.duration(player.currentTime)) / \(DateLabel.duration(player.duration))")
                .font(TronFont.meta)
                .foregroundStyle(TronColor.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, Space.s3)
        .padding(.vertical, 10)
        .tronCard()
    }
}

@MainActor
final class NotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    /// 40 loudness bars (0...1) drawn from the recording.
    @Published private(set) var bars: [Double] = Array(repeating: 0.3, count: 40)

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var progress: Double { duration > 0 ? currentTime / duration : 0 }

    func load(_ url: URL) {
        guard player == nil else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        bars = Self.bars(of: url)
    }

    private static func bars(of url: URL, count: Int = 40) -> [Double] {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let data = buffer.floatChannelData?[0], buffer.frameLength > 0
        else { return Array(repeating: 0.3, count: count) }
        let n = Int(buffer.frameLength)
        let size = max(1, n / count)
        var levels: [Double] = []
        for b in 0..<count {
            let start = b * size
            guard start < n else { levels.append(0); continue }
            var sum: Float = 0
            for i in start..<min(n, start + size) { sum += data[i] * data[i] }
            levels.append(Double(sqrt(sum / Float(size))))
        }
        let peak = max(levels.max() ?? 1, 0.0001)
        return levels.map { max(0.15, $0 / peak) }
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.currentTime = self?.player?.currentTime ?? 0 }
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

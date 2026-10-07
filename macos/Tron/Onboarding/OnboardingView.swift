import SwiftUI

/// First launch: microphone, Accessibility, the 🌐 key, and the model download.
struct OnboardingView: View {
    @ObservedObject var engine = TranscriptionEngine.shared
    var onDone: () -> Void

    @State private var mic = Permissions.microphone
    @State private var micDenied = Permissions.microphoneDenied
    @State private var accessibility = Permissions.accessibility
    @State private var globeFree = Permissions.globeKeyIsFree
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let brand = Color(red: 0.5, green: 0.77, blue: 0.66)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bienvenue dans Tron")
                    .font(.system(size: 22, weight: .semibold))
                Text("Dictez dans n'importe quelle app. Votre voix ne quitte pas ce Mac.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                step(
                    done: mic,
                    title: "Micro",
                    detail: micDenied ? "Refusé. Autorisez Tron dans Réglages Système." : "Pour entendre votre voix.",
                    action: micDenied ? "Ouvrir Réglages" : "Autoriser"
                ) {
                    if micDenied {
                        Permissions.openMicrophoneSettings()
                    } else {
                        Task { mic = await Permissions.requestMicrophone(); refresh() }
                    }
                }
                step(
                    done: accessibility,
                    title: "Accessibilité",
                    detail: "Pour la touche fn et pour coller le texte au curseur.",
                    action: "Autoriser"
                ) {
                    Permissions.requestAccessibility()
                }
                step(
                    done: globeFree,
                    title: "Touche 🌐",
                    detail: "Conseillé : dans Clavier, réglez « Appuyer sur 🌐 » sur « Ne rien faire ».",
                    action: "Ouvrir Clavier"
                ) {
                    Permissions.openKeyboardSettings()
                }
                modelRow
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Maintenez fn pour dicter, relâchez pour coller.")
                Text("Double appui sur fn : le micro reste ouvert. Un appui pour finir, Échap pour annuler.")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))

            HStack {
                Spacer()
                Button("C'est parti", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!(mic && accessibility))
            }
        }
        .padding(28)
        .frame(width: 480)
        .onReceive(poll) { _ in refresh() }
    }

    private func refresh() {
        mic = Permissions.microphone
        micDenied = Permissions.microphoneDenied
        accessibility = Permissions.accessibility
        globeFree = Permissions.globeKeyIsFree
    }

    private func step(done: Bool, title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(done ? brand : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if !done {
                Button(action, action: perform)
            }
        }
    }

    private var modelRow: some View {
        HStack(spacing: 12) {
            Image(systemName: engine.isReady ? "checkmark.circle.fill" : "arrow.down.circle")
                .font(.system(size: 18))
                .foregroundStyle(engine.isReady ? brand : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Modèle \(TranscriptionEngine.modelName)").fontWeight(.medium)
                Group {
                    switch engine.state {
                    case .idle: Text("En attente")
                    case .downloading(let p): Text("Téléchargement, une seule fois : \(Int(p * 100)) %")
                    case .loading: Text("Préparation…")
                    case .ready: Text("Prêt, fonctionne hors ligne.")
                    case .failed(let message): Text("Échec : \(message)")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            Spacer()
            if case .failed = engine.state {
                Button("Réessayer") { engine.retry() }
            }
        }
    }
}

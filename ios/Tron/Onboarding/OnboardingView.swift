import SwiftUI
import UIKit

/// Short test onboarding: welcome, first name, language, microphone, Action Button (optional), ready.
/// No account yet: sign-in (Supabase) comes later.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, name, language, mic, actionButton, done
    }

    @EnvironmentObject private var store: AppStore
    @State private var step: Step = .welcome
    @State private var forward = true

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome && step != .done {
                topBar
            }
            Group {
                switch step {
                case .welcome: WelcomeStep { go(.name) }
                case .name: NameStep { go(.language) }
                case .language: LanguageStep { go(.mic) }
                case .mic: MicStep { go(DeviceInfo.hasActionButton ? .actionButton : .done) }
                case .actionButton: ActionButtonStep { go(.done) }
                case .done: DoneStep()
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
            ))
        }
        .padding(.horizontal, Space.s4)
        .padding(.bottom, Space.s4)
        .background(TronColor.paper.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button {
                go(previous, forward: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(TronColor.ink)
            .accessibilityLabel("Retour")
            Spacer()
            if let progress {
                Text(progress)
                    .font(TronFont.meta)
                    .foregroundStyle(TronColor.muted)
            } else {
                Text("Optionnel")
                    .font(TronFont.meta)
                    .foregroundStyle(TronColor.muted)
            }
        }
        .frame(height: 44)
    }

    private var progress: String? {
        switch step {
        case .name: return "1/3"
        case .language: return "2/3"
        case .mic: return "3/3"
        default: return nil
        }
    }

    private var previous: Step {
        switch step {
        case .done: return DeviceInfo.hasActionButton ? .actionButton : .mic
        default: return Step(rawValue: max(0, step.rawValue - 1)) ?? .welcome
        }
    }

    private func go(_ next: Step, forward: Bool = true) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        self.forward = forward
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }
}

// MARK: - Steps

private struct StepHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title)
                .font(TronFont.large)
                .foregroundStyle(TronColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(TronFont.body)
                    .foregroundStyle(TronColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.s4)
    }
}

private struct WelcomeStep: View {
    let next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            Spacer()
            TronMark(height: 64, speaking: !reduceMotion)
            VStack(alignment: .leading, spacing: 0) {
                Text("Parlez.")
                Text("Ça reste ici.").foregroundStyle(TronColor.brand)
            }
            .font(TronFont.display)
            .foregroundStyle(TronColor.ink)
            Text("Tron transcrit votre voix directement sur votre iPhone. Rien n'est envoyé sur un serveur.")
                .font(TronFont.body)
                .foregroundStyle(TronColor.muted)
            Badge(text: "Traitement sur l'appareil", systemImage: "lock.fill")
            Spacer()
            Button("Commencer", action: next)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

private struct NameStep: View {
    let next: () -> Void
    @EnvironmentObject private var store: AppStore
    @FocusState private var focused: Bool
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            StepHeader(title: "Comment vous appelez-vous ?", subtitle: "Tron utilise votre prénom pour s'adresser à vous.")
            VStack(alignment: .leading, spacing: 6) {
                Text("Prénom")
                    .font(TronFont.label)
                    .foregroundStyle(TronColor.ink)
                TextField("", text: $name)
                    .font(.system(size: 17))
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit(submit)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(focused ? TronColor.brand : TronColor.lineStrong, lineWidth: focused ? 2 : 1)
                    )
            }
            Spacer()
            Button("Continuer", action: submit)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
        }
        .onAppear {
            name = store.firstName
            focused = true
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        store.firstName = trimmed
        next()
    }
}

private struct LanguageStep: View {
    let next: () -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            StepHeader(title: "Dans quelle langue parlez-vous ?", subtitle: "Tron règle le modèle de reconnaissance sur cette langue.")
            VStack(spacing: 0) {
                ForEach(Array(SpokenLanguage.allCases.enumerated()), id: \.element) { index, lang in
                    if index > 0 { RowDivider() }
                    Button {
                        store.language = lang
                    } label: {
                        HStack(spacing: Space.s3) {
                            RadioDot(selected: store.language == lang)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.name).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink)
                                if lang == SpokenLanguage.deviceDefault {
                                    Text("Langue de l'iPhone").font(TronFont.caption).foregroundStyle(TronColor.muted)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(store.language == lang ? TronColor.brandTint : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .tronCard()
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            Text("Vous pourrez la changer dans les réglages.")
                .font(TronFont.caption)
                .foregroundStyle(TronColor.muted)
            Spacer()
            Button("Continuer", action: next)
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

struct RadioDot: View {
    let selected: Bool
    var body: some View {
        Circle()
            .strokeBorder(selected ? TronColor.brand : TronColor.lineStrong, lineWidth: selected ? 7 : 1.5)
            .background(Circle().fill(TronColor.surface))
            .frame(width: 22, height: 22)
    }
}

private struct MicStep: View {
    let next: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            HStack {
                Spacer()
                ZStack {
                    ForEach(0..<2) { i in
                        Circle()
                            .stroke(TronColor.brand, lineWidth: 2)
                            .frame(width: 96, height: 96)
                            .scaleEffect(pulse ? 1.6 : 1)
                            .opacity(pulse ? 0 : 0.6)
                            .animation(reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 1.2), value: pulse)
                    }
                    Circle().fill(TronColor.brand).frame(width: 96, height: 96)
                    Image(systemName: "mic")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(TronColor.onBrand)
                }
                .frame(height: 160)
                Spacer()
            }
            .padding(.top, Space.s6)
            StepHeader(title: "Tron a besoin du micro", subtitle: "Pour vous entendre, et c'est tout.")
            VStack(alignment: .leading, spacing: Space.s3) {
                bullet("lock", "L'audio est traité sur cet iPhone, jamais envoyé.")
                bullet("hand.tap", "Le micro ne s'active que quand vous le décidez.")
                bullet("arrow.uturn.backward", "Vous pouvez retirer l'accès à tout moment.")
            }
            Spacer()
            if denied {
                Text("L'accès est refusé. Ouvrez Réglages, puis Tron, puis activez Micro.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.danger)
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Continuer quand même", action: next)
                    .buttonStyle(GhostButtonStyle())
            } else {
                VStack(spacing: Space.s2) {
                    Button("Autoriser le micro", action: ask)
                        .buttonStyle(PrimaryButtonStyle())
                    Text("iOS va vous demander de confirmer.")
                        .font(TronFont.caption)
                        .foregroundStyle(TronColor.muted)
                }
            }
        }
        .onAppear { pulse = true }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TronColor.brand)
                .frame(width: 22)
            Text(text)
                .font(TronFont.body)
                .foregroundStyle(TronColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ask() {
        Task {
            let granted = await AudioRecorder.requestPermission()
            store.micGranted = granted
            if granted { next() } else { denied = true }
        }
    }
}

private struct ActionButtonStep: View {
    let next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            HStack {
                Spacer()
                phone
                Spacer()
            }
            .padding(.top, Space.s4)
            StepHeader(title: "Dictez avec le bouton Action", subtitle: "Un appui long, vous parlez, le texte est prêt à coller. Sans chercher l'app.")
            VStack(alignment: .leading, spacing: Space.s3) {
                step(1, "Ouvrez Réglages, puis Bouton Action.")
                step(2, "Choisissez Raccourci.")
                step(3, "Sélectionnez « Dicter avec Tron ».")
            }
            Spacer()
            VStack(spacing: Space.s2) {
                Button("C'est fait", action: next)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Passer", action: next)
                    .buttonStyle(GhostButtonStyle(color: TronColor.muted))
            }
        }
        .onAppear { pulse = true }
    }

    private var phone: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .stroke(TronColor.lineStrong, lineWidth: 2)
                .frame(width: 88, height: 150)
            Capsule()
                .fill(TronColor.live)
                .frame(width: 5, height: 22)
                .offset(x: -4, y: 34)
                .scaleEffect(pulse ? 1.15 : 1, anchor: .center)
                .opacity(pulse ? 1 : 0.7)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        }
        .accessibilityHidden(true)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Text("\(n)")
                .font(TronFont.label)
                .foregroundStyle(TronColor.brand)
                .frame(width: 26, height: 26)
                .background(TronColor.brandTint, in: Circle())
            Text(text)
                .font(TronFont.body)
                .foregroundStyle(TronColor.ink)
                .padding(.top, 3)
        }
    }
}

private struct DoneStep: View {
    @EnvironmentObject private var store: AppStore
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.s6) {
            Spacer()
            Text("C'est prêt, \(store.firstName).")
                .font(TronFont.display)
                .foregroundStyle(TronColor.ink)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            Text("Touchez le bouton et dites votre première phrase.")
                .font(TronFont.body)
                .foregroundStyle(TronColor.muted)
                .multilineTextAlignment(.center)
            Badge(text: "\(store.language.name) · \(TranscriptionEngine.modelName) · sur l'appareil")
            ModelStatusView()
            Spacer()
            Button {
                store.onboardingDone = true
            } label: {
                Label("Aller à l'accueil", systemImage: "mic")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { appeared = true }
        }
    }
}

/// Download and load progress of the Parakeet model.
struct ModelStatusView: View {
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        switch engine.state {
        case .idle, .ready:
            EmptyView()
        case .downloading(let p):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Téléchargement du modèle")
                    Spacer()
                    Text("\(Int(p * 100)) %").font(TronFont.meta)
                }
                .font(TronFont.label)
                .foregroundStyle(TronColor.ink)
                ProgressView(value: p).tint(TronColor.brand)
                Text("Une seule fois, quelques centaines de Mo. Restez en Wi-Fi.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
            }
            .padding(Space.s4)
            .tronCard()
        case .loading:
            HStack(spacing: Space.s2) {
                ProgressView()
                Text("Préparation du modèle sur l'iPhone")
                    .font(TronFont.label)
                    .foregroundStyle(TronColor.ink)
                Spacer()
            }
            .padding(Space.s4)
            .tronCard()
        case .failed(let message):
            VStack(alignment: .leading, spacing: Space.s2) {
                Label("Le modèle n'a pas pu être chargé", systemImage: "exclamationmark.triangle")
                    .font(TronFont.label)
                    .foregroundStyle(TronColor.danger)
                Text(message)
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.ink)
                Button("Réessayer") { engine.retry() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Space.s4)
            .background(TronColor.dangerTint, in: RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}

enum DeviceInfo {
    /// iPhone 15 Pro and later (and iPhone 16e) have an Action Button. The simulator shows the step too.
    static var hasActionButton: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        guard machine.hasPrefix("iPhone") else { return false }
        let parts = machine.dropFirst("iPhone".count).split(separator: ",")
        guard let major = parts.first.flatMap({ Int($0) }) else { return false }
        if major >= 17 { return true }
        return machine == "iPhone16,1" || machine == "iPhone16,2"
        #endif
    }
}

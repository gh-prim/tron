import SwiftUI
import UIKit

/// Onboarding, as designed in Claude Design (Onboarding, iOS): welcome, first name, language, usage,
/// microphone, Action Button (optional), ready. The account step comes with sign-in (Supabase).
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, name, language, usage, mic, actionButton, done
    }

    @EnvironmentObject private var store: AppStore
    @State private var step: Step = .welcome
    @State private var forward = true

    var body: some View {
        VStack(spacing: Space.s6) {
            if step != .welcome && step != .done {
                topBar
            }
            Group {
                switch step {
                case .welcome: WelcomeStep { go(.name) }
                case .name: NameStep { go(.language) }
                case .language: LanguageStep { go(.usage) }
                case .usage: UsageStep { go(.mic) }
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
        .padding(.top, Space.s2)
        .padding(.horizontal, Space.s4)
        .padding(.bottom, Space.s4)
        .background(TronColor.paper.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack(spacing: Space.s3) {
            Button {
                go(previous, forward: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(TronColor.ink)
            .padding(.leading, -10)
            .accessibilityLabel("Retour")
            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TronColor.line)
                        Capsule().fill(TronColor.brand).frame(width: geo.size.width * CGFloat(progress) / CGFloat(Self.counted))
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
                Text("\(progress)/\(Self.counted)")
                    .font(TronFont.meta)
                    .foregroundStyle(TronColor.muted)
                    .accessibilityLabel("Étape \(progress) sur \(Self.counted)")
            } else {
                Spacer()
                Text("Optionnel")
                    .font(TronFont.meta)
                    .foregroundStyle(TronColor.muted)
            }
        }
        .frame(height: 44)
    }

    /// Steps shown in the progress bar.
    private static let counted = 4

    private var progress: Int? {
        switch step {
        case .name: return 1
        case .language: return 2
        case .usage: return 3
        case .mic: return 4
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
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: Space.s4) {
            Text(title)
                .font(TronFont.stepTitle)
                .foregroundStyle(TronColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(TronFont.body)
                    .foregroundStyle(TronColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(centered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Logo with the "tron" wordmark.
struct TronLogo: View {
    var height: CGFloat = 40
    var speaking = false

    var body: some View {
        HStack(spacing: height * 0.3) {
            TronMark(height: height, speaking: speaking)
            Text("tron")
                .font(.custom("InstrumentSans-SemiBold", size: height * 0.95))
                .foregroundStyle(TronColor.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tron")
    }
}

private struct WelcomeStep: View {
    let next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            Spacer()
            TronLogo(height: 40, speaking: !reduceMotion)
            Text("Parlez.\nÇa reste ici.")
                .font(TronFont.display)
                .foregroundStyle(TronColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tron transcrit votre voix directement sur votre iPhone. Rien n'est envoyé sur un serveur.")
                .font(TronFont.body)
                .foregroundStyle(TronColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Badge(text: "Traitement sur l'appareil", systemImage: "lock")
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
        VStack(alignment: .leading, spacing: Space.s4) {
            StepHeader(title: "Comment vous appelez-vous ?", subtitle: "Tron utilise votre prénom pour s'adresser à vous.")
            VStack(alignment: .leading, spacing: 6) {
                Text("Prénom")
                    .font(TronFont.label)
                    .foregroundStyle(TronColor.ink)
                TextField("", text: $name)
                    .font(TronFont.field)
                    .foregroundStyle(TronColor.ink)
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
            .padding(.top, Space.s2)
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
        VStack(alignment: .leading, spacing: Space.s4) {
            StepHeader(title: "Dans quelle langue parlez-vous ?", subtitle: "Tron charge le modèle de reconnaissance adapté.")
            VStack(spacing: 0) {
                ForEach(Array(SpokenLanguage.allCases.enumerated()), id: \.element) { index, lang in
                    if index > 0 { RowDivider() }
                    Button {
                        store.language = lang
                    } label: {
                        HStack(spacing: Space.s3) {
                            RadioDot(selected: store.language == lang)
                            Text(lang.name).font(TronFont.body).foregroundStyle(TronColor.ink)
                            Spacer()
                            if lang == SpokenLanguage.deviceDefault {
                                Text("Langue de l'iPhone").font(TronFont.meta).foregroundStyle(TronColor.muted)
                            }
                        }
                        .padding(.horizontal, Space.s4)
                        .frame(height: 54)
                        .background(store.language == lang ? TronColor.brandTint : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.language == lang ? .isSelected : [])
                }
            }
            .tronCard()
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .padding(.top, Space.s2)
            Text("Vous pourrez la changer dans les réglages.")
                .font(TronFont.small)
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

private struct UsageStep: View {
    let next: () -> Void
    /// Comma-separated choices, kept for later personalization (stays on the iPhone).
    @AppStorage("usage") private var usageRaw = "apps"

    private struct Choice: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
    }

    private let choices = [
        Choice(id: "apps", icon: "keyboard", title: "Dicter dans mes apps", detail: "Mails, messages, documents"),
        Choice(id: "meetings", icon: "person.2", title: "Transcrire mes réunions", detail: "Avec qui parle, et quand"),
        Choice(id: "notes", icon: "doc.text", title: "Prendre des notes vocales", detail: "Idées, mémos, comptes rendus"),
        Choice(id: "other", icon: "plus.circle", title: "Autre chose", detail: "On verra à l'usage"),
    ]

    private var selected: Set<String> { Set(usageRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            StepHeader(title: "Vous allez utiliser Tron pour…", subtitle: "Plusieurs choix possibles.")
            VStack(spacing: Space.s2) {
                ForEach(choices) { choice in
                    let on = selected.contains(choice.id)
                    Button { toggle(choice.id) } label: {
                        HStack(spacing: Space.s3) {
                            Image(systemName: choice.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(TronColor.brand)
                                .frame(width: 40, height: 40)
                                .background(on ? TronColor.surface : TronColor.paper, in: RoundedRectangle(cornerRadius: Radius.md))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(choice.title).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink)
                                Text(choice.detail).font(TronFont.small).foregroundStyle(TronColor.muted)
                            }
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .fill(on ? TronColor.brand : TronColor.surface)
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .strokeBorder(on ? TronColor.brand : TronColor.lineStrong, lineWidth: 1.5)
                                if on {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(TronColor.onBrand)
                                }
                            }
                            .frame(width: 22, height: 22)
                        }
                        .padding(.horizontal, Space.s4)
                        .padding(.vertical, 14)
                        .background(on ? TronColor.brandTint : TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(on ? TronColor.brand : TronColor.line, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.top, Space.s2)
            Spacer()
            Button("Continuer", action: next)
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func toggle(_ id: String) {
        var set = selected
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        usageRaw = choices.map(\.id).filter(set.contains).joined(separator: ",")
    }
}

/// Mic in a soft halo with two expanding rings (Micro and Prêt steps).
private struct MicHalo: View {
    var size: CGFloat = 112
    var filled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<2) { i in
                Circle()
                    .stroke(TronColor.brand, lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.6 : 1)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 1.2), value: pulse)
            }
            Circle().fill(filled ? TronColor.brand : TronColor.brandTint).frame(width: size, height: size)
            Image(systemName: "mic")
                .font(.system(size: size * 0.3, weight: .regular))
                .foregroundStyle(filled ? TronColor.onBrand : TronColor.brand)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .onAppear { pulse = true }
    }
}

private struct MicStep: View {
    let next: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            MicHalo()
                .frame(maxWidth: .infinity)
                .padding(.vertical, -Space.s4)
            StepHeader(title: "Tron a besoin du micro", subtitle: "Pour vous entendre, et c'est tout.", centered: true)
            VStack(alignment: .leading, spacing: Space.s3) {
                bullet("iphone", "L'audio est traité sur cet iPhone, jamais envoyé.")
                bullet("smallcircle.filled.circle", "Le micro ne s'active que quand vous le décidez.")
                bullet("checkmark.circle", "Vous pouvez retirer l'accès à tout moment.")
            }
            .padding(.top, Space.s2)
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
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(TronColor.brand)
                .frame(width: 18)
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
        VStack(alignment: .leading, spacing: Space.s4) {
            phone
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s2)
            StepHeader(title: "Dictez avec le bouton Action", subtitle: "Un appui long, vous parlez, le texte apparaît. Sans ouvrir l'app.")
            VStack(alignment: .leading, spacing: Space.s3) {
                step(1, "Ouvrez Réglages, puis Bouton Action.")
                step(2, "Choisissez Raccourci.")
                step(3, "Sélectionnez « Dicter avec Tron ».")
            }
            .padding(.top, Space.s2)
            Spacer()
            VStack(spacing: Space.s2) {
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    next()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Passer", action: next)
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .onAppear { pulse = true }
    }

    /// An iPhone outline with Tron on screen and the Action Button being pressed.
    private var phone: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(TronColor.surface)
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(TronColor.ink, lineWidth: 3))
                .overlay(TronMark(height: 30))
                .frame(width: 104, height: 200)
            sideButton(top: 34, height: 22, color: TronColor.brand)
                .offset(x: pulse ? 2 : 0)
                .shadow(color: TronColor.brand.opacity(pulse ? 0.35 : 0), radius: pulse ? 4 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            sideButton(top: 66, height: 30, color: TronColor.lineStrong)
            sideButton(top: 102, height: 30, color: TronColor.lineStrong)
        }
        .accessibilityHidden(true)
    }

    private func sideButton(top: CGFloat, height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 5, height: height)
            .offset(x: -7, y: top)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Text("\(n)")
                .font(TronFont.meta)
                .foregroundStyle(TronColor.brand)
            Text(text)
                .font(TronFont.body)
                .foregroundStyle(TronColor.ink)
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
            Button(action: startFirstNote) {
                MicHalo(size: 96, filled: true)
            }
            .buttonStyle(.plain)
            .padding(.vertical, -Space.s4)
            .accessibilityLabel("Dicter")
            Text("\(store.language.name) · \(TranscriptionEngine.modelName) · sur l'appareil")
                .font(TronFont.meta)
                .foregroundStyle(TronColor.muted)
            ModelStatusView()
            Spacer()
            Button("Plus tard") { store.onboardingDone = true }
                .buttonStyle(GhostButtonStyle())
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) { appeared = true }
        }
    }

    /// Opens the home screen already listening, for the first note.
    private func startFirstNote() {
        store.onboardingDone = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DictationController.shared.start(mode: .note)
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

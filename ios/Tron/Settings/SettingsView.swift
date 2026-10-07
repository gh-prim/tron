import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    @State private var confirmReset = false
    @State private var keyboardEnabled = false

    private var dictionaryCount: String {
        let n = Corrections.all().count
        return n == 0 ? "Vide" : "\(n)"
    }

    var body: some View {
        TronScreen(back: "Accueil", title: "Réglages") {
                    NavigationLink { AccountView() } label: { accountCard }
                        .buttonStyle(.plain)

                    TronGroup(header: "Dictée") {
                        NavigationLink { LanguageSettingView() } label: {
                            SettingRow(title: "Langue", value: store.language.name)
                        }
                        RowDivider()
                        NavigationLink { KeyboardSettingView() } label: {
                            SettingRow(title: "Clavier Tron", value: keyboardEnabled ? "Actif" : "À ajouter", dot: keyboardEnabled)
                        }
                        RowDivider()
                        NavigationLink { MicSessionSettingView() } label: {
                            SettingRow(title: "Micro prêt", value: store.micSession.title)
                        }
                        RowDivider()
                        NavigationLink { DictionaryView() } label: {
                            SettingRow(title: "Dictionnaire", value: dictionaryCount)
                        }
                        RowDivider()
                        NavigationLink { ActionButtonSettingView() } label: {
                            SettingRow(title: "Bouton Action", value: store.actionButtonMode.title)
                        }
                    }

                    TronGroup(header: "Historique") {
                        NavigationLink { RetentionSettingView() } label: {
                            SettingRow(title: "Conserver", value: store.historyRetention.title)
                        }
                        RowDivider()
                        Button { confirmClear = true } label: {
                            SettingRow(title: "Tout effacer", chevron: false, destructive: true)
                        }
                    }

                    TronGroup(header: "Confidentialité", footer: "Aide à améliorer Tron. Aucun audio ni texte n'est envoyé.") {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock").foregroundStyle(TronColor.brand)
                            Text("Votre voix et vos textes ne quittent pas cet iPhone.")
                                .font(TronFont.sans(14))
                                .foregroundStyle(TronColor.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, Space.s3)
                        RowDivider()
                        Toggle(isOn: $store.analyticsOptIn) {
                            Text("Statistiques anonymes").font(TronFont.sans(15)).foregroundStyle(TronColor.ink)
                        }
                        .tint(TronColor.brand)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                    }

                    TronGroup(header: "À propos") {
                        NavigationLink { PrivacyView() } label: {
                            SettingRow(title: "Conditions et confidentialité")
                        }
                        RowDivider()
                        SettingRow(title: "Modèle", value: "\(TranscriptionEngine.modelName) · \(engineLabel)", chevron: false, monoValue: true)
                        RowDivider()
                        SettingRow(title: "Version", value: appVersion, chevron: false, monoValue: true)
                    }

                    TronGroup(header: "Test", footer: "Efface les notes, l'historique et le prénom, puis relance l'onboarding. Le modèle reste installé.") {
                        Button { confirmReset = true } label: {
                            SettingRow(title: "Recommencer l'onboarding", chevron: false, destructive: true)
                        }
                    }
        }
        .sheet(isPresented: $confirmClear) {
            ClearHistorySheet(count: store.history.count) { store.clearHistory() }
        }
        .confirmationDialog("Recommencer l'onboarding ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Tout effacer et recommencer", role: .destructive) {
                dismiss()
                store.resetEverything()
            }
            Button("Annuler", role: .cancel) {}
        }
        .onAppear { keyboardEnabled = KeyboardStatus.isEnabled }
    }

    private var accountCard: some View {
        HStack(spacing: Space.s3) {
            Text(String(store.firstName.prefix(1)).uppercased())
                .font(TronFont.sans(18, .semibold))
                .foregroundStyle(TronColor.brand)
                .frame(width: 44, height: 44)
                .background(TronColor.brandTint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(store.firstName.isEmpty ? "Votre prénom" : store.firstName)
                    .font(TronFont.sans(16, .semibold))
                    .foregroundStyle(TronColor.ink)
                Text("Sans compte pour l'instant")
                    .font(TronFont.sans(13))
                    .foregroundStyle(TronColor.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(TronColor.lineStrong)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Space.s3)
        .tronCard()
    }

    private var engineLabel: String {
        switch engine.state {
        case .ready: return "prêt"
        case .downloading(let p): return "\(Int(p * 100)) %"
        case .loading: return "chargement"
        case .failed: return "erreur"
        case .idle: return "en attente"
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct SettingRow: View {
    let title: String
    var value: String? = nil
    var chevron = true
    var destructive = false
    var monoValue = false
    /// Green dot before the value ("Actif").
    var dot = false
    /// SF Symbol in a tinted tile before the title.
    var icon: String? = nil

    var body: some View {
        HStack(spacing: Space.s3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(TronColor.brand)
                    .frame(width: 28, height: 28)
                    .background(TronColor.brandTint, in: RoundedRectangle(cornerRadius: 7))
            }
            Text(title)
                .font(TronFont.sans(15, destructive ? .medium : .regular))
                .foregroundStyle(destructive ? TronColor.danger : TronColor.ink)
            Spacer(minLength: Space.s2)
            if dot {
                Circle().fill(TronColor.brand).frame(width: 8, height: 8)
            }
            if let value {
                Text(value)
                    .font(monoValue ? TronFont.mono(13) : TronFont.body)
                    .foregroundStyle(TronColor.muted)
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(TronFont.sans(13, .semibold))
                    .foregroundStyle(TronColor.lineStrong)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Sub pages

private struct AccountView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TronScreen(back: "Réglages", title: "Compte") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prénom").font(TronFont.label).foregroundStyle(TronColor.ink)
                TextField("Prénom", text: $store.firstName)
                    .font(TronFont.sans(17))
                    .textContentType(.givenName)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(TronColor.surface, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(TronColor.lineStrong))
                Text("La connexion avec Apple, Google ou e-mail arrive dans une prochaine version.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
                    .padding(.top, Space.s2)
            }
        }
    }
}

private struct LanguageSettingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ChoiceList(
            title: "Langue parlée",
            intro: "Parakeet comprend ces langues. Tron s'appuie sur ce choix pour éviter les erreurs d'écriture.",
            options: SpokenLanguage.allCases.map { ChoiceOption(id: $0.rawValue, title: $0.name) },
            selected: store.languageCode
        ) { store.languageCode = $0 }
    }
}

private struct RetentionSettingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ChoiceList(
            title: "Conserver l'historique",
            intro: "Ce que vous dictez dans vos apps est gardé sur cet iPhone, puis effacé tout seul.",
            options: HistoryRetention.allCases.map {
                ChoiceOption(id: $0.rawValue, title: $0.title, tag: $0 == .month ? "Par défaut" : nil)
            },
            selected: store.historyRetentionRaw
        ) { raw in
            if let r = HistoryRetention(rawValue: raw) { store.historyRetention = r }
        }
    }
}

private struct MicSessionSettingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TronScreen(back: "Réglages", title: "Micro prêt", spacing: Space.s3) {
                Text("Après chaque utilisation de Tron, le micro reste prêt en arrière-plan. Le bouton Tron du clavier dicte alors sans ouvrir l'app. Le point orange d'iOS reste affiché pendant ce temps.")
                    .font(TronFont.body)
                    .foregroundStyle(TronColor.muted)
                VStack(spacing: 0) {
                    ForEach(Array(MicSession.allCases.enumerated()), id: \.element) { index, session in
                        if index > 0 { RowDivider() }
                        Button { store.micSession = session } label: {
                            OptionRow(
                                title: session.title,
                                detail: nil,
                                tag: session == .hour ? "Conseillé" : nil,
                                selected: store.micSession == session
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tronCard()
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                Text("Pour couper le micro avant, touchez la croix dans la Dynamic Island.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
        }
    }
}

private struct ActionButtonSettingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TronScreen(back: "Réglages", title: "Bouton Action", spacing: Space.s3) {
                Text("Quand vous dictez avec le bouton Action, comment le texte arrive-t-il dans l'app ?")
                    .font(TronFont.body)
                    .foregroundStyle(TronColor.muted)
                VStack(spacing: 0) {
                    ForEach(Array(ActionButtonMode.allCases.enumerated()), id: \.element) { index, mode in
                        if index > 0 { RowDivider() }
                        Button { store.actionButtonMode = mode } label: {
                            OptionRow(
                                title: mode.title,
                                detail: mode.detail,
                                tag: mode == .miniKeyboard ? "Conseillé" : nil,
                                selected: store.actionButtonMode == mode
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tronCard()
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))


                TronGroup(header: "Réglage de l'iPhone", footer: "Réglages, puis Bouton Action, puis Raccourci « Dicter avec Tron ».") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        SettingRow(title: "Configurer le bouton Action", icon: "iphone.gen3")
                    }
                }
        }
    }
}

private struct ChoiceOption {
    let id: String
    let title: String
    var tag: String? = nil
}

private struct ChoiceList: View {
    let title: String
    let intro: String
    let options: [ChoiceOption]
    let selected: String
    let onSelect: (String) -> Void

    var body: some View {
        TronScreen(back: "Réglages", title: title, spacing: Space.s3) {
                Text(intro).font(TronFont.body).foregroundStyle(TronColor.muted)
                VStack(spacing: 0) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        if index > 0 { RowDivider() }
                        Button { onSelect(option.id) } label: {
                            OptionRow(title: option.title, detail: nil, tag: option.tag, selected: option.id == selected)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tronCard()
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}

struct OptionRow: View {
    let title: String
    let detail: String?
    let tag: String?
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            RadioDot(selected: selected).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink)
                    if let tag {
                        Text(tag)
                            .font(TronFont.mono(11))
                            .foregroundStyle(TronColor.brand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(selected ? TronColor.surface : TronColor.brandTint, in: Capsule())
                    }
                }
                if let detail {
                    Text(detail)
                        .font(TronFont.sans(13))
                        .foregroundStyle(TronColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Space.s3)
        .background(selected ? TronColor.brandTint : .clear)
        .contentShape(Rectangle())
    }
}


// MARK: - Clavier Tron, confidentialité, effacement

/// Whether the Tron keyboard is in the user's keyboard list.
enum KeyboardStatus {
    static var isEnabled: Bool {
        UITextInputMode.activeInputModes.contains { mode in
            (mode.value(forKey: "identifier") as? String)?.hasPrefix("app.tron.ios") == true
        }
    }
}

private struct KeyboardSettingView: View {
    @State private var enabled = KeyboardStatus.isEnabled

    var body: some View {
        TronScreen(back: "Réglages", title: "Clavier Tron", spacing: Space.s3) {
            Text("Le clavier Tron écrit vos dictées directement au curseur, dans toutes vos apps. Touchez son bouton micro pour dicter, ou utilisez le bouton Action.")
                .font(TronFont.body)
                .foregroundStyle(TronColor.muted)
            TronGroup {
                SettingRow(title: "État", value: enabled ? "Actif" : "Pas encore ajouté", chevron: false, dot: enabled)
                RowDivider()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    SettingRow(title: "Ouvrir les Réglages", icon: "keyboard")
                }
            }
            TronGroup(header: "Pour l'ajouter") {
                VStack(alignment: .leading, spacing: Space.s3) {
                    step(1, "Réglages, puis Apps, puis Tron.")
                    step(2, "Claviers : activez Clavier Tron.")
                    step(3, "Activez Autoriser l'accès complet, pour que Tron écrive au curseur.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            Text("L'accès complet sert seulement à échanger le texte dicté avec l'app Tron, sur cet iPhone. Rien n'est envoyé.")
                .font(TronFont.caption)
                .foregroundStyle(TronColor.muted)
        }
        .onAppear { enabled = KeyboardStatus.isEnabled }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s3) {
            Text("\(n)").font(TronFont.meta).foregroundStyle(TronColor.brand)
            Text(text).font(TronFont.body).foregroundStyle(TronColor.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PrivacyView: View {
    var body: some View {
        TronScreen(back: "Réglages", title: "Confidentialité", spacing: Space.s4) {
            point("Votre voix reste ici", "Parakeet transcrit sur cet iPhone. L'audio et le texte ne sont jamais envoyés sur un serveur.")
            point("Vos données", "Notes, historique et dictionnaire sont gardés sur cet iPhone. L'historique s'efface tout seul selon votre réglage.")
            point("Statistiques", "Désactivées par défaut. Si vous les activez, elles ne contiennent ni audio ni texte.")
            point("Version de test", "Les conditions d'utilisation complètes arriveront avec les comptes.")
        }
    }

    private func point(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(TronFont.bodyStrong).foregroundStyle(TronColor.ink)
            Text(text).font(TronFont.body).foregroundStyle(TronColor.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Effacer tout l'historique ?" as a bottom sheet, as designed.
private struct ClearHistorySheet: View {
    let count: Int
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Effacer tout l'historique ?")
                .font(TronFont.title)
                .foregroundStyle(TronColor.ink)
                .padding(.top, Space.s2)
            Text("\(count) dictée\(count > 1 ? "s seront supprimées" : " sera supprimée") de cet iPhone. Vos notes ne sont pas touchées.")
                .font(TronFont.body)
                .foregroundStyle(TronColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Tout effacer") {
                confirm()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(fill: TronColor.danger, text: TronColor.onDanger))
            .padding(.top, Space.s2)
            Button("Annuler") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s6)
        .padding(.bottom, Space.s4)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
        .presentationBackground(TronColor.surface)
    }
}

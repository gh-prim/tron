import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s2) {
                    NavigationLink { AccountView() } label: { accountCard }
                        .buttonStyle(.plain)

                    TronGroup(header: "Dictée") {
                        NavigationLink { LanguageSettingView() } label: {
                            SettingRow(title: "Langue", value: store.language.name)
                        }
                        RowDivider()
                        NavigationLink { MicSessionSettingView() } label: {
                            SettingRow(title: "Micro prêt", value: store.micSession.title)
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
                                .font(.system(size: 14))
                                .foregroundStyle(TronColor.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, Space.s3)
                        RowDivider()
                        Toggle(isOn: $store.analyticsOptIn) {
                            Text("Statistiques anonymes").font(.system(size: 15)).foregroundStyle(TronColor.ink)
                        }
                        .tint(TronColor.brand)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                    }

                    TronGroup(header: "À propos") {
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
                .padding(Space.s4)
            }
            .background(TronColor.paper.ignoresSafeArea())
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }.foregroundStyle(TronColor.brand)
                }
            }
            .confirmationDialog("Effacer tout l'historique ?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) { store.clearHistory() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("\(store.history.count) dictées seront supprimées de cet iPhone. Vos notes ne sont pas touchées.")
            }
            .confirmationDialog("Recommencer l'onboarding ?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Tout effacer et recommencer", role: .destructive) {
                    dismiss()
                    store.resetEverything()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private var accountCard: some View {
        HStack(spacing: Space.s3) {
            Text(String(store.firstName.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TronColor.brand)
                .frame(width: 44, height: 44)
                .background(TronColor.brandTint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(store.firstName.isEmpty ? "Votre prénom" : store.firstName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TronColor.ink)
                Text("Sans compte pour l'instant")
                    .font(.system(size: 13))
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

    var body: some View {
        HStack(spacing: Space.s3) {
            Text(title)
                .font(.system(size: 15, weight: destructive ? .medium : .regular))
                .foregroundStyle(destructive ? TronColor.danger : TronColor.ink)
            Spacer(minLength: Space.s2)
            if let value {
                Text(value)
                    .font(monoValue ? TronFont.meta : .system(size: 15))
                    .foregroundStyle(TronColor.muted)
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TronColor.lineStrong)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

// MARK: - Sub pages

private struct AccountView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Prénom").font(TronFont.label).foregroundStyle(TronColor.ink)
                TextField("Prénom", text: $store.firstName)
                    .font(.system(size: 17))
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
            .padding(Space.s4)
        }
        .background(TronColor.paper.ignoresSafeArea())
        .navigationTitle("Compte")
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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
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
            .padding(Space.s4)
        }
        .background(TronColor.paper.ignoresSafeArea())
        .navigationTitle("Micro prêt")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ActionButtonSettingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
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
                        SettingRow(title: "Ouvrir les Réglages")
                    }
                }
            }
            .padding(Space.s4)
        }
        .background(TronColor.paper.ignoresSafeArea())
        .navigationTitle("Bouton Action")
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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s3) {
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
            .padding(Space.s4)
        }
        .background(TronColor.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
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
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TronColor.brand)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(selected ? TronColor.surface : TronColor.brandTint, in: Capsule())
                    }
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 13))
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

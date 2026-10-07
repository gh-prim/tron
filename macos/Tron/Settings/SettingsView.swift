import SwiftUI

/// Réglages (⌘ ,): language and the correction dictionary.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            Form {
                Picker("Langue de la dictée", selection: $store.language) {
                    ForEach(SpokenLanguage.allCases) { Text($0.name).tag($0) }
                }
                Text("Maintenez fn pour dicter dans n'importe quelle app. Double appui : le micro reste ouvert.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
            }
            .padding(Space.s6)
            .frame(width: 520)
            .tabItem { Label("Général", systemImage: "gearshape") }

            DictionaryView()
                .tabItem { Label("Dictionnaire", systemImage: "character.book.closed") }
        }
    }
}

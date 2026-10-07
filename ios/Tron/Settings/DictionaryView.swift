import SwiftUI

/// Réglages > Dictée > Dictionnaire: corrections applied to every dictation.
struct DictionaryView: View {
    @State private var entries: [Correction] = []
    @State private var editing: Correction?
    @State private var adding = false

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("Aucune correction pour l'instant. Sélectionnez un mot mal écrit avec le clavier Tron, puis touchez « Corriger ».")
                        .font(TronFont.body)
                        .foregroundStyle(TronColor.muted)
                        .listRowBackground(TronColor.surface)
                }
                ForEach(entries) { entry in
                    Button { editing = entry } label: {
                        HStack(spacing: Space.s2) {
                            Text(entry.heard)
                                .font(.system(size: 15))
                                .foregroundStyle(TronColor.muted)
                                .strikethrough(color: TronColor.lineStrong)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TronColor.lineStrong)
                            Text(entry.correct)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TronColor.ink)
                            Spacer(minLength: 0)
                        }
                        .lineLimit(1)
                    }
                    .listRowBackground(TronColor.surface)
                }
                .onDelete { offsets in
                    entries.remove(atOffsets: offsets)
                    Corrections.save(entries)
                }
            } footer: {
                Text("Tron remplace ces mots dans chaque dictée, y compris le texte écrit en direct.")
                    .font(TronFont.caption)
                    .foregroundStyle(TronColor.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(TronColor.paper.ignoresSafeArea())
        .navigationTitle("Dictionnaire")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .foregroundStyle(TronColor.brand)
                    .accessibilityLabel("Ajouter une correction")
            }
        }
        .sheet(item: $editing) { entry in
            CorrectionEditor(entry: entry) { reload() }
        }
        .sheet(isPresented: $adding) {
            CorrectionEditor(entry: nil) { reload() }
        }
        .onAppear { reload() }
    }

    private func reload() { entries = Corrections.all() }
}

private struct CorrectionEditor: View {
    let entry: Correction?
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var heard = ""
    @State private var correct = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tron entend") {
                    TextField("ex. tronc", text: $heard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Tron écrit") {
                    TextField("ex. Tron", text: $correct)
                        .autocorrectionDisabled()
                }
                if let entry {
                    Section {
                        Button("Supprimer la correction", role: .destructive) {
                            Corrections.save(Corrections.all().filter { $0.id != entry.id })
                            onDone()
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TronColor.paper.ignoresSafeArea())
            .navigationTitle(entry == nil ? "Nouvelle correction" : "Correction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }.foregroundStyle(TronColor.brand)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        if let entry {
                            var list = Corrections.all()
                            if let i = list.firstIndex(where: { $0.id == entry.id }) {
                                list[i].heard = heard.trimmingCharacters(in: .whitespaces)
                                list[i].correct = correct.trimmingCharacters(in: .whitespaces)
                                Corrections.save(list)
                            }
                        } else {
                            Corrections.add(heard: heard, correct: correct)
                        }
                        onDone()
                        dismiss()
                    }
                    .foregroundStyle(TronColor.brand)
                    .disabled(heard.trimmingCharacters(in: .whitespaces).isEmpty || correct.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                heard = entry?.heard ?? ""
                correct = entry?.correct ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}

import SwiftUI

/// Dictionnaire tab of the main window: corrections applied to every dictation and note (shared format with iOS).
struct DictionaryView: View {
    @State private var entries: [Correction] = []
    @State private var heard = ""
    @State private var correct = ""
    @State private var editing: Correction?
    @FocusState private var heardFocused: Bool

    private var canAdd: Bool {
        !heard.trimmingCharacters(in: .whitespaces).isEmpty && !correct.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("Tron remplace ces mots dans chaque dictée et chaque note, y compris le texte en direct.")
                .font(TronFont.caption)
                .foregroundStyle(TronColor.muted)

            HStack(spacing: Space.s2) {
                TextField("Tron entend (ex. tronc)", text: $heard)
                    .focused($heardFocused)
                Image(systemName: "arrow.right").foregroundStyle(TronColor.lineStrong)
                TextField("Tron écrit (ex. Tron)", text: $correct)
                    .onSubmit(add)
                Button("Ajouter", action: add)
                    .disabled(!canAdd)
                    .keyboardShortcut(.defaultAction)
            }
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()

            if entries.isEmpty {
                VStack(spacing: Space.s2) {
                    Image(systemName: "character.book.closed").font(.system(size: 26)).foregroundStyle(TronColor.muted)
                    Text("Aucune correction pour l'instant").font(TronFont.heading).foregroundStyle(TronColor.ink)
                    Text("Quand Tron écrit mal un mot, un nom ou une marque, ajoutez-le ici.")
                        .font(TronFont.body)
                        .foregroundStyle(TronColor.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries) { entry in
                        row(entry)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { editing = entry }
                            .contextMenu {
                                Button("Modifier…") { editing = entry }
                                Button("Supprimer", role: .destructive) { delete(entry) }
                            }
                    }
                    .onDelete { offsets in
                        entries.remove(atOffsets: offsets)
                        Corrections.save(entries)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(item: $editing) { entry in
            CorrectionEditor(entry: entry) { reload() }
        }
        .onAppear { reload() }
    }

    private func row(_ entry: Correction) -> some View {
        HStack(spacing: Space.s2) {
            Text(entry.heard)
                .font(TronFont.sans(14))
                .foregroundStyle(TronColor.muted)
                .strikethrough(color: TronColor.lineStrong)
            Image(systemName: "arrow.right")
                .font(TronFont.sans(11, .semibold))
                .foregroundStyle(TronColor.lineStrong)
            Text(entry.correct)
                .font(TronFont.sans(14, .semibold))
                .foregroundStyle(TronColor.ink)
            Spacer(minLength: 0)
            Button { delete(entry) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(TronColor.lineStrong)
            }
            .buttonStyle(.plain)
            .help("Supprimer")
        }
        .lineLimit(1)
        .padding(.vertical, 2)
    }

    private func add() {
        guard canAdd else { return }
        Corrections.add(heard: heard, correct: correct)
        heard = ""
        correct = ""
        heardFocused = true
        reload()
    }

    private func delete(_ entry: Correction) {
        entries.removeAll { $0.id == entry.id }
        Corrections.save(entries)
    }

    private func reload() { entries = Corrections.all() }
}

private struct CorrectionEditor: View {
    let entry: Correction
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var heard = ""
    @State private var correct = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text("Correction").font(TronFont.heading)
            Form {
                TextField("Tron entend", text: $heard)
                TextField("Tron écrit", text: $correct)
            }
            .autocorrectionDisabled()
            HStack {
                Button("Supprimer", role: .destructive) {
                    Corrections.save(Corrections.all().filter { $0.id != entry.id })
                    onDone()
                    dismiss()
                }
                Spacer()
                Button("Annuler") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") {
                    var list = Corrections.all()
                    if let i = list.firstIndex(where: { $0.id == entry.id }) {
                        list[i].heard = heard.trimmingCharacters(in: .whitespaces)
                        list[i].correct = correct.trimmingCharacters(in: .whitespaces)
                        Corrections.save(list)
                    }
                    onDone()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(heard.trimmingCharacters(in: .whitespaces).isEmpty || correct.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Space.s6)
        .frame(width: 380)
        .onAppear {
            heard = entry.heard
            correct = entry.correct
        }
    }
}

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Corriger dans Tron" in the share sheet: saves a correction for the selected text.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadSelection { [weak self] text in
            guard let self else { return }
            let sheet = UIHostingController(rootView: CorrectionSheet(heard: text) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            })
            sheet.view.backgroundColor = .clear
            self.addChild(sheet)
            sheet.view.frame = self.view.bounds
            sheet.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(sheet.view)
            sheet.didMove(toParent: self)
        }
    }

    private func loadSelection(_ done: @escaping (String) -> Void) {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        if let text = items.compactMap({ $0.attributedContentText?.string }).first(where: { !$0.isEmpty }) {
            done(text.trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        let provider = items.flatMap { $0.attachments ?? [] }
            .first { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        guard let provider else { done(""); return }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
            let text = (item as? String) ?? ""
            DispatchQueue.main.async { done(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }
}

private struct CorrectionSheet: View {
    @State var heard: String
    @State private var correct = ""
    @State private var saved = false
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack {
                Text("Corriger dans Tron")
                    .font(TronFont.heading)
                    .foregroundStyle(TronColor.ink)
                Spacer()
                Button("Annuler", action: close)
                    .font(TronFont.body)
                    .foregroundStyle(TronColor.brand)
            }
            field("Tron entend", text: $heard, placeholder: "ex. tronc")
            field("Tron écrit", text: $correct, placeholder: "ex. Tron")
            Text(saved ? "Enregistré." : "Appliqué à vos prochaines dictées. Le texte déjà écrit ne change pas ici.")
                .font(TronFont.caption)
                .foregroundStyle(saved ? TronColor.brand : TronColor.muted)
            Button {
                Corrections.add(heard: heard, correct: correct)
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: close)
            } label: {
                Text("Enregistrer")
                    .font(TronFont.bodyStrong)
                    .foregroundStyle(TronColor.onBrand)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(TronColor.brand))
            }
            .disabled(heard.trimmingCharacters(in: .whitespaces).isEmpty || correct.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Space.s6)
        .background(RoundedRectangle(cornerRadius: Radius.lg).fill(TronColor.paper))
        .padding(Space.s4)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(title).font(TronFont.label).foregroundStyle(TronColor.muted)
            TextField(placeholder, text: text)
                .font(TronFont.body)
                .autocorrectionDisabled()
                .padding(.horizontal, Space.s3)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: Radius.md).fill(TronColor.surface))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(TronColor.line))
        }
    }
}

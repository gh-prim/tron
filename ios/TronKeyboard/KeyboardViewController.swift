import UIKit

/// Tron mini keyboard: a mic key and a few keys. Keyboards cannot use the microphone, so the mic key
/// stops a running dictation, or opens Tron to start one. Finished dictations are typed at the cursor once.
final class KeyboardViewController: UIInputViewController {
    private let status = UILabel()
    private let micButton = UIButton(type: .system)
    private var globeButton: UIButton?
    private var observers: [DarwinObserver] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        observers = [
            DarwinObserver(TronShared.Signal.state) { [weak self] in self?.refresh() },
            DarwinObserver(TronShared.Signal.result) { [weak self] in self?.insertPendingResult() },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        insertPendingResult()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        globeButton?.isHidden = !needsInputModeSwitchKey
    }

    // MARK: Dictation

    @objc private func micTapped() {
        guard hasFullAccess else {
            status.text = "Activez l'Accès complet pour le clavier Tron dans Réglages."
            return
        }
        UIDevice.current.playInputClick()
        switch TronShared.state {
        case .recording:
            DarwinSignal.post(TronShared.Signal.stop)
        case .transcribing:
            break
        case .idle:
            openTron()
        }
    }

    /// Types the last dictation at the cursor, once, if it is recent and meant for the keyboard.
    private func insertPendingResult() {
        guard hasFullAccess else { return }
        let d = TronShared.defaults
        guard d.bool(forKey: TronShared.Key.resultForKeyboard),
              let id = d.string(forKey: TronShared.Key.resultID),
              id != d.string(forKey: TronShared.Key.insertedID),
              let text = d.string(forKey: TronShared.Key.resultText), !text.isEmpty,
              Date().timeIntervalSince1970 - d.double(forKey: TronShared.Key.resultAt) < 120
        else { refresh(); return }
        d.set(id, forKey: TronShared.Key.insertedID)
        var insert = text
        if let last = textDocumentProxy.documentContextBeforeInput?.last, !last.isWhitespace {
            insert = " " + insert
        }
        textDocumentProxy.insertText(insert)
        status.text = "Texte inséré."
        status.textColor = Palette.brand
    }

    private func refresh() {
        guard hasFullAccess else {
            status.text = "Activez l'Accès complet pour dicter."
            status.textColor = Palette.muted
            setMic(recording: false)
            return
        }
        switch TronShared.state {
        case .recording:
            status.text = "Écoute… Touchez pour terminer."
            status.textColor = Palette.live
            setMic(recording: true)
        case .transcribing:
            status.text = "Transcription…"
            status.textColor = Palette.muted
            setMic(recording: false)
        case .idle:
            status.text = "Touchez le micro ou le bouton Action pour dicter."
            status.textColor = Palette.muted
            setMic(recording: false)
        }
    }

    private func setMic(recording: Bool) {
        micButton.backgroundColor = recording ? Palette.live : Palette.brand
        micButton.tintColor = recording ? Palette.onLive : Palette.onBrand
        micButton.setImage(UIImage(systemName: recording ? "stop.fill" : "mic.fill"), for: .normal)
        micButton.accessibilityLabel = recording ? "Terminer la dictée" : "Dicter avec Tron"
    }

    /// Extensions cannot call UIApplication.shared; the app object is found in the responder chain.
    private func openTron() {
        let url = TronShared.dictateURL
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector), current is UIApplication {
                typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, Any?) -> Void
                let open = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = current.next
        }
        extensionContext?.open(url, completionHandler: nil)
    }

    // MARK: Keys

    @objc private func insertKey(_ sender: UIButton) {
        guard let text = sender.accessibilityValue else { return }
        UIDevice.current.playInputClick()
        textDocumentProxy.insertText(text)
    }

    @objc private func deleteKey() {
        UIDevice.current.playInputClick()
        textDocumentProxy.deleteBackward()
    }

    @objc private func returnKey() {
        UIDevice.current.playInputClick()
        textDocumentProxy.insertText("\n")
    }

    // MARK: Layout

    private func buildLayout() {
        guard let inputView else { return }
        inputView.allowsSelfSizing = true
        view.backgroundColor = Palette.paper

        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textAlignment = .center
        status.numberOfLines = 2
        status.adjustsFontSizeToFitNotEnoughSpace()

        micButton.layer.cornerRadius = 32
        micButton.setPreferredSymbolConfiguration(.init(pointSize: 24, weight: .semibold), forImageIn: .normal)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            micButton.widthAnchor.constraint(equalToConstant: 64),
            micButton.heightAnchor.constraint(equalToConstant: 64),
        ])
        setMic(recording: false)

        let globe = key(symbol: "globe", label: "Clavier suivant")
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        globeButton = globe

        let comma = key(text: ",")
        let period = key(text: ".")
        let question = key(text: "?")
        let space = key(title: "espace", insert: " ")
        let delete = key(symbol: "delete.left", label: "Effacer")
        delete.addTarget(self, action: #selector(deleteKey), for: .touchUpInside)
        let ret = key(symbol: "return", label: "Retour")
        ret.addTarget(self, action: #selector(returnKey), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [globe, comma, period, question, space, delete, ret])
        row.spacing = 6
        row.distribution = .fill
        for k in [globe, comma, period, question, delete, ret] {
            k.widthAnchor.constraint(equalToConstant: 40).isActive = true
        }

        let micRow = UIStackView(arrangedSubviews: [micButton])
        micRow.alignment = .center
        micRow.axis = .vertical

        let stack = UIStackView(arrangedSubviews: [status, micRow, row])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
            row.heightAnchor.constraint(equalToConstant: 44),
            status.heightAnchor.constraint(greaterThanOrEqualToConstant: 18),
        ])
    }

    private func key(text: String) -> UIButton {
        key(title: text, insert: text)
    }

    private func key(title: String, insert: String) -> UIButton {
        let b = baseKey()
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: insert == " " ? 15 : 22)
        b.accessibilityValue = insert
        b.addTarget(self, action: #selector(insertKey(_:)), for: .touchUpInside)
        return b
    }

    private func key(symbol: String, label: String) -> UIButton {
        let b = baseKey()
        b.setImage(UIImage(systemName: symbol), for: .normal)
        b.accessibilityLabel = label
        return b
    }

    private func baseKey() -> UIButton {
        let b = UIButton(type: .system)
        b.backgroundColor = Palette.surface
        b.tintColor = Palette.ink
        b.setTitleColor(Palette.ink, for: .normal)
        b.layer.cornerRadius = 8
        b.layer.borderWidth = 1
        b.layer.borderColor = Palette.line.cgColor
        return b
    }
}

private extension UILabel {
    func adjustsFontSizeToFitNotEnoughSpace() {
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor = 0.8
    }
}

/// UIKit versions of the Tron color tokens (Shared/Theme.swift).
private enum Palette {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    static let paper = dynamic(0xF6F4EF, 0x121311)
    static let surface = dynamic(0xFFFFFF, 0x1B1C1A)
    static let line = dynamic(0xE2DED5, 0x2E302C)
    static let ink = dynamic(0x16171A, 0xEDEBE5)
    static let muted = dynamic(0x5E6066, 0xA3A49E)
    static let brand = dynamic(0x1F4D3F, 0x7FC4A8)
    static let onBrand = dynamic(0xFFFFFF, 0x0E1F18)
    static let live = dynamic(0xC2410C, 0xFB8A4E)
    static let onLive = dynamic(0xFFFFFF, 0x1A0C05)
}

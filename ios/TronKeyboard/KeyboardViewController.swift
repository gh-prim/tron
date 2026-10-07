import UIKit

/// Tron keyboard: a full French AZERTY keyboard with a discreet Tron key in the top bar.
/// Keyboards cannot use the microphone, so the Tron key stops a running dictation, starts one when the app keeps
/// the mic armed, or opens Tron once to turn the mic on. Finished dictations are typed at the cursor once.
final class KeyboardViewController: UIInputViewController {
    fileprivate enum Layout { case letters, numbers, symbols }
    private enum Shift { case off, on, locked }

    fileprivate enum Key {
        case char(String)
        case shift, delete, space, returnKey, globe
        case layout(Layout, String)
    }

    private let topBar = UIView()
    private let status = UILabel()
    private let accentStrip = UIStackView()
    private let tronButton = UIButton(type: .system)
    private let keysView = UIStackView()
    /// "Corriger « … »" chip, shown while a short text is selected.
    private let correctChip = UIButton(type: .system)
    private let correctionBar = UIStackView()
    private let correctionLabel = UILabel()
    private var correcting = false
    private var correctionHeard = ""
    private var correctionText = ""

    private var layout: Layout = .letters
    private var shift: Shift = .on
    private var lastShiftTap = Date.distantPast
    private var lastSpace = Date.distantPast
    private var deleteTimer: Timer?
    private var heightConstraint: NSLayoutConstraint?
    private var observers: [DarwinObserver] = []
    private var statusClear: DispatchWorkItem?
    /// Dictation currently shown at the cursor as provisional (marked) text.
    private var markedSession: String?
    private var markedPrefix = ""
    /// Dictations whose live text was committed early (keyboard closed): no second insert.
    private var abandonedSessions: Set<String> = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildChrome()
        rebuildKeys()
        observers = [
            DarwinObserver(TronShared.Signal.state) { [weak self] in self?.refreshTron() },
            DarwinObserver(TronShared.Signal.result) { [weak self] in self?.insertPendingResult(maxAge: 30) },
            DarwinObserver(TronShared.Signal.partial) { [weak self] in self?.showPartial() },
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTron()
        // Only a result that just finished: an older one stays in the clipboard.
        insertPendingResult(maxAge: 5)
        updateAutoShift()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Keyboard closed mid-dictation: keep what is written, skip the final insert.
        commitMarked()
    }

    /// Makes the provisional text regular and stops live updates for that dictation (typing, keyboard closed).
    private func commitMarked() {
        guard let session = markedSession else { return }
        textDocumentProxy.unmarkText()
        abandonedSessions.insert(session)
        markedSession = nil
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        heightConstraint?.constant = 262
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAutoShift()
        updateCorrectChip()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        updateCorrectChip()
    }

    // MARK: Corrections

    private var selection: String? {
        guard let text = textDocumentProxy.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count <= 40, !text.contains("\n") else { return nil }
        return text
    }

    private func updateCorrectChip() {
        guard !correcting else { return }
        if hasFullAccess, let text = selection {
            correctChip.setTitle("Corriger « \(text) »", for: .normal)
            correctChip.isHidden = false
            status.isHidden = true
        } else {
            correctChip.isHidden = true
            status.isHidden = !accentStrip.isHidden
        }
    }

    @objc private func startCorrection() {
        guard let text = selection else { return }
        hideAccents()
        correcting = true
        correctionHeard = text
        correctionText = text
        correctChip.isHidden = true
        status.isHidden = true
        correctionBar.isHidden = false
        shift = .off
        refreshLetters()
        refreshCorrection()
    }

    private func refreshCorrection() {
        correctionLabel.text = correctionText + "|"
    }

    @objc private func validateCorrection() {
        let correct = correctionText.trimmingCharacters(in: .whitespaces)
        let heard = correctionHeard
        endCorrection()
        guard !correct.isEmpty else { return }
        // Typing with a selection replaces it.
        if correct != heard { textDocumentProxy.insertText(correct) }
        Corrections.add(heard: heard, correct: correct)
        showStatus("Corrigé. Tron l'écrira ainsi la prochaine fois.", color: Palette.brand, for: 3)
    }

    @objc private func endCorrection() {
        correcting = false
        correctionBar.isHidden = true
        status.isHidden = false
        updateCorrectChip()
        updateAutoShift()
    }

    // MARK: Tron dictation

    @objc private func tronTapped() {
        guard hasFullAccess else {
            showStatus("Activez l'Accès complet pour le clavier Tron dans Réglages.", color: Palette.muted, for: 4)
            return
        }
        switch TronShared.state {
        case .recording:
            DarwinSignal.post(TronShared.Signal.stop)
        case .transcribing:
            break
        case .ready:
            DarwinSignal.post(TronShared.Signal.start)
        case .idle:
            openTron()
        }
    }

    /// Live transcript at the cursor, as provisional text replaced in one block at each update.
    private func showPartial() {
        guard hasFullAccess else { return }
        let d = TronShared.defaults
        guard d.bool(forKey: TronShared.Key.partialForKeyboard),
              let session = d.string(forKey: TronShared.Key.partialSession),
              !abandonedSessions.contains(session)
        else { return }
        let text = d.string(forKey: TronShared.Key.partialText) ?? ""
        if text.isEmpty {
            // Cancelled or failed: drop the provisional text.
            if markedSession == session {
                textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
                textDocumentProxy.unmarkText()
                markedSession = nil
            }
            return
        }
        if markedSession != session {
            if let last = textDocumentProxy.documentContextBeforeInput?.last, !last.isWhitespace {
                markedPrefix = " "
            } else {
                markedPrefix = ""
            }
            markedSession = session
        }
        let shown = markedPrefix + text
        textDocumentProxy.setMarkedText(shown, selectedRange: NSRange(location: (shown as NSString).length, length: 0))
    }

    /// Types the last dictation at the cursor, once, if it is recent and meant for the keyboard.
    private func insertPendingResult(maxAge: TimeInterval) {
        guard hasFullAccess else { return }
        let d = TronShared.defaults
        let session = d.string(forKey: TronShared.Key.resultSession) ?? ""
        if abandonedSessions.contains(session) {
            if let id = d.string(forKey: TronShared.Key.resultID) { d.set(id, forKey: TronShared.Key.insertedID) }
            refreshTron()
            return
        }
        guard d.bool(forKey: TronShared.Key.resultForKeyboard),
              let id = d.string(forKey: TronShared.Key.resultID),
              id != d.string(forKey: TronShared.Key.insertedID),
              let text = d.string(forKey: TronShared.Key.resultText), !text.isEmpty,
              Date().timeIntervalSince1970 - d.double(forKey: TronShared.Key.resultAt) < maxAge
        else { refreshTron(); return }
        d.set(id, forKey: TronShared.Key.insertedID)
        if markedSession == session {
            // The final clean text replaces the provisional one, then becomes regular text.
            let shown = markedPrefix + text
            textDocumentProxy.setMarkedText(shown, selectedRange: NSRange(location: (shown as NSString).length, length: 0))
            textDocumentProxy.unmarkText()
            markedSession = nil
        } else {
            var insert = text
            if let last = textDocumentProxy.documentContextBeforeInput?.last, !last.isWhitespace {
                insert = " " + insert
            }
            textDocumentProxy.insertText(insert)
        }
        DarwinSignal.post(TronShared.Signal.inserted)
        refreshTron()
        showStatus("Texte inséré", color: Palette.brand, for: 2)
    }

    private func refreshTron() {
        let state = hasFullAccess ? TronShared.state : .idle
        let recording = state == .recording
        tronButton.backgroundColor = recording ? Palette.live : Palette.brandTint
        tronButton.tintColor = recording ? Palette.onLive : Palette.brand
        tronButton.setImage(UIImage(systemName: recording ? "stop.fill" : "mic.fill"), for: .normal)
        tronButton.accessibilityLabel = recording ? "Terminer la dictée" : "Dicter avec Tron"
        switch state {
        case .recording: showStatus("Écoute…", color: Palette.live, for: nil)
        case .transcribing: showStatus("Transcription…", color: Palette.muted, for: nil)
        case .idle, .ready:
            if status.text == "Écoute…" || status.text == "Transcription…" { showStatus(nil, color: Palette.muted, for: nil) }
        }
    }

    private func showStatus(_ text: String?, color: UIColor, for seconds: TimeInterval?) {
        statusClear?.cancel()
        status.text = text
        status.textColor = color
        guard let seconds else { return }
        let work = DispatchWorkItem { [weak self] in self?.status.text = nil }
        statusClear = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
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

    // MARK: Typing

    private func type(_ text: String) {
        hideAccents()
        if correcting {
            if text == "\n" { validateCorrection(); return }
            correctionText += text
            if shift == .on { shift = .off; refreshLetters() }
            refreshCorrection()
            return
        }
        commitMarked()
        let proxy = textDocumentProxy
        if text == " " {
            // Double space: ". " like the system keyboard.
            if Date().timeIntervalSince(lastSpace) < 0.4,
               let before = proxy.documentContextBeforeInput, before.hasSuffix(" "),
               let previous = before.dropLast().last, previous.isLetter || previous.isNumber {
                proxy.deleteBackward()
                proxy.insertText(". ")
                lastSpace = .distantPast
                updateAutoShift()
                return
            }
            lastSpace = Date()
        }
        proxy.insertText(text)
        if shift == .on, layout == .letters { shift = .off; refreshLetters() }
        updateAutoShift()
    }

    private func updateAutoShift() {
        guard layout == .letters, shift != .locked, !correcting else { return }
        let type = textDocumentProxy.autocapitalizationType ?? .sentences
        var wantsCap = false
        if type == .allCharacters {
            wantsCap = true
        } else if type == .sentences || type == .words {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || before.hasSuffix("\n") {
                wantsCap = true
            } else if before.hasSuffix(" "), let last = trimmed.last {
                wantsCap = ".?!".contains(last) || type == .words
            }
        }
        let next: Shift = wantsCap ? .on : .off
        if next != shift { shift = next; refreshLetters() }
    }

    @objc private func keyTapped(_ sender: KeyButton) {
        guard let key = sender.key else { return }
        UIDevice.current.playInputClick()
        switch key {
        case .char(let c):
            type(shift == .off || layout != .letters ? c : c.uppercased())
        case .space:
            type(" ")
        case .returnKey:
            type("\n")
        case .shift:
            let now = Date()
            if now.timeIntervalSince(lastShiftTap) < 0.3 {
                shift = .locked
            } else {
                shift = shift == .off ? .on : .off
            }
            lastShiftTap = now
            refreshLetters()
        case .layout(let target, _):
            layout = target
            rebuildKeys()
            updateAutoShift()
        case .delete, .globe:
            break
        }
    }

    @objc private func deleteDown() {
        hideAccents()
        if correcting {
            if !correctionText.isEmpty { correctionText.removeLast() }
            refreshCorrection()
            return
        }
        commitMarked()
        textDocumentProxy.deleteBackward()
        deleteTimer?.invalidate()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                self?.textDocumentProxy.deleteBackward()
            }
        }
    }

    @objc private func deleteUp() {
        deleteTimer?.invalidate()
        deleteTimer = nil
        updateAutoShift()
    }

    // MARK: Accents (long press)

    private static let accents: [String: [String]] = [
        "e": ["é", "è", "ê", "ë"], "a": ["à", "â", "æ", "ä"], "u": ["ù", "û", "ü"],
        "i": ["î", "ï"], "o": ["ô", "œ", "ö"], "c": ["ç"], "y": ["ÿ"], "n": ["ñ"],
    ]

    @objc private func longPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? KeyButton,
              case .char(let c) = button.key, let variants = Self.accents[c] else { return }
        let upper = shift != .off
        accentStrip.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for v in variants {
            let b = KeyButton(type: .system)
            b.key = .char(upper ? v.uppercased() : v)
            b.setTitle(upper ? v.uppercased() : v, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 22)
            style(b, special: false)
            b.addTarget(self, action: #selector(accentTapped(_:)), for: .touchUpInside)
            b.widthAnchor.constraint(equalToConstant: 40).isActive = true
            accentStrip.addArrangedSubview(b)
        }
        accentStrip.isHidden = false
        status.isHidden = true
    }

    @objc private func accentTapped(_ sender: KeyButton) {
        guard case .char(let c) = sender.key else { return }
        textDocumentProxy.insertText(c)
        if shift == .on { shift = .off; refreshLetters() }
        hideAccents()
        updateAutoShift()
    }

    private func hideAccents() {
        guard !accentStrip.isHidden else { return }
        accentStrip.isHidden = true
        status.isHidden = false
    }

    // MARK: Layout

    private func buildChrome() {
        view.backgroundColor = Palette.paper
        heightConstraint = view.heightAnchor.constraint(equalToConstant: 262)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true

        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = Palette.muted
        accentStrip.spacing = 6
        accentStrip.isHidden = true

        tronButton.layer.cornerRadius = 15
        tronButton.setPreferredSymbolConfiguration(.init(pointSize: 13, weight: .semibold), forImageIn: .normal)
        tronButton.addTarget(self, action: #selector(tronTapped), for: .touchUpInside)
        refreshTron()

        for v in [topBar, status, accentStrip, tronButton, keysView] { v.translatesAutoresizingMaskIntoConstraints = false }
        topBar.addSubview(status)
        topBar.addSubview(accentStrip)
        topBar.addSubview(tronButton)

        correctChip.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        correctChip.titleLabel?.lineBreakMode = .byTruncatingMiddle
        correctChip.setTitleColor(Palette.brand, for: .normal)
        correctChip.backgroundColor = Palette.brandTint
        correctChip.layer.cornerRadius = 14
        correctChip.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        correctChip.isHidden = true
        correctChip.addTarget(self, action: #selector(startCorrection), for: .touchUpInside)

        correctionLabel.font = .systemFont(ofSize: 15, weight: .medium)
        correctionLabel.textColor = Palette.ink
        correctionLabel.backgroundColor = Palette.surface
        correctionLabel.layer.cornerRadius = 8
        correctionLabel.layer.masksToBounds = true
        correctionLabel.lineBreakMode = .byTruncatingHead
        let cancel = UIButton(type: .system)
        cancel.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancel.tintColor = Palette.muted
        cancel.accessibilityLabel = "Annuler la correction"
        cancel.addTarget(self, action: #selector(endCorrection), for: .touchUpInside)
        let validate = UIButton(type: .system)
        validate.setTitle("Valider", for: .normal)
        validate.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        validate.setTitleColor(Palette.onBrand, for: .normal)
        validate.backgroundColor = Palette.brand
        validate.layer.cornerRadius = 14
        validate.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        validate.addTarget(self, action: #selector(validateCorrection), for: .touchUpInside)
        for v in [cancel, correctionLabel, validate] { correctionBar.addArrangedSubview(v) }
        correctionBar.spacing = 8
        correctionBar.alignment = .center
        correctionBar.isHidden = true
        cancel.widthAnchor.constraint(equalToConstant: 28).isActive = true
        correctionLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true
        validate.heightAnchor.constraint(equalToConstant: 28).isActive = true
        validate.setContentHuggingPriority(.required, for: .horizontal)
        for v in [correctChip, correctionBar] {
            v.translatesAutoresizingMaskIntoConstraints = false
            topBar.addSubview(v)
        }
        view.addSubview(topBar)
        view.addSubview(keysView)

        keysView.axis = .vertical
        keysView.spacing = 10
        keysView.distribution = .fillEqually

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            topBar.heightAnchor.constraint(equalToConstant: 36),

            status.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            status.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: tronButton.leadingAnchor, constant: -8),
            accentStrip.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            accentStrip.topAnchor.constraint(equalTo: topBar.topAnchor),
            accentStrip.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),

            correctChip.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            correctChip.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            correctChip.heightAnchor.constraint(equalToConstant: 28),
            correctChip.trailingAnchor.constraint(lessThanOrEqualTo: tronButton.leadingAnchor, constant: -8),
            correctionBar.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            correctionBar.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            correctionBar.trailingAnchor.constraint(equalTo: tronButton.leadingAnchor, constant: -8),

            tronButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            tronButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            tronButton.widthAnchor.constraint(equalToConstant: 44),
            tronButton.heightAnchor.constraint(equalToConstant: 30),

            keysView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            keysView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            keysView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            keysView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
    }

    private func rows(for layout: Layout) -> [[Key]] {
        func chars(_ s: String) -> [Key] { s.map { .char(String($0)) } }
        let bottom: [Key] = [
            layout == .letters ? .layout(.numbers, "123") : .layout(.letters, "ABC"),
            .globe, .space, .returnKey,
        ]
        switch layout {
        case .letters:
            return [chars("azertyuiop"), chars("qsdfghjklm"), [.shift] + chars("wxcvbn'") + [.delete], bottom]
        case .numbers:
            return [chars("1234567890"), chars("-/:;()€&@\""), [.layout(.symbols, "#+=")] + chars(".,?!'") + [.delete], bottom]
        case .symbols:
            return [chars("[]{}#%^*+="), chars("_\\|~<>$£¥•"), [.layout(.numbers, "123")] + chars(".,?!'") + [.delete], bottom]
        }
    }

    private func rebuildKeys() {
        hideAccents()
        keysView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var unit: UIView?
        for (index, keys) in rows(for: layout).enumerated() {
            let row = UIStackView()
            row.spacing = 6
            row.distribution = index < 2 ? .fillEqually : .fill
            // In the hierarchy first: key widths are tied to a key of the first row.
            keysView.addArrangedSubview(row)
            var specials: [UIView] = []
            for key in keys {
                let b = makeKey(key)
                if key.isGlobe, !needsInputModeSwitchKey { continue }
                row.addArrangedSubview(b)
                if index == 0, unit == nil { unit = b }
                guard index >= 2, let unit else { continue }
                switch key {
                case .char:
                    b.widthAnchor.constraint(equalTo: unit.widthAnchor).isActive = true
                case .space:
                    break
                case .returnKey:
                    b.widthAnchor.constraint(equalTo: unit.widthAnchor, multiplier: 2).isActive = true
                case .globe:
                    b.widthAnchor.constraint(equalTo: unit.widthAnchor).isActive = true
                case .layout where index == 3:
                    b.widthAnchor.constraint(equalTo: unit.widthAnchor, multiplier: 1.3).isActive = true
                default:
                    specials.append(b)
                }
            }
            // Shift and delete share the room left on the third row.
            if specials.count == 2 {
                specials[0].widthAnchor.constraint(equalTo: specials[1].widthAnchor).isActive = true
            }
        }
        refreshLetters()
    }

    private func makeKey(_ key: Key) -> KeyButton {
        let b = KeyButton(type: .system)
        b.key = key
        switch key {
        case .char(let c):
            b.setTitle(c, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 23)
            style(b, special: false)
            if Self.accents[c] != nil {
                b.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:))))
            }
        case .space:
            b.setTitle("Tron", for: .normal)
            b.accessibilityLabel = "Espace"
            b.titleLabel?.font = .systemFont(ofSize: 16)
            style(b, special: false)
        case .returnKey:
            b.setImage(UIImage(systemName: "return"), for: .normal)
            b.accessibilityLabel = "Retour"
            style(b, special: true)
        case .shift:
            b.accessibilityLabel = "Majuscule"
            style(b, special: true)
        case .delete:
            b.setImage(UIImage(systemName: "delete.left"), for: .normal)
            b.accessibilityLabel = "Effacer"
            style(b, special: true)
            b.addTarget(self, action: #selector(deleteDown), for: .touchDown)
            b.addTarget(self, action: #selector(deleteUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            return b
        case .globe:
            b.setImage(UIImage(systemName: "globe"), for: .normal)
            b.accessibilityLabel = "Clavier suivant"
            style(b, special: true)
            b.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            return b
        case .layout(_, let title):
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 16)
            style(b, special: true)
        }
        b.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        return b
    }

    private func style(_ b: UIButton, special: Bool) {
        b.backgroundColor = special ? Palette.special : Palette.surface
        b.tintColor = Palette.ink
        b.setTitleColor(Palette.ink, for: .normal)
        b.layer.cornerRadius = 6
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.18
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.layer.shadowRadius = 0
    }

    /// Letter case and the shift key icon.
    private func refreshLetters() {
        for case let row as UIStackView in keysView.arrangedSubviews {
            for case let b as KeyButton in row.arrangedSubviews {
                switch b.key {
                case .char(let c) where layout == .letters:
                    b.setTitle(shift == .off ? c : c.uppercased(), for: .normal)
                case .shift:
                    let name = shift == .locked ? "capslock.fill" : (shift == .on ? "shift.fill" : "shift")
                    b.setImage(UIImage(systemName: name), for: .normal)
                    b.backgroundColor = shift == .off ? Palette.special : Palette.surface
                default:
                    break
                }
            }
        }
    }
}

private final class KeyButton: UIButton {
    var key: KeyboardViewController.Key?
}

private extension KeyboardViewController.Key {
    var isGlobe: Bool { if case .globe = self { return true } else { return false } }
}

/// UIKit versions of the Tron color tokens (Shared/Theme.swift).
private enum Palette {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    static let paper = dynamic(0xD5D7DD, 0x2B2B2D)
    static let surface = dynamic(0xFFFFFF, 0x6B6B6E)
    static let special = dynamic(0xABB0BA, 0x47474A)
    static let ink = dynamic(0x16171A, 0xEDEBE5)
    static let muted = dynamic(0x5E6066, 0xA3A49E)
    static let brand = dynamic(0x1F4D3F, 0x7FC4A8)
    static let brandTint = dynamic(0xDCEBE3, 0x1E3A30)
    static let onBrand = dynamic(0xFFFFFF, 0x0E1F18)
    static let live = dynamic(0xC2410C, 0xFB8A4E)
    static let onLive = dynamic(0xFFFFFF, 0x1A0C05)
}

import AppKit
import ApplicationServices

/// Puts the text at the cursor of the frontmost app, or leaves it in the clipboard.
enum Paster {
    enum Outcome { case pasted, copied }

    private static let editableRoles: Set<String> = [
        kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField",
    ]

    /// True when the focused element of the frontmost app takes text.
    static func focusedFieldTakesText() -> Bool {
        if let app = NSWorkspace.shared.frontmostApplication {
            // Electron and Chromium apps only expose their fields once asked to.
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        let element = value as! AXUIElement

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let role = role as? String, editableRoles.contains(role) { return true }

        // Web fields and custom text views: a selection range, or a value that can be set.
        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success { return true }
        var settable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue { return true }
        return false
    }

    @MainActor
    static func insert(_ text: String) async -> Outcome {
        let pasteboard = NSPasteboard.general
        guard focusedFieldTakesText() else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copied
        }
        let saved = snapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Clipboard managers skip transient entries.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let ours = pasteboard.changeCount
        pressCommandV()
        // Give the app time to read the clipboard, then put back what was there.
        try? await Task.sleep(for: .milliseconds(400))
        if pasteboard.changeCount == ours {
            pasteboard.clearContents()
            if !saved.isEmpty { pasteboard.writeObjects(saved) }
        }
        return .pasted
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func pressCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

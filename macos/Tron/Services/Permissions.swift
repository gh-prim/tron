import AppKit
import ApplicationServices
import AVFoundation

enum Permissions {
    static var microphone: Bool { AVAudioApplication.shared.recordPermission == .granted }
    static var microphoneDenied: Bool { AVAudioApplication.shared.recordPermission == .denied }

    static func requestMicrophone() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Needed to read the fn key in every app and to paste at the cursor.
    static var accessibility: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt the first time, then opens the right pane of System Settings.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    /// What the 🌐 key does on its own: 0 nothing, 1 input source, 2 emoji, 3 dictation. Unset means emoji.
    static var globeKeyIsFree: Bool {
        UserDefaults(suiteName: "com.apple.HIToolbox")?.object(forKey: "AppleFnUsageType") as? Int == 0
    }

    static func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private static func open(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}

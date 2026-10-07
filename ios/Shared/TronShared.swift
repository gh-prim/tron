import Foundation

/// State shared by the app, the Live Activity and the Tron keyboard through the App Group.
enum TronShared {
    static let appGroup = "group.app.tron.ios"
    static let dictateURL = URL(string: "tron://dictate")!

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    enum Key {
        static let actionButtonMode = "actionButtonMode"
        static let language = "language"
        /// "idle", "ready", "recording" or "transcribing".
        static let state = "dictationState"
        /// Refreshed every second while recording, so a crashed session does not look alive.
        static let stateAt = "dictationStateAt"
        static let resultID = "resultID"
        static let resultText = "resultText"
        static let resultAt = "resultAt"
        /// True when the result should be typed at the cursor by the Tron keyboard.
        static let resultForKeyboard = "resultForKeyboard"
        /// Dictation the result or the live text belongs to.
        static let resultSession = "resultSession"
        static let partialSession = "partialSession"
        /// Live transcript while recording; empty means "drop the provisional text".
        static let partialText = "partialText"
        /// True when the live transcript should show at the cursor.
        static let partialForKeyboard = "partialForKeyboard"
        /// Last result the keyboard typed, so each result is inserted once.
        static let insertedID = "insertedID"
    }

    /// Darwin notification names (cross-process, no payload).
    enum Signal {
        static let stop = "app.tron.ios.stop"
        /// Keyboard mic key while the mic is armed: start without opening the app.
        static let start = "app.tron.ios.start"
        static let state = "app.tron.ios.state"
        static let result = "app.tron.ios.result"
        static let partial = "app.tron.ios.partial"
        /// Posted by the keyboard once it typed the result.
        static let inserted = "app.tron.ios.inserted"
    }

    enum State: String {
        /// `ready`: the app keeps the mic armed in the background, the keyboard can start without opening it.
        case idle, ready, recording, transcribing
    }

    static var state: State {
        let d = defaults
        guard let raw = d.string(forKey: Key.state), let s = State(rawValue: raw) else { return .idle }
        // A recording that stopped sending heartbeats is dead (app killed).
        if s == .recording || s == .ready, Date().timeIntervalSince1970 - d.double(forKey: Key.stateAt) > 3 { return .idle }
        if s == .transcribing, Date().timeIntervalSince1970 - d.double(forKey: Key.stateAt) > 60 { return .idle }
        return s
    }
}

enum DarwinSignal {
    static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString), nil, nil, true
        )
    }
}

/// Listens to one Darwin notification and calls `handler` on the main queue. Keep a reference while needed.
final class DarwinObserver {
    private let name: String
    private let handler: () -> Void

    init(_ name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let me = Unmanaged<DarwinObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { me.handler() }
            },
            name as CFString, nil, .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(name as CFString), nil
        )
    }
}

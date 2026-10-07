import Foundation

/// Storage keys the shared core expects. No App Group on the Mac (no keyboard or widget): the app's own defaults.
enum TronShared {
    static var defaults: UserDefaults { .standard }

    enum Key {
        static let actionButtonMode = "shared.actionButtonMode"
        static let language = "shared.language"
    }
}

import CoreGraphics
import Foundation

/// Watches the fn / 🌐 key in every app through a session event tap (needs Accessibility).
/// The fn presses are swallowed so macOS does not also open the emoji picker or its own dictation.
final class FnKeyMonitor {
    var onDown: () -> Void = {}
    var onUp: () -> Void = {}
    /// Another key was pressed while fn was held (fn used as a modifier, e.g. fn + arrow).
    var onChord: () -> Void = {}
    /// Escape. Return true to swallow it (while Tron is recording).
    var onEscape: () -> Bool = { false }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var fnDown = false

    private static let fnKeyCode: Int64 = 63
    private static let escapeKeyCode: Int64 = 53

    var isRunning: Bool { tap != nil }

    /// Returns false while Accessibility is not granted.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            guard event.getIntegerValueField(.keyboardEventKeycode) == Self.fnKeyCode else {
                return Unmanaged.passUnretained(event)
            }
            let down = event.flags.contains(.maskSecondaryFn)
            guard down != fnDown else { return nil }
            fnDown = down
            down ? onDown() : onUp()
            return nil
        case .keyDown:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.escapeKeyCode, onEscape() { return nil }
            if fnDown { onChord() }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

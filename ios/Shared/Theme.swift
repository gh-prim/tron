import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// Tron design system tokens (tokens.json v4). Every color follows the system light or dark setting.

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}
#else
extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
        })
    }
}
#endif

enum TronColor {
    static let paper = Color(light: 0xF6F4EF, dark: 0x121311)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1B1C1A)
    static let line = Color(light: 0xE2DED5, dark: 0x2E302C)
    static let lineStrong = Color(light: 0x8C8E86, dark: 0x6B6D66)
    static let ink = Color(light: 0x16171A, dark: 0xEDEBE5)
    static let muted = Color(light: 0x5E6066, dark: 0xA3A49E)
    static let brand = Color(light: 0x1F4D3F, dark: 0x7FC4A8)
    static let onBrand = Color(light: 0xFFFFFF, dark: 0x0E1F18)
    static let brandTint = Color(light: 0xDCEBE3, dark: 0x1E3A30)
    static let live = Color(light: 0xC2410C, dark: 0xFB8A4E)
    static let onLive = Color(light: 0xFFFFFF, dark: 0x1A0C05)
    static let danger = Color(light: 0x9F1239, dark: 0xFB7185)
    static let onDanger = Color(light: 0xFFFFFF, dark: 0x2A0A12)
    static let dangerTint = Color(light: 0xFBE4EA, dark: 0x3A1420)
    static let warning = Color(light: 0x8A5A00, dark: 0xF5C451)
    static let warningTint = Color(light: 0xF8ECD0, dark: 0x3A2C0C)
}

/// Instrument Sans and JetBrains Mono, bundled as static weights (Shared/Fonts, SIL Open Font License).
enum TronFont {
    enum Weight: String { case regular = "Regular", medium = "Medium", semibold = "SemiBold" }

    private static func sans(_ weight: String, _ size: CGFloat, _ style: Font.TextStyle) -> Font {
        .custom("InstrumentSans-\(weight)", size: size, relativeTo: style)
    }

    /// Instrument Sans at any size, scaling with Dynamic Type like body text.
    static func sans(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
        .custom("InstrumentSans-\(weight.rawValue)", size: size, relativeTo: .body)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Regular", size: size, relativeTo: .caption)
    }

    static let display = sans("SemiBold", 40, .largeTitle)
    static let large = sans("SemiBold", 30, .largeTitle)
    static let title = sans("SemiBold", 22, .title2)
    /// Onboarding step titles (28/34).
    static let stepTitle = sans("SemiBold", 28, .title)
    static let heading = sans("SemiBold", 17, .headline)
    static let body = sans("Regular", 15, .body)
    static let bodyStrong = sans("SemiBold", 15, .body)
    static let bodyMedium = sans("Medium", 15, .body)
    static let live = sans("Regular", 17, .body)
    static let field = sans("Regular", 17, .body)
    static let label = sans("Medium", 13, .subheadline)
    static let caption = sans("Regular", 12, .caption)
    static let small = sans("Regular", 13, .footnote)
    static let transcript = Font.custom("JetBrainsMono-Regular", size: 14, relativeTo: .body)
    static let meta = Font.custom("JetBrainsMono-Regular", size: 12, relativeTo: .caption)
}

enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 16
}

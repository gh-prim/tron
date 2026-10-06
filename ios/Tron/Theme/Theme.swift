import SwiftUI
import UIKit

// Tron design system tokens (tokens.json v4). Every color follows the system light or dark setting.

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

/// Instrument Sans and JetBrains Mono fall back to the system faces until the font files are bundled.
enum TronFont {
    static let display = Font.custom("Instrument Sans", size: 40, relativeTo: .largeTitle).weight(.semibold)
    static let large = Font.custom("Instrument Sans", size: 30, relativeTo: .largeTitle).weight(.semibold)
    static let title = Font.custom("Instrument Sans", size: 22, relativeTo: .title2).weight(.semibold)
    static let heading = Font.custom("Instrument Sans", size: 17, relativeTo: .headline).weight(.semibold)
    static let body = Font.custom("Instrument Sans", size: 15, relativeTo: .body)
    static let bodyStrong = Font.custom("Instrument Sans", size: 15, relativeTo: .body).weight(.semibold)
    static let live = Font.custom("Instrument Sans", size: 17, relativeTo: .body)
    static let label = Font.custom("Instrument Sans", size: 13, relativeTo: .subheadline).weight(.medium)
    static let caption = Font.custom("Instrument Sans", size: 12, relativeTo: .caption)
    static let transcript = Font.system(size: 14, design: .monospaced)
    static let meta = Font.system(size: 12, design: .monospaced)
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

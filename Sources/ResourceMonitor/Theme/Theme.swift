import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    // Surfaces
    static let windowBackground = Color(hex: 0x0B0E14)
    static let cardBackground = Color(hex: 0x141922)
    static let cardBorder = Color(hex: 0x1F2633)
    static let gridline = Color(hex: 0x1F2633)

    // Text
    static let textPrimary = Color(hex: 0xE6EAF2)
    static let textSecondary = Color(hex: 0x8A93A6)

    // Resource accents
    static let cpu = Color(hex: 0x4C9AFF)
    static let memory = Color(hex: 0xB07CFF)
    static let disk = Color(hex: 0x3DDC97)
    static let networkDown = Color(hex: 0xFFB547)
    static let networkUp = Color(hex: 0xFF7A59)
    static let gpu = Color(hex: 0x2ED3E6)
    static let sensors = Color(hex: 0xFF5C7A)
    static let battery = Color(hex: 0x9BE15D)

    // Status
    static let green = Color(hex: 0x3DDC97)
    static let yellow = Color(hex: 0xFFC94D)
    static let red = Color(hex: 0xFF5C5C)

    // Metrics
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16

    static let bigNumber = Font.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit()
}

/// Rounded dark card used by all detail sections.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

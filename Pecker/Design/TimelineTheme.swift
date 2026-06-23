import SwiftUI

enum TimelineAccent: String, Equatable {
    case now
    case next
    case pinned
    case neutral
}

enum TimelineTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.018, green: 0.038, blue: 0.092),
            Color(red: 0.034, green: 0.065, blue: 0.145),
            Color(red: 0.018, green: 0.02, blue: 0.045)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGlow = LinearGradient(
        colors: [
            Color.white.opacity(0.14),
            Color.white.opacity(0.02),
            Color.clear
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    static let cardCornerRadius: CGFloat = 28
    static let cardStroke = Color.white.opacity(0.11)
    static let cardShadow = Color.black.opacity(0.34)
    static let cardFallbackFill = Color(red: 0.08, green: 0.11, blue: 0.18)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary = Color.white.opacity(0.55)

    static let now = Color(red: 0.52, green: 0.9, blue: 0.34)
    static let next = Color(red: 0.34, green: 0.67, blue: 1.0)
    static let pinned = Color(red: 1.0, green: 0.62, blue: 0.16)
    static let neutral = Color.white.opacity(0.78)

    static func color(for accent: TimelineAccent) -> Color {
        switch accent {
        case .now:
            now
        case .next:
            next
        case .pinned:
            pinned
        case .neutral:
            neutral
        }
    }

    static func iconBackground(for accent: TimelineAccent) -> Color {
        color(for: accent).opacity(0.18)
    }

    static func lineColor(for accent: TimelineAccent) -> Color {
        color(for: accent).opacity(0.9)
    }
}

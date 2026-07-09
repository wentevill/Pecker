import SwiftUI

enum TimelineAccent: String, Equatable {
    case now
    case next
    case pinned
    case neutral
}

struct TimelineRGB: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
}

enum TimelineTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.965, green: 0.925, blue: 0.875),
            Color(red: 0.992, green: 0.968, blue: 0.925),
            Color(red: 0.94, green: 0.885, blue: 0.82)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let headerGlow = LinearGradient(
        colors: [
            Color.white.opacity(0.72),
            Color(red: 1.0, green: 0.46, blue: 0.39).opacity(0.08),
            Color.clear
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    static let cardCornerRadius: CGFloat = 30
    static let cardStroke = Color(red: 0.23, green: 0.18, blue: 0.14).opacity(0.08)
    static let cardShadow = Color(red: 0.34, green: 0.22, blue: 0.14).opacity(0.12)
    static let cardFallbackFill = Color(red: 1.0, green: 0.985, blue: 0.955)
    static let cardWarmFill = Color(red: 1.0, green: 0.985, blue: 0.955).opacity(0.86)
    static let controlFill = Color.white.opacity(0.62)

    static let textPrimary = Color(red: 0.105, green: 0.075, blue: 0.055)
    static let textSecondary = Color(red: 0.105, green: 0.075, blue: 0.055).opacity(0.66)
    static let textTertiaryRGB = TimelineRGB(
        red: 0.36,
        green: 0.31,
        blue: 0.27
    )
    static let nowTextRGB = TimelineRGB(
        red: 0.68,
        green: 0.13,
        blue: 0.10
    )
    static let pinnedTextRGB = TimelineRGB(
        red: 0.56,
        green: 0.30,
        blue: 0.04
    )
    static let textTertiary = Color(
        red: textTertiaryRGB.red,
        green: textTertiaryRGB.green,
        blue: textTertiaryRGB.blue
    )
    static let nowText = Color(
        red: nowTextRGB.red,
        green: nowTextRGB.green,
        blue: nowTextRGB.blue
    )
    static let pinnedText = Color(
        red: pinnedTextRGB.red,
        green: pinnedTextRGB.green,
        blue: pinnedTextRGB.blue
    )
    static let nextText = Color(red: 0.12, green: 0.32, blue: 0.52)

    static let now = Color(red: 1.0, green: 0.38, blue: 0.34)
    static let next = Color(red: 0.21, green: 0.47, blue: 0.72)
    static let pinned = Color(red: 0.86, green: 0.53, blue: 0.16)
    static let neutral = Color(red: 0.105, green: 0.075, blue: 0.055).opacity(0.74)

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

    static func textColor(for accent: TimelineAccent) -> Color {
        switch accent {
        case .now:
            nowText
        case .next:
            nextText
        case .pinned:
            pinnedText
        case .neutral:
            textPrimary
        }
    }

    static func iconBackground(for accent: TimelineAccent) -> Color {
        color(for: accent).opacity(0.12)
    }

    static func lineColor(for accent: TimelineAccent) -> Color {
        color(for: accent).opacity(0.74)
    }
}

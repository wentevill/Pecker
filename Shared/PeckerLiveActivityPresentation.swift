import Foundation
import SwiftUI

enum PeckerLiveActivityStatus: CaseIterable, Equatable {
    case now
    case next
    case pinned
}

struct PeckerLiveActivityColorSpec: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    static let peckerCoral = PeckerLiveActivityColorSpec(red: 1.0, green: 0.38, blue: 0.34)
    static let peckerWarmOrange = PeckerLiveActivityColorSpec(red: 0.96, green: 0.58, blue: 0.28)
    static let peckerAmber = PeckerLiveActivityColorSpec(red: 0.92, green: 0.66, blue: 0.28)
}

enum PeckerLiveActivityPalette {
    static let darkTop = PeckerLiveActivityColorSpec(red: 0.13, green: 0.09, blue: 0.06)
    static let darkMiddle = PeckerLiveActivityColorSpec(red: 0.18, green: 0.11, blue: 0.075)
    static let darkBottom = PeckerLiveActivityColorSpec(red: 0.075, green: 0.052, blue: 0.04)
    static let textPrimary = PeckerLiveActivityColorSpec(red: 1.0, green: 0.955, blue: 0.88)
    static let textSecondary = PeckerLiveActivityColorSpec(red: 1.0, green: 0.955, blue: 0.88, opacity: 0.68)
    static let hairline = PeckerLiveActivityColorSpec(red: 1.0, green: 0.74, blue: 0.54, opacity: 0.16)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                darkTop.color,
                darkMiddle.color,
                darkBottom.color
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func accentSpec(for status: PeckerLiveActivityStatus) -> PeckerLiveActivityColorSpec {
        switch status {
        case .now:
            .peckerCoral
        case .next:
            .peckerWarmOrange
        case .pinned:
            .peckerAmber
        }
    }

    static func accentColor(for status: PeckerLiveActivityStatus) -> Color {
        accentSpec(for: status).color
    }
}

enum PeckerLiveActivityCopy {
    static func statusLabel(
        for status: PeckerLiveActivityStatus,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        switch (status, usesChinese(locale)) {
        case (.now, true):
            "现在"
        case (.next, true):
            "下一项"
        case (.pinned, true):
            "固定"
        case (.now, false):
            "Now"
        case (.next, false):
            "Next"
        case (.pinned, false):
            "Pinned"
        }
    }

    static func additionalActiveText(
        count: Int,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if usesChinese(locale) {
            return "另有 \(count) 项进行中"
        }

        return count == 1 ? "1 more active" : "\(count) more active"
    }

    static func countdownHint(
        isRunning: Bool,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        if usesChinese(locale) {
            return isRunning ? "剩余" : "开始"
        }

        return isRunning ? "left" : "starts"
    }

    static func progressAccessibilityLabel(
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        usesChinese(locale) ? "进度" : "Progress"
    }

    private static func usesChinese(_ locale: Locale) -> Bool {
        let languageCode = locale.language.languageCode?.identifier
        return languageCode == "zh"
    }
}

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

    static let peckerGreen = PeckerLiveActivityColorSpec(red: 0.36, green: 0.88, blue: 0.47)
    static let peckerBlue = PeckerLiveActivityColorSpec(red: 0.35, green: 0.68, blue: 1.0)
    static let peckerOrange = PeckerLiveActivityColorSpec(red: 1.0, green: 0.60, blue: 0.18)
}

enum PeckerLiveActivityPalette {
    static let darkTop = PeckerLiveActivityColorSpec(red: 0.03, green: 0.09, blue: 0.16)
    static let darkMiddle = PeckerLiveActivityColorSpec(red: 0.06, green: 0.12, blue: 0.20)
    static let darkBottom = PeckerLiveActivityColorSpec(red: 0.025, green: 0.055, blue: 0.10)
    static let textPrimary = PeckerLiveActivityColorSpec(red: 0.94, green: 0.97, blue: 1.0)
    static let textSecondary = PeckerLiveActivityColorSpec(red: 0.72, green: 0.78, blue: 0.86)
    static let hairline = PeckerLiveActivityColorSpec(red: 0.48, green: 0.72, blue: 1.0, opacity: 0.18)

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
            .peckerGreen
        case .next:
            .peckerBlue
        case .pinned:
            .peckerOrange
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

    static func endedLabel(
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        usesChinese(locale) ? "已结束" : "Ended"
    }

    private static func usesChinese(_ locale: Locale) -> Bool {
        let languageCode = locale.language.languageCode?.identifier
        return languageCode == "zh"
    }
}

enum PeckerLiveActivityStyle {
    static func symbolName(kindRawValue: String) -> String {
        switch kindRawValue {
        case "meeting":
            "person.2.fill"
        case "task":
            "checklist"
        case "flight":
            "airplane"
        case "train":
            "train.side.front.car"
        case "travel":
            "suitcase.fill"
        case "interview":
            "person.text.rectangle"
        case "deadline":
            "calendar.badge.exclamationmark"
        default:
            "clock.fill"
        }
    }

    static func status(for rawValue: String) -> PeckerLiveActivityStatus {
        switch rawValue {
        case "next":
            .next
        case "pinned":
            .pinned
        default:
            .now
        }
    }

    static func progress(
        startDate: Date?,
        endDate: Date?,
        at date: Date
    ) -> Double? {
        guard let startDate, let endDate, endDate > startDate else {
            return nil
        }
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = date.timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }
}

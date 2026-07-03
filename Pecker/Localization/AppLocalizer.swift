import Foundation
import PeckerCore

struct AppLocalizer: Sendable {
    let language: AppLanguage

    init(language: AppLanguage) {
        self.language = language
    }

    var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func string(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    func joinedList(_ values: [String]) -> String {
        guard let first = values.first else {
            return ""
        }
        guard values.count > 1 else {
            return first
        }
        return values.dropFirst().reduce(first) { partial, value in
            string("list.join", partial, value)
        }
    }

    func durationText(for interval: TimeInterval) -> String {
        if interval < 60 {
            return string("duration.lessThanMinute")
        }

        let totalMinutes = Int((interval / 60).rounded(.down))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case let (hours, 0) where hours > 0:
            return string("duration.hours", hours)
        case let (0, minutes):
            return string("duration.minutes", minutes)
        case let (hours, minutes):
            return string("duration.hoursMinutes", hours, minutes)
        }
    }

    private var bundle: Bundle {
        guard
            let path = Bundle.main.path(
                forResource: language.resourceIdentifier,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}

extension AppLanguage {
    var resourceIdentifier: String {
        switch self {
        case .system:
            Locale.preferredLanguages.first?.hasPrefix("zh") == true
                ? "zh-Hans"
                : "en"
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system:
            Locale.preferredLanguages.first ?? "en"
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }
}

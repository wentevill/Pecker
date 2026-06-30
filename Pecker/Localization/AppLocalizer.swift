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

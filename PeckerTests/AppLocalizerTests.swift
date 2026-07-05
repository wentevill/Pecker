import XCTest
@testable import Pecker
@testable import PeckerCore

final class AppLocalizerTests: XCTestCase {
    func testEnglishLookup() {
        let localizer = AppLocalizer(language: .english)

        XCTAssertEqual(localizer.string("settings.title"), "Settings")
        XCTAssertEqual(localizer.string("language.english"), "English")
    }

    func testSimplifiedChineseLookup() {
        let localizer = AppLocalizer(language: .simplifiedChinese)

        XCTAssertNotEqual(localizer.string("settings.title"), "settings.title")
        XCTAssertNotEqual(
            localizer.string("language.simplifiedChinese"),
            "language.simplifiedChinese"
        )
    }

    func testPermissionRecoveryStringsExistInBothLanguages() {
        let keys = [
            "settings.permission.allow",
            "settings.permission.openSettings",
            "settings.permission.calendar.error",
            "settings.permission.reminders.error"
        ]

        for language in [AppLanguage.english, .simplifiedChinese] {
            let localizer = AppLocalizer(language: language)
            for key in keys {
                XCTAssertNotEqual(
                    localizer.string(key),
                    key,
                    "Missing \(key) for \(language)"
                )
            }
        }
    }
}

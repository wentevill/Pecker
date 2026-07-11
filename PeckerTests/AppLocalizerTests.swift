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

    func testRecognitionImageFailureCopyExistsInBothLanguages() {
        let keys = [
            "recognition.image.decodeFailed",
            "recognition.image.encodeFailed",
            "recognition.image.tooLarge"
        ]

        for language in [AppLanguage.english, .simplifiedChinese] {
            let localizer = AppLocalizer(language: language)
            for key in keys {
                XCTAssertNotEqual(localizer.string(key), key)
            }
        }
    }

    func testTimelineRangeExplanationIsLocalized() {
        XCTAssertEqual(
            AppLocalizer(language: .english)
                .string("timeline.range.explanation"),
            "History and future events are loaded up to one year from today."
        )
        XCTAssertEqual(
            AppLocalizer(language: .simplifiedChinese)
                .string("timeline.range.explanation"),
            "\u{5386}\u{53f2}\u{548c}\u{672a}\u{6765}\u{65e5}\u{7a0b}\u{6700}\u{591a}\u{52a0}\u{8f7d}\u{4eca}\u{5929}\u{524d}\u{540e}\u{4e00}\u{5e74}\u{3002}"
        )
    }
}

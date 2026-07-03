import XCTest
@testable import Pecker

final class LiveActivityPresentationTests: XCTestCase {
    func testLiveActivityCopySupportsChineseAndEnglishLocales() {
        let zh = Locale(identifier: "zh_Hans_CN")
        let en = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .now, locale: zh), "\u{73b0}\u{5728}")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .next, locale: zh), "\u{4e0b}\u{4e00}\u{9879}")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .pinned, locale: zh), "\u{56fa}\u{5b9a}")
        XCTAssertEqual(PeckerLiveActivityCopy.additionalActiveText(count: 2, locale: zh), "\u{53e6}\u{6709} 2 \u{9879}\u{8fdb}\u{884c}\u{4e2d}")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: true, locale: zh), "\u{5269}\u{4f59}")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: false, locale: zh), "\u{5f00}\u{59cb}")
        XCTAssertEqual(PeckerLiveActivityCopy.progressAccessibilityLabel(locale: zh), "\u{8fdb}\u{5ea6}")
        XCTAssertEqual(PeckerLiveActivityCopy.endedLabel(locale: zh), "\u{5df2}\u{7ed3}\u{675f}")

        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .now, locale: en), "Now")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .next, locale: en), "Next")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .pinned, locale: en), "Pinned")
        XCTAssertEqual(PeckerLiveActivityCopy.additionalActiveText(count: 2, locale: en), "2 more active")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: true, locale: en), "left")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: false, locale: en), "starts")
        XCTAssertEqual(PeckerLiveActivityCopy.progressAccessibilityLabel(locale: en), "Progress")
        XCTAssertEqual(PeckerLiveActivityCopy.endedLabel(locale: en), "Ended")
    }

    func testLiveActivityPaletteUsesApprovedSemanticColors() {
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .now), .peckerGreen)
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .next), .peckerBlue)
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .pinned), .peckerOrange)

        XCTAssertGreaterThan(PeckerLiveActivityColorSpec.peckerGreen.green, 0.7)
        XCTAssertGreaterThan(PeckerLiveActivityColorSpec.peckerBlue.blue, 0.7)
        XCTAssertGreaterThan(PeckerLiveActivityColorSpec.peckerOrange.red, 0.8)
        XCTAssertGreaterThan(PeckerLiveActivityPalette.darkTop.blue, PeckerLiveActivityPalette.darkTop.red)
    }

    func testLiveActivityTimeFormattingUsesHumanReadableClockOnly() {
        let date = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 24,
            hour: 10,
            minute: 30
        ).date!
        let rendered = PeckerLiveActivityCopy.timeString(
            date,
            locale: Locale(identifier: "en_US_POSIX")
        )

        XCTAssertTrue(rendered.contains("30"))
        XCTAssertFalse(rendered.contains("2026"))
        XCTAssertFalse(rendered.contains("T"))
        XCTAssertFalse(rendered.contains("+0000"))
    }

    func testStyleMapsEveryKindAndFallsBackForUnknownRawValue() {
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "meeting"), "person.2.fill")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "task"), "checklist")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "flight"), "airplane")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "train"), "train.side.front.car")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "travel"), "suitcase.fill")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "interview"), "person.text.rectangle")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "deadline"), "calendar.badge.exclamationmark")
        XCTAssertEqual(PeckerLiveActivityStyle.symbolName(kindRawValue: "bogus"), "clock.fill")
    }

    func testEndedStateStopsCountdownAtBoundary() {
        let end = Date(timeIntervalSinceReferenceDate: 1_000)
        let state = PeckerActivityAttributes.ContentState(
            itemIdentifier: "item",
            title: "Meeting",
            secondaryIdentity: nil,
            kindRawValue: "meeting",
            symbolName: "person.2.fill",
            statusRawValue: "now",
            startDate: end.addingTimeInterval(-600),
            endDate: end,
            leadingEndpoint: nil,
            trailingEndpoint: nil,
            location: nil,
            supportingDetail: nil,
            metadata: [],
            generatedAt: end.addingTimeInterval(-600)
        )

        XCTAssertTrue(state.hasEnded(at: end))
        XCTAssertNil(state.countdownTargetDate(at: end))
    }

    func testContentStateDecodesLegacySinglePrimaryPayload() throws {
        let data = Data(
            """
            {
              "primaryTitle": "Old meeting",
              "primarySubtitle": "Room 42",
              "primaryStartDate": 1000,
              "primaryEndDate": 1600,
              "primaryKindRawValue": "meeting",
              "primarySourceIdentifier": "calendar:old",
              "additionalActiveCount": 0,
              "generatedAt": 1000,
              "primaryStatusRawValue": "now"
            }
            """.utf8
        )

        let state = try JSONDecoder().decode(
            PeckerActivityAttributes.ContentState.self,
            from: data
        )

        XCTAssertEqual(state.itemIdentifier, "calendar:old")
        XCTAssertEqual(state.title, "Old meeting")
        XCTAssertEqual(state.location, "Room 42")
        XCTAssertEqual(state.symbolName, "person.2.fill")
        XCTAssertNil(state.localeIdentifier)
    }
}

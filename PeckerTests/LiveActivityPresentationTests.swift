import XCTest
@testable import Pecker

final class LiveActivityPresentationTests: XCTestCase {
    func testLiveActivityCopySupportsChineseAndEnglishLocales() {
        let zh = Locale(identifier: "zh_Hans_CN")
        let en = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .now, locale: zh), "现在")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .next, locale: zh), "下一项")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .pinned, locale: zh), "固定")
        XCTAssertEqual(PeckerLiveActivityCopy.additionalActiveText(count: 2, locale: zh), "另有 2 项进行中")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: true, locale: zh), "剩余")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: false, locale: zh), "开始")
        XCTAssertEqual(PeckerLiveActivityCopy.progressAccessibilityLabel(locale: zh), "进度")
        XCTAssertEqual(PeckerLiveActivityCopy.endedLabel(locale: zh), "已结束")

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
    }
}

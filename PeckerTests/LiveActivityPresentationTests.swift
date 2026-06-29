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

        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .now, locale: en), "Now")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .next, locale: en), "Next")
        XCTAssertEqual(PeckerLiveActivityCopy.statusLabel(for: .pinned, locale: en), "Pinned")
        XCTAssertEqual(PeckerLiveActivityCopy.additionalActiveText(count: 2, locale: en), "2 more active")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: true, locale: en), "left")
        XCTAssertEqual(PeckerLiveActivityCopy.countdownHint(isRunning: false, locale: en), "starts")
        XCTAssertEqual(PeckerLiveActivityCopy.progressAccessibilityLabel(locale: en), "Progress")
    }

    func testLiveActivityPaletteUsesWarmDarkPeckerColors() {
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .now), .peckerCoral)
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .next), .peckerWarmOrange)
        XCTAssertEqual(PeckerLiveActivityPalette.accentSpec(for: .pinned), .peckerAmber)

        for accent in PeckerLiveActivityStatus.allCases {
            let color = PeckerLiveActivityPalette.accentSpec(for: accent)
            XCTAssertGreaterThanOrEqual(color.red, color.blue)
            XCTAssertGreaterThan(color.red, 0.7)
        }

        XCTAssertLessThan(PeckerLiveActivityPalette.darkTop.red, 0.16)
        XCTAssertGreaterThan(PeckerLiveActivityPalette.darkTop.red, PeckerLiveActivityPalette.darkTop.blue)
        XCTAssertGreaterThan(PeckerLiveActivityPalette.darkBottom.red, PeckerLiveActivityPalette.darkBottom.blue)
    }
}

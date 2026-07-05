import XCTest
@testable import Pecker

final class TimelineThemeContrastTests: XCTestCase {
    func testSemanticTextColorsMeetNormalTextContrast() {
        let card = TimelineRGB(red: 1.0, green: 0.985, blue: 0.955)
        let page = TimelineRGB(red: 0.965, green: 0.925, blue: 0.875)

        for color in [
            TimelineTheme.textTertiaryRGB,
            TimelineTheme.nowTextRGB,
            TimelineTheme.pinnedTextRGB
        ] {
            XCTAssertGreaterThanOrEqual(contrast(color, card), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(color, page), 4.5)
        }
    }

    private func contrast(
        _ left: TimelineRGB,
        _ right: TimelineRGB
    ) -> Double {
        let lighter = max(luminance(left), luminance(right))
        let darker = min(luminance(left), luminance(right))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: TimelineRGB) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.red)
            + 0.7152 * channel(color.green)
            + 0.0722 * channel(color.blue)
    }
}

import XCTest
@testable import NowTimeline
@testable import NowTimelineCore

final class ItemDetailActionTests: XCTestCase {
    func testPrimaryButtonTitleReflectsPinnedState() {
        let item = makeItem()
        let pinnedSettings = TimelineSettings(
            manualPinnedSourceIdentifier: item.sourceIdentifier
        )

        XCTAssertEqual(
            ItemDetailAction.primaryButtonTitle(
                for: item,
                settings: .init()
            ),
            "固定行程"
        )
        XCTAssertEqual(
            ItemDetailAction.primaryButtonTitle(
                for: item,
                settings: pinnedSettings
            ),
            "取消固定"
        )
    }

    func testTogglingPinSetsAndClearsManualPinWithoutMutatingSourceItem() {
        let item = makeItem()
        let originalItem = item
        let settings = TimelineSettings()

        let pinned = ItemDetailAction.updatedSettings(
            byTogglingPinFor: item,
            settings: settings
        )
        let unpinned = ItemDetailAction.updatedSettings(
            byTogglingPinFor: item,
            settings: pinned
        )

        XCTAssertEqual(pinned.manualPinnedSourceIdentifier, item.sourceIdentifier)
        XCTAssertNil(unpinned.manualPinnedSourceIdentifier)
        XCTAssertEqual(item, originalItem)
    }

    private func makeItem() -> TimelineItem {
        TimelineItem(
            id: "calendar:event-1",
            sourceIdentifier: "event-1",
            title: "Daily Standup",
            startDate: Date(timeIntervalSince1970: 100),
            endDate: Date(timeIntervalSince1970: 200),
            isAllDay: false,
            source: .calendar,
            kind: .meeting,
            location: "Conference Room",
            notes: "Bring notes"
        )
    }
}

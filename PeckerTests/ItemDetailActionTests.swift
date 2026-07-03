import XCTest
@testable import Pecker
@testable import PeckerCore

final class ItemDetailActionTests: XCTestCase {
    @MainActor
    func testNavigationTitleUsesStableShortCopy() {
        XCTAssertEqual(ItemDetailView.navigationTitle, "\u{8be6}\u{60c5}")
    }

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
            "\u{56fa}\u{5b9a}\u{884c}\u{7a0b}"
        )
        XCTAssertEqual(
            ItemDetailAction.primaryButtonTitle(
                for: item,
                settings: pinnedSettings
            ),
            "\u{53d6}\u{6d88}\u{56fa}\u{5b9a}"
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

    func testVisibleCustomFieldsDropsBlankRowsWithoutReordering() {
        let fields = [
            EventCustomField(id: "one", name: "Booking", value: "K8X2"),
            EventCustomField(id: "blank", name: " ", value: " "),
            EventCustomField(id: "two", name: "Seat", value: "18A")
        ]

        XCTAssertEqual(
            ItemDetailAction.visibleCustomFields(fields),
            [fields[0], fields[2]]
        )
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

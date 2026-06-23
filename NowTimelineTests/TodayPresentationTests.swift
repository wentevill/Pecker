import Foundation
import NowTimelineCore
import XCTest
@testable import NowTimeline

final class TodayPresentationTests: XCTestCase {
    func testSnapshotResolvesNowNextAndPinnedItemsSafely() throws {
        let items = [
            makeItem(id: "now"),
            makeItem(id: "next"),
            makeItem(id: "pinned")
        ]
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_000),
            staleAfter: Date(timeIntervalSince1970: 2_000),
            items: items,
            nowItemID: "now",
            concurrentNowCount: 0,
            nextItemID: "next",
            pinnedItemID: "pinned",
            pinOrigin: .automatic
        )

        XCTAssertEqual(snapshot.resolvedNowItem?.id, "now")
        XCTAssertEqual(snapshot.resolvedNextItem?.id, "next")
        XCTAssertEqual(snapshot.resolvedPinnedItem?.id, "pinned")
        XCTAssertNil(snapshot.item(resolving: "missing"))
    }

    func testProgressClampsAndReturnsNilForInvalidIntervals() {
        let now = Date(timeIntervalSince1970: 1_000)
        let start = now.addingTimeInterval(-50)
        let end = now.addingTimeInterval(50)

        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: now
                )
            ),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: start.addingTimeInterval(-10)
                )
            ),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: end.addingTimeInterval(10)
                )
            ),
            1,
            accuracy: 0.0001
        )
        XCTAssertNil(
            TodayPresentation.progress(start: nil, end: end, now: now)
        )
        XCTAssertNil(
            TodayPresentation.progress(start: start, end: nil, now: now)
        )
        XCTAssertNil(
            TodayPresentation.progress(
                start: end,
                end: start,
                now: now
            )
        )
    }

    func testConcurrentTextIsShownOnlyForAdditionalActiveItems() {
        XCTAssertNil(TodayPresentation.concurrentText(extraCount: 0))
        XCTAssertEqual(
            TodayPresentation.concurrentText(extraCount: 2),
            "另有 2 项进行中"
        )
    }

    func testPinBadgeCopyMatchesOrigin() {
        XCTAssertEqual(TodayPresentation.pinBadgeText(for: .automatic), "自动推荐")
        XCTAssertEqual(TodayPresentation.pinBadgeText(for: .manual), "手动固定")
        XCTAssertNil(TodayPresentation.pinBadgeText(for: nil))
    }

    func testSummaryCountIgnoresTheVisibleNowItem() {
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_000),
            staleAfter: Date(timeIntervalSince1970: 2_000),
            items: [
                makeItem(id: "now"),
                makeItem(id: "next"),
                makeItem(id: "pinned")
            ],
            nowItemID: "now",
            concurrentNowCount: 1,
            nextItemID: "next",
            pinnedItemID: "pinned",
            pinOrigin: .manual
        )

        XCTAssertEqual(TodayPresentation.summaryCount(for: snapshot), 2)
    }

    func testStateCopyIsStable() {
        XCTAssertEqual(TodayStateCopy.loadingTitle, "加载中")
        XCTAssertEqual(TodayStateCopy.emptyTitle, "今天暂时空闲")
        XCTAssertEqual(TodayStateCopy.permissionTitle, "需要访问日历与提醒事项")
        XCTAssertEqual(TodayStateCopy.staleBanner, "数据可能已过时")
        XCTAssertEqual(TodayStateCopy.failureTitle, "今天暂时不可用")
    }

    private func makeItem(id: String) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: id.capitalized,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_100),
            isAllDay: false,
            source: .calendar,
            kind: .meeting,
            location: "Room 1",
            notes: nil
        )
    }
}

import Foundation
import Testing
@testable import NowTimelineCore

@Test func snapshotRoundTrips() throws {
    let item = TimelineItem(
        id: "calendar:event-1",
        sourceIdentifier: "event-1",
        title: "Daily Standup",
        startDate: Date(timeIntervalSince1970: 100),
        endDate: Date(timeIntervalSince1970: 200),
        isAllDay: false,
        source: .calendar,
        kind: .meeting,
        location: nil,
        notes: nil
    )
    let value = TodaySnapshot(
        schemaVersion: 1,
        generatedAt: .init(timeIntervalSince1970: 50),
        staleAfter: .init(timeIntervalSince1970: 300),
        items: [item],
        nowItemID: item.id,
        concurrentNowCount: 0,
        nextItemID: nil,
        pinnedItemID: nil,
        pinOrigin: nil
    )

    let decoded = try JSONDecoder().decode(
        TodaySnapshot.self,
        from: JSONEncoder().encode(value)
    )
    #expect(decoded == value)
}

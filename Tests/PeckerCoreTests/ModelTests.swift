import Foundation
import Testing
@testable import PeckerCore

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

@Test func templatedTimelineItemRoundTrips() throws {
    let item = TimelineItem(
        id: "calendar:train-1",
        sourceIdentifier: "train-1",
        title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
        startDate: Date(timeIntervalSince1970: 100),
        endDate: Date(timeIntervalSince1970: 200),
        isAllDay: false,
        source: .calendar,
        kind: .train,
        location: "\u{68c0}\u{7968}\u{53e3} B7",
        notes: "08\u{8f66} 03A",
        template: .trainTicket(.init(
            trainNumber: "G123",
            departureStation: "\u{4e0a}\u{6d77}\u{8679}\u{6865}",
            arrivalStation: "\u{5317}\u{4eac}\u{5357}",
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: "08",
            seatNumber: "03A",
            checkInGate: "B7",
            passengerName: nil,
            ticketNumber: nil
        ))
    )

    let decoded = try JSONDecoder().decode(
        TimelineItem.self,
        from: JSONEncoder().encode(item)
    )

    #expect(decoded == item)
}

@Test func snapshotIsNotStaleImmediatelyBeforeStaleAfter() {
    let snapshot = snapshot(staleAfter: Date(timeIntervalSince1970: 300))

    #expect(!snapshot.isStale(at: Date(timeIntervalSince1970: 299.999)))
}

@Test func snapshotIsStaleExactlyAtStaleAfter() {
    let staleAfter = Date(timeIntervalSince1970: 300)
    let snapshot = snapshot(staleAfter: staleAfter)

    #expect(snapshot.isStale(at: staleAfter))
}

private func snapshot(staleAfter: Date) -> TodaySnapshot {
    TodaySnapshot(
        schemaVersion: TodaySnapshot.currentSchemaVersion,
        generatedAt: Date(timeIntervalSince1970: 50),
        staleAfter: staleAfter,
        items: [],
        nowItemID: nil,
        concurrentNowCount: 0,
        nextItemID: nil,
        pinnedItemID: nil,
        pinOrigin: nil
    )
}

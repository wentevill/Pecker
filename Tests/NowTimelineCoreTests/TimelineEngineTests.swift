import Foundation
import Testing
@testable import NowTimelineCore

@Suite struct TimelineEngineTests {
    @Test func selectsHighestPriorityNowAndCountsConflicts() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meeting = item("meeting", .meeting, 900, 1_100)
        let flight = item("flight", .flight, 950, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting, flight],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == flight.id)
        #expect(snapshot.concurrentNowCount == 1)
    }

    @Test func excludesItemAtExactEndAndSelectsEarliestNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let ended = item("ended", .meeting, 900, 1_000)
        let later = item("later", .meeting, 1_200, 1_300)
        let next = item("next", .task, 1_100, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [later, ended, next],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == nil)
        #expect(snapshot.nextItemID == next.id)
    }

    @Test func includesItemAtExactStartAsNow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let starting = item("starting", .meeting, 1_000, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [starting],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == starting.id)
        #expect(snapshot.concurrentNowCount == 0)
    }

    @Test func ranksNowKindsInApprovedOrder() {
        let now = Date(timeIntervalSince1970: 1_000)
        let rankedItems = [
            item("flight", .flight, 900, 1_100),
            item("train", .train, 900, 1_100),
            item("interview", .interview, 900, 1_100),
            item("meeting", .meeting, 900, 1_100),
            item("deadline", .deadline, 900, 1_100),
            item("task", .task, 900, 1_100),
            item("unknown", .unknown, 900, 1_100)
        ]

        for index in rankedItems.indices {
            let candidates = Array(rankedItems[index...].reversed())
            let snapshot = TimelineEngine().makeSnapshot(
                items: candidates,
                now: now,
                settings: .init(),
                staleInterval: 900
            )

            #expect(snapshot.nowItemID == rankedItems[index].id)
            #expect(snapshot.concurrentNowCount == candidates.count - 1)
        }
    }

    @Test func appliesStableNowTieBreakers() {
        let now = Date(timeIntervalSince1970: 1_000)
        let earliestEnd = item("earliest-end", .meeting, 800, 1_050)
        let laterEnd = item("later-end", .meeting, 700, 1_100)
        let endSnapshot = TimelineEngine().makeSnapshot(
            items: [laterEnd, earliestEnd],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let earliestStart = item("earliest-start", .meeting, 700, 1_100)
        let laterStart = item("later-start", .meeting, 800, 1_100)
        let startSnapshot = TimelineEngine().makeSnapshot(
            items: [laterStart, earliestStart],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let alpha = item("Alpha", .meeting, 800, 1_100)
        let beta = item("Beta", .meeting, 800, 1_100)
        let titleSnapshot = TimelineEngine().makeSnapshot(
            items: [beta, alpha],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(endSnapshot.nowItemID == earliestEnd.id)
        #expect(startSnapshot.nowItemID == earliestStart.id)
        #expect(titleSnapshot.nowItemID == alpha.id)
    }

    @Test func selectsEarliestFutureTimedItemAsNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let laterFlight = item("later-flight", .flight, 1_200, 1_300)
        let earlierUnknown = item("earlier-unknown", .unknown, 1_100, 1_150)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [laterFlight, earlierUnknown],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nextItemID == earlierUnknown.id)
    }

    @Test func excludesAllDayItemsFromNowAndNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let activeAllDay = item(
            "active-all-day",
            .meeting,
            900,
            1_100,
            isAllDay: true
        )
        let futureAllDay = item(
            "future-all-day",
            .flight,
            1_050,
            1_200,
            isAllDay: true
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [futureAllDay, activeAllDay],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.count == 2)
        #expect(snapshot.nowItemID == nil)
        #expect(snapshot.concurrentNowCount == 0)
        #expect(snapshot.nextItemID == nil)
    }

    @Test func filtersDisabledCalendarAndReminderSources() {
        let now = Date(timeIntervalSince1970: 1_000)
        let calendar = item(
            "calendar",
            .meeting,
            900,
            1_100,
            source: .calendar
        )
        let reminder = item(
            "reminder",
            .task,
            950,
            1_200,
            source: .reminder
        )

        let calendarDisabled = TimelineEngine().makeSnapshot(
            items: [calendar, reminder],
            now: now,
            settings: .init(calendarEnabled: false),
            staleInterval: 900
        )
        let remindersDisabled = TimelineEngine().makeSnapshot(
            items: [calendar, reminder],
            now: now,
            settings: .init(remindersEnabled: false),
            staleInterval: 900
        )

        #expect(calendarDisabled.items.map(\.id) == [reminder.id])
        #expect(calendarDisabled.nowItemID == reminder.id)
        #expect(remindersDisabled.items.map(\.id) == [calendar.id])
        #expect(remindersDisabled.nowItemID == calendar.id)
    }

    @Test func downgradesTravelKindsWhenTravelEventsAreHidden() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("flight", .flight, 900, 1_050)
        let train = item("train", .train, 1_100, 1_200)
        let travel = item("travel", .travel, 1_200, 1_300)
        let meeting = item("meeting", .meeting, 900, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight, train, travel, meeting],
            now: now,
            settings: .init(showTravelEvents: false),
            staleInterval: 900
        )

        #expect(snapshot.items.first { $0.id == flight.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == train.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == travel.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == meeting.id }?.kind == .meeting)
        #expect(snapshot.nowItemID == meeting.id)
        #expect(snapshot.nextItemID == train.id)
    }

    @Test func sortsItemsAndSetsSnapshotMetadata() {
        let now = Date(timeIntervalSince1970: 1_000)
        let noEnd = item("No End", .task, 1_100, nil)
        let laterEnd = item("Later End", .task, 1_100, 1_300)
        let alpha = item("Alpha", .task, 1_100, 1_200)
        let beta = item("Beta", .task, 1_100, 1_200)
        let earlier = item("Earlier", .task, 1_050, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [noEnd, beta, laterEnd, earlier, alpha],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.map(\.id) == [
            earlier.id,
            alpha.id,
            beta.id,
            laterEnd.id,
            noEnd.id
        ])
        #expect(snapshot.generatedAt == now)
        #expect(snapshot.staleAfter == Date(timeIntervalSince1970: 1_900))
        #expect(snapshot.schemaVersion == TodaySnapshot.currentSchemaVersion)
        #expect(snapshot.pinnedItemID == nil)
        #expect(snapshot.pinOrigin == nil)
    }
}

private func item(
    _ title: String,
    _ kind: TimelineKind,
    _ start: TimeInterval,
    _ end: TimeInterval?,
    isAllDay: Bool = false,
    source: TimelineSource = .calendar
) -> TimelineItem {
    TimelineItem(
        id: "\(source.rawValue):\(title)",
        sourceIdentifier: title,
        title: title,
        startDate: Date(timeIntervalSince1970: start),
        endDate: end.map(Date.init(timeIntervalSince1970:)),
        isAllDay: isAllDay,
        source: source,
        kind: kind,
        location: nil,
        notes: nil
    )
}

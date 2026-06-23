import Foundation
import XCTest
@testable import NowTimeline
@testable import NowTimelineCore

final class TimelineGroupingTests: XCTestCase {
    func testSectionsAreOrderedOverdueAllDayActiveUpcomingElapsed() {
        let now = date(1_000)
        let overdueReminder = item(
            id: "overdue-reminder",
            title: "Submit expense report",
            start: 900,
            end: 950,
            source: .reminder,
            kind: .task
        )
        let allDayEvent = item(
            id: "all-day",
            title: "Conference Day 1",
            start: 800,
            end: 1_800,
            source: .calendar,
            kind: .meeting,
            isAllDay: true
        )
        let activeEvent = item(
            id: "active",
            title: "Daily Standup",
            start: 950,
            end: 1_050,
            source: .calendar,
            kind: .meeting
        )
        let upcomingEvent = item(
            id: "upcoming",
            title: "Product Review",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )
        let elapsedEvent = item(
            id: "elapsed",
            title: "Morning Sync",
            start: 700,
            end: 900,
            source: .calendar,
            kind: .meeting
        )

        let sections = TimelineGrouping.sections(
            items: [
                upcomingEvent,
                activeEvent,
                elapsedEvent,
                overdueReminder,
                allDayEvent
            ],
            now: now
        )

        XCTAssertEqual(
            sections.map(\.kind),
            [.overdue, .allDay, .active, .upcoming, .elapsed]
        )
        XCTAssertEqual(sections[0].items.map(\.id), [overdueReminder.id])
        XCTAssertEqual(sections[1].items.map(\.id), [allDayEvent.id])
        XCTAssertEqual(sections[2].items.map(\.id), [activeEvent.id])
        XCTAssertEqual(sections[3].items.map(\.id), [upcomingEvent.id])
        XCTAssertEqual(sections[4].items.map(\.id), [elapsedEvent.id])
    }

    func testItemsWithinSectionAreSortedByTimeThenTitle() {
        let now = date(1_000)
        let alpha = item(
            id: "alpha",
            title: "Alpha",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )
        let beta = item(
            id: "beta",
            title: "Beta",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )
        let earlier = item(
            id: "earlier",
            title: "Earlier",
            start: 1_050,
            end: 1_150,
            source: .calendar,
            kind: .meeting
        )

        let sections = TimelineGrouping.sections(
            items: [beta, earlier, alpha],
            now: now
        )

        XCTAssertEqual(
            sections.first(where: { $0.kind == .upcoming })?.items.map(\.id),
            [earlier.id, alpha.id, beta.id]
        )
    }

    func testActiveOnlyFilterReturnsOnlyExactActiveItems() {
        let now = date(1_000)
        let startsNow = item(
            id: "starts-now",
            title: "Starts Now",
            start: 1_000,
            end: 1_100,
            source: .calendar,
            kind: .meeting
        )
        let endsNow = item(
            id: "ends-now",
            title: "Ends Now",
            start: 900,
            end: 1_000,
            source: .calendar,
            kind: .meeting
        )
        let future = item(
            id: "future",
            title: "Future",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )

        let sections = TimelineGrouping.sections(
            items: [future, endsNow, startsNow],
            now: now,
            activeOnly: true
        )

        XCTAssertEqual(sections.map(\.kind), [.active])
        XCTAssertEqual(sections.first?.items.map(\.id), [startsNow.id])
    }

    func testOverdueReminderDoesNotStayInActiveSectionAtExactEndBoundary() {
        let now = date(1_000)
        let reminderEndingNow = item(
            id: "reminder-ending-now",
            title: "Pay bill",
            start: 900,
            end: 1_000,
            source: .reminder,
            kind: .task
        )
        let reminderAfterNow = item(
            id: "reminder-after-now",
            title: "Send follow-up",
            start: 950,
            end: 1_050,
            source: .reminder,
            kind: .task
        )

        let sections = TimelineGrouping.sections(
            items: [reminderAfterNow, reminderEndingNow],
            now: now
        )

        XCTAssertEqual(
            sections.first(where: { $0.kind == .overdue })?.items.map(\.id),
            [reminderEndingNow.id]
        )
        XCTAssertEqual(
            sections.first(where: { $0.kind == .active })?.items.map(\.id),
            [reminderAfterNow.id]
        )
    }

    func testAllItemsAppearInExactlyOneSectionAndAllDayRemindersStayOnlyInAllDay() {
        let now = date(1_000)
        let allDayReminder = item(
            id: "all-day-reminder",
            title: "All-day reminder",
            start: 800,
            end: 900,
            source: .reminder,
            kind: .task,
            isAllDay: true
        )
        let activeEvent = item(
            id: "active-event",
            title: "Active event",
            start: 900,
            end: 1_100,
            source: .calendar,
            kind: .meeting
        )
        let upcomingEvent = item(
            id: "upcoming-event",
            title: "Upcoming event",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )
        let elapsedEvent = item(
            id: "elapsed-event",
            title: "Elapsed event",
            start: 700,
            end: 900,
            source: .calendar,
            kind: .meeting
        )
        let overdueReminder = item(
            id: "overdue-reminder",
            title: "Overdue reminder",
            start: 800,
            end: 900,
            source: .reminder,
            kind: .task
        )

        let sections = TimelineGrouping.sections(
            items: [
                allDayReminder,
                activeEvent,
                upcomingEvent,
                elapsedEvent,
                overdueReminder
            ],
            now: now
        )

        XCTAssertEqual(
            sections.first(where: { $0.kind == .allDay })?.items.map(\.id),
            [allDayReminder.id]
        )
        XCTAssertFalse(
            sections.first(where: { $0.kind == .overdue })?.items.contains(where: { $0.id == allDayReminder.id }) ?? false
        )

        let flattenedIDs = sections.flatMap(\.items).map(\.id)
        XCTAssertEqual(Set(flattenedIDs).count, flattenedIDs.count)
        XCTAssertEqual(Set(flattenedIDs), [
            allDayReminder.id,
            activeEvent.id,
            upcomingEvent.id,
            elapsedEvent.id,
            overdueReminder.id
        ])
    }

    func testNoDuplicateIDsAcrossSectionsGenerally() {
        let now = date(1_000)
        let reminderEndingNow = item(
            id: "reminder-ending-now",
            title: "Reminder ending now",
            start: 900,
            end: 1_000,
            source: .reminder,
            kind: .task
        )
        let activeEvent = item(
            id: "active-event",
            title: "Active event",
            start: 900,
            end: 1_100,
            source: .calendar,
            kind: .meeting
        )
        let upcomingEvent = item(
            id: "upcoming-event",
            title: "Upcoming event",
            start: 1_100,
            end: 1_200,
            source: .calendar,
            kind: .meeting
        )

        let sections = TimelineGrouping.sections(
            items: [upcomingEvent, activeEvent, reminderEndingNow],
            now: now
        )

        let flattenedIDs = sections.flatMap(\.items).map(\.id)
        XCTAssertEqual(Set(flattenedIDs).count, flattenedIDs.count)
    }

    private func item(
        id: String,
        title: String,
        start: TimeInterval,
        end: TimeInterval,
        source: TimelineSource,
        kind: TimelineKind,
        isAllDay: Bool = false
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: title,
            startDate: date(start),
            endDate: date(end),
            isAllDay: isAllDay,
            source: source,
            kind: kind,
            location: nil,
            notes: nil
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}

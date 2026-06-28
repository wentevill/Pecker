import Foundation
import Testing
@testable import PeckerCore

@Test func classifiesItemIntersectingTodayAsToday() {
    let item = makeScopeItem(
        start: scopeDate("2026-06-28T10:00:00Z"),
        end: scopeDate("2026-06-28T11:00:00Z")
    )

    #expect(scope(for: item) == .today)
}

@Test func classifiesCrossMidnightItemAsToday() {
    let item = makeScopeItem(
        start: scopeDate("2026-06-27T23:30:00Z"),
        end: scopeDate("2026-06-28T00:30:00Z")
    )

    #expect(scope(for: item) == .today)
}

@Test func classifiesTomorrowBoundaryAsFuture() {
    let item = makeScopeItem(
        start: scopeDate("2026-06-29T00:00:00Z"),
        end: scopeDate("2026-06-29T01:00:00Z")
    )

    #expect(scope(for: item) == .future)
}

@Test func classifiesTodayBoundaryEndAsHistory() {
    let item = makeScopeItem(
        start: scopeDate("2026-06-27T23:00:00Z"),
        end: scopeDate("2026-06-28T00:00:00Z")
    )

    #expect(scope(for: item) == .history)
}

@Test func completionDoesNotChangeHistoricalScope() {
    let item = makeScopeItem(
        start: scopeDate("2026-06-27T09:00:00Z"),
        end: nil,
        isCompleted: false
    )

    #expect(scope(for: item) == .history)
}

private func scope(for item: TimelineItem) -> TimelineDateScope {
    TimelineDateScope.classify(
        item,
        calendar: scopeCalendar(),
        now: scopeDate("2026-06-28T12:00:00Z")
    )
}

private func makeScopeItem(
    start: Date,
    end: Date?,
    isCompleted: Bool = false
) -> TimelineItem {
    TimelineItem(
        id: "scope-item",
        sourceIdentifier: "scope-item",
        title: "Scope item",
        startDate: start,
        endDate: end,
        isAllDay: false,
        source: .external,
        kind: .unknown,
        location: nil,
        notes: nil,
        isCompleted: isCompleted
    )
}

private func scopeCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func scopeDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

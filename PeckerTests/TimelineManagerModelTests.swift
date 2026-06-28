import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class TimelineManagerModelTests: XCTestCase {
    func testScopeAndKindFiltersComposeWithoutDateLeakage() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let todayTrain = item(
            id: "today-train",
            start: now,
            kind: .train
        )
        let todayMeeting = item(
            id: "today-meeting",
            start: now.addingTimeInterval(60),
            kind: .meeting
        )
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!
        let futureTrain = item(
            id: "future-train",
            start: tomorrow,
            kind: .train
        )

        let visible = TimelineManagerModel.visibleItems(
            from: [futureTrain, todayMeeting, todayTrain],
            scope: .today,
            kind: .train,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(visible.map(\.id), ["today-train"])
    }

    func testHistoryUsesReverseChronologicalOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let older = item(
            id: "older",
            start: calendar.date(byAdding: .day, value: -2, to: now)!,
            kind: .task
        )
        let newer = item(
            id: "newer",
            start: calendar.date(byAdding: .day, value: -1, to: now)!,
            kind: .task
        )

        let visible = TimelineManagerModel.visibleItems(
            from: [older, newer],
            scope: .history,
            kind: nil,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(visible.map(\.id), ["newer", "older"])
    }

    private func item(
        id: String,
        start: Date,
        kind: TimelineKind
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: id,
            startDate: start,
            endDate: start.addingTimeInterval(30),
            isAllDay: false,
            source: .external,
            kind: kind,
            location: nil,
            notes: nil
        )
    }
}

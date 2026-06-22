import Foundation
import NowTimelineCore
import XCTest
@testable import NowTimeline

final class EventKitMapperTests: XCTestCase {
    func testReminderMapsConfiguredDurationAndIdentifiers() throws {
        let dueDate = Date(timeIntervalSince1970: 1_000)

        let item = try XCTUnwrap(
            EventKitMapper().mapReminder(
                ReminderRecord(
                    identifier: "r1",
                    title: "Pay bill",
                    dueDate: dueDate,
                    notes: "Use checking"
                ),
                durationMinutes: 45
            )
        )

        XCTAssertEqual(item.id, "reminder:r1")
        XCTAssertEqual(item.sourceIdentifier, "r1")
        XCTAssertEqual(item.title, "Pay bill")
        XCTAssertEqual(item.startDate, dueDate)
        XCTAssertEqual(item.endDate, dueDate.addingTimeInterval(45 * 60))
        XCTAssertFalse(item.isAllDay)
        XCTAssertEqual(item.source, .reminder)
        XCTAssertEqual(item.kind, .unknown)
        XCTAssertNil(item.location)
        XCTAssertEqual(item.notes, "Use checking")
    }

    func testReminderWithoutDueDateIsExcluded() {
        let item = EventKitMapper().mapReminder(
            ReminderRecord(
                identifier: "r2",
                title: "Someday",
                dueDate: nil,
                notes: nil
            ),
            durationMinutes: 30
        )

        XCTAssertNil(item)
    }

    func testCalendarRecordMapsAllFieldsAndIdentifiers() {
        let startDate = Date(timeIntervalSince1970: 2_000)
        let endDate = Date(timeIntervalSince1970: 5_600)

        let item = EventKitMapper().mapEvent(
            EventRecord(
                identifier: "e1",
                title: "Airport transfer",
                startDate: startDate,
                endDate: endDate,
                isAllDay: true,
                location: "Terminal 1",
                notes: "Meet at arrivals"
            )
        )

        XCTAssertEqual(item.id, "calendar:e1")
        XCTAssertEqual(item.sourceIdentifier, "e1")
        XCTAssertEqual(item.title, "Airport transfer")
        XCTAssertEqual(item.startDate, startDate)
        XCTAssertEqual(item.endDate, endDate)
        XCTAssertTrue(item.isAllDay)
        XCTAssertEqual(item.source, .calendar)
        XCTAssertEqual(item.kind, .unknown)
        XCTAssertEqual(item.location, "Terminal 1")
        XCTAssertEqual(item.notes, "Meet at arrivals")
    }

    func testInvalidReminderDurationIsNormalizedToThirtyMinutes() throws {
        let dueDate = Date(timeIntervalSince1970: 3_000)

        let item = try XCTUnwrap(
            EventKitMapper().mapReminder(
                ReminderRecord(
                    identifier: "r3",
                    title: "Follow up",
                    dueDate: dueDate,
                    notes: nil
                ),
                durationMinutes: 0
            )
        )

        XCTAssertEqual(item.endDate, dueDate.addingTimeInterval(30 * 60))
    }
}

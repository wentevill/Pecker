import EventKit
import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class EventKitMapperTests: XCTestCase {
    private final class LockedCallback<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var callback: (@Sendable (Value) -> Void)?

        func set(_ callback: @escaping @Sendable (Value) -> Void) {
            lock.withLock {
                self.callback = callback
            }
        }

        func call(_ value: Value) {
            let callback = lock.withLock { self.callback }
            callback?(value)
        }
    }

    func testReminderMapsDueDateWithoutSyntheticDuration() throws {
        let dueDate = Date(timeIntervalSince1970: 1_000)

        let item = try XCTUnwrap(
            EventKitMapper().mapReminder(
                ReminderRecord(
                    identifier: "r1",
                    title: "Pay bill",
                    dueDate: dueDate,
                    notes: "Use checking"
                )
            )
        )

        XCTAssertEqual(item.id, "reminder:r1")
        XCTAssertEqual(item.sourceIdentifier, "r1")
        XCTAssertEqual(item.title, "Pay bill")
        XCTAssertEqual(item.startDate, dueDate)
        XCTAssertNil(item.endDate)
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
            )
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

    func testReminderDurationSettingDoesNotCreateEndDate() throws {
        let dueDate = Date(timeIntervalSince1970: 3_000)

        let item = try XCTUnwrap(
            EventKitMapper().mapReminder(
                ReminderRecord(
                    identifier: "r3",
                    title: "Follow up",
                    dueDate: dueDate,
                    notes: nil
                )
            )
        )

        XCTAssertNil(item.endDate)
    }

    func testDayIntervalUsesLocalCalendarAcrossDSTBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(
            TimeZone(identifier: "America/Los_Angeles")
        )
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 3,
                    day: 8,
                    hour: 12
                )
            )
        )

        let interval = try XCTUnwrap(
            EventKitGatewaySupport.dayInterval(calendar: calendar, now: now)
        )

        XCTAssertEqual(interval.start, calendar.startOfDay(for: now))
        XCTAssertEqual(
            interval.end,
            calendar.date(byAdding: .day, value: 1, to: interval.start)
        )
        XCTAssertEqual(interval.duration, 23 * 60 * 60)
    }

    func testReminderInclusionExcludesHistoricalReminder() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 10_000),
            duration: 24 * 60 * 60
        )
        let historical = interval.start.addingTimeInterval(-1)

        XCTAssertFalse(
            EventKitGatewaySupport.includesReminder(
                dueDate: historical,
                interval: interval
            )
        )
    }

    func testReminderInclusionExcludesExactNextDay() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 10_000),
            duration: 24 * 60 * 60
        )

        XCTAssertFalse(
            EventKitGatewaySupport.includesReminder(
                dueDate: interval.end,
                interval: interval
            )
        )
    }

    func testReminderInclusionIncludesStartOfToday() {
        let interval = DateInterval(
            start: Date(timeIntervalSince1970: 10_000),
            duration: 24 * 60 * 60
        )

        XCTAssertTrue(
            EventKitGatewaySupport.includesReminder(
                dueDate: interval.start,
                interval: interval
            )
        )
    }

    func testAuthorizationStatusMapping() {
        let cases: [(EKAuthorizationStatus, SourceAuthorizationStatus)] = [
            (.notDetermined, .notDetermined),
            (.denied, .denied),
            (.restricted, .restricted),
            (.fullAccess, .fullAccess),
            (.writeOnly, .writeOnly)
        ]

        for (eventKitStatus, expected) in cases {
            XCTAssertEqual(
                EventKitGatewaySupport.authorizationStatus(eventKitStatus),
                expected
            )
        }
    }

    func testCancellableFetchResumesCancellationAndIgnoresLateCallback() async {
        let callback = LockedCallback<[String]>()
        let fetchStarted = expectation(description: "fetch request started")
        let cancellationCalled = expectation(
            description: "fetch request cancelled"
        )

        let task = Task {
            try await EventKitGatewaySupport.cancellableFetch(
                start: { completion in
                    callback.set(completion)
                    fetchStarted.fulfill()
                    return "fetch-1"
                },
                cancel: { identifier in
                    XCTAssertEqual(identifier, "fetch-1")
                    cancellationCalled.fulfill()
                }
            )
        }

        await fulfillment(of: [fetchStarted], timeout: 1)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        callback.call(["late"])
        await fulfillment(of: [cancellationCalled], timeout: 1)
    }
}

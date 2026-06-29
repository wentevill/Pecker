import Foundation
import XCTest
@testable import Pecker

@MainActor
final class LiveActivityBoundarySchedulerTests: XCTestCase {
    func testPastBoundaryRefreshesImmediately() async {
        let sleeper = BoundarySleeper()
        let background = BoundaryBackgroundScheduler()
        let refresh = expectation(description: "refresh")
        let scheduler = LiveActivityBoundaryScheduler(
            sleeper: sleeper,
            backgroundScheduler: background,
            now: { Date(timeIntervalSinceReferenceDate: 1_000) },
            refresh: {
                refresh.fulfill()
                return nil
            }
        )

        scheduler.schedule(Date(timeIntervalSinceReferenceDate: 999))

        await fulfillment(of: [refresh], timeout: 1)
        let requestedDates = await sleeper.requestedDates()
        XCTAssertEqual(requestedDates, [])
    }

    func testReplacingBoundaryCancelsOldSleep() async {
        let sleeper = BoundarySleeper()
        let scheduler = LiveActivityBoundaryScheduler(
            sleeper: sleeper,
            backgroundScheduler: BoundaryBackgroundScheduler(),
            now: { Date(timeIntervalSinceReferenceDate: 1_000) },
            refresh: { nil }
        )
        let first = Date(timeIntervalSinceReferenceDate: 1_100)
        let second = Date(timeIntervalSinceReferenceDate: 1_200)

        scheduler.schedule(first)
        await waitForRequestCount(1, sleeper: sleeper)
        scheduler.schedule(second)
        await waitForRequestCount(2, sleeper: sleeper)
        await waitForCancellationCount(1, sleeper: sleeper)

        let requestedDates = await sleeper.requestedDates()
        let cancelledDates = await sleeper.cancelledDates()
        XCTAssertEqual(requestedDates, [first, second])
        XCTAssertEqual(cancelledDates, [first])
    }

    func testInactiveSubmitsCurrentBoundaryAndCancelClearsIt() throws {
        let background = BoundaryBackgroundScheduler()
        let scheduler = LiveActivityBoundaryScheduler(
            sleeper: BoundarySleeper(),
            backgroundScheduler: background,
            now: { Date(timeIntervalSinceReferenceDate: 1_000) },
            refresh: { nil }
        )
        let boundary = Date(timeIntervalSinceReferenceDate: 1_100)
        scheduler.schedule(boundary)

        try scheduler.becameInactive()
        scheduler.cancel()

        XCTAssertEqual(background.submittedDates, [boundary])
        XCTAssertEqual(background.cancelCount, 1)
    }

    func testRemovingBoundaryCancelsPendingBackgroundRequest() {
        let background = BoundaryBackgroundScheduler()
        let scheduler = LiveActivityBoundaryScheduler(
            sleeper: BoundarySleeper(),
            backgroundScheduler: background,
            now: { Date(timeIntervalSinceReferenceDate: 1_000) },
            refresh: { nil }
        )

        scheduler.schedule(Date(timeIntervalSinceReferenceDate: 1_100))
        scheduler.schedule(nil)

        XCTAssertEqual(background.cancelCount, 1)
        XCTAssertNil(scheduler.boundary)
    }

    func testRefreshResultSchedulesFollowingBoundary() async {
        let sleeper = BoundarySleeper()
        let following = Date(timeIntervalSinceReferenceDate: 1_100)
        let scheduler = LiveActivityBoundaryScheduler(
            sleeper: sleeper,
            backgroundScheduler: BoundaryBackgroundScheduler(),
            now: { Date(timeIntervalSinceReferenceDate: 1_000) },
            refresh: { following }
        )

        scheduler.schedule(Date(timeIntervalSinceReferenceDate: 999))
        await waitForRequestCount(1, sleeper: sleeper)

        let requestedDates = await sleeper.requestedDates()
        XCTAssertEqual(requestedDates, [following])
        XCTAssertEqual(scheduler.boundary, following)
    }

    private func waitForRequestCount(
        _ count: Int,
        sleeper: BoundarySleeper
    ) async {
        for _ in 0..<100 {
            if await sleeper.requestedDates().count >= count {
                return
            }
            await Task.yield()
        }
    }

    private func waitForCancellationCount(
        _ count: Int,
        sleeper: BoundarySleeper
    ) async {
        for _ in 0..<100 {
            if await sleeper.cancelledDates().count >= count {
                return
            }
            await Task.yield()
        }
    }
}

private actor BoundarySleeper: LiveActivitySleeping {
    private var requested: [Date] = []
    private var cancelled: [Date] = []

    func sleep(until date: Date) async throws {
        requested.append(date)
        do {
            try await Task.sleep(for: .seconds(3_600))
        } catch {
            cancelled.append(date)
            throw error
        }
    }

    func requestedDates() -> [Date] {
        requested
    }

    func cancelledDates() -> [Date] {
        cancelled
    }
}

private final class BoundaryBackgroundScheduler:
    LiveActivityBackgroundScheduling,
    @unchecked Sendable
{
    private(set) var submittedDates: [Date?] = []
    private(set) var cancelCount = 0

    func submit(earliestBeginDate: Date?) throws {
        submittedDates.append(earliestBeginDate)
    }

    func cancel() {
        cancelCount += 1
    }
}

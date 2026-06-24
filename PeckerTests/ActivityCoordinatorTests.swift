import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class ActivityCoordinatorTests: XCTestCase {
    func testDisabledSettingEndsAndAppliesDecision() async throws {
        let client = FakeActivityClient()
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let snapshot = makeSnapshot(
            now: makeItem(id: "now", title: "Standup")
        )

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: false),
            now: testNow
        )

        XCTAssertEqual(decision, .end)
        XCTAssertEqual(client.appliedOperations(), [])
    }

    func testFirstActivationStartsWithNowStateAndLocalDayAttributes() async throws {
        let client = FakeActivityClient()
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let nowItem = makeItem(
            id: "now",
            sourceIdentifier: "calendar-now",
            title: "Design Review",
            startDate: testNow.addingTimeInterval(-600),
            endDate: testNow.addingTimeInterval(1_200),
            kind: .meeting,
            location: "Room 42",
            notes: "Fallback notes"
        )
        let nextItem = makeItem(
            id: "next",
            title: "Ship Train",
            startDate: testNow.addingTimeInterval(900),
            endDate: testNow.addingTimeInterval(1_800)
        )
        let pinnedItem = makeItem(
            id: "pinned",
            title: "Pinned Task",
            startDate: testNow.addingTimeInterval(3_600),
            endDate: testNow.addingTimeInterval(7_200),
            location: nil,
            notes: "Pinned notes"
        )
        let snapshot = makeSnapshot(
            staleAfter: testNow.addingTimeInterval(3_000),
            items: [nowItem, nextItem, pinnedItem],
            nowItemID: nowItem.id,
            concurrentNowCount: 2,
            nextItemID: nextItem.id,
            pinnedItemID: pinnedItem.id
        )

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        let expectedState = PeckerActivityAttributes.ContentState(
            primaryTitle: "Design Review",
            primarySubtitle: "Room 42",
            primaryStartDate: nowItem.startDate,
            primaryEndDate: nowItem.endDate,
            primaryKindRawValue: TimelineKind.meeting.rawValue,
            primarySourceIdentifier: "calendar-now",
            nextTitle: "Ship Train",
            nextStartDate: nextItem.startDate,
            pinnedTitle: "Pinned Task",
            pinnedSubtitle: "Pinned notes",
            additionalActiveCount: 2,
            generatedAt: snapshot.generatedAt
        )
        let expectedStaleDate = nextItem.startDate

        XCTAssertEqual(decision, .start(expectedState, expectedStaleDate))
        XCTAssertEqual(
            client.appliedOperations(),
            [
                .start(
                    state: expectedState,
                    staleDate: expectedStaleDate,
                    attributes: PeckerActivityAttributes(
                        localDayIdentifier: "2026-06-24"
                    )
                )
            ]
        )
    }

    func testChangedContentUpdatesCurrentActivity() async throws {
        let existingState = makeContentState(primaryTitle: "Old Title")
        let client = FakeActivityClient(currentState: existingState)
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let nowItem = makeItem(id: "now", title: "New Title")
        let snapshot = makeSnapshot(now: nowItem)

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        let expectedState = makeContentState(
            primaryTitle: "New Title",
            primarySubtitle: "Room",
            primaryStartDate: nowItem.startDate,
            primaryEndDate: nowItem.endDate,
            primarySourceIdentifier: nowItem.sourceIdentifier,
            generatedAt: snapshot.generatedAt
        )
        XCTAssertEqual(decision, .update(expectedState, nowItem.endDate!))
        XCTAssertEqual(
            client.appliedOperations(),
            [
                .update(
                    id: "current",
                    state: expectedState,
                    staleDate: nowItem.endDate!
                )
            ]
        )
    }

    func testEqualContentProducesNoneAndAppliesNoOp() async throws {
        let nowItem = makeItem(id: "now", title: "Design Review")
        let snapshot = makeSnapshot(now: nowItem)
        let currentState = makeContentState(
            primaryTitle: "Design Review",
            primarySubtitle: "Room",
            primaryStartDate: nowItem.startDate,
            primaryEndDate: nowItem.endDate,
            primarySourceIdentifier: nowItem.sourceIdentifier,
            generatedAt: snapshot.generatedAt
        )
        let client = FakeActivityClient(currentState: currentState)
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision, .none)
        XCTAssertEqual(client.appliedOperations(), [])
    }

    func testEmptySnapshotEndsActivity() async throws {
        let client = FakeActivityClient()
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let snapshot = makeSnapshot(items: [])

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision, .end)
        XCTAssertEqual(client.appliedOperations(), [])
    }

    func testFallsBackFromNowToNextThenUnfinishedPinnedOnly() async throws {
        let nextItem = makeItem(
            id: "next",
            title: "Next Event",
            startDate: testNow.addingTimeInterval(1_800),
            endDate: testNow.addingTimeInterval(3_600)
        )
        var snapshot = makeSnapshot(items: [nextItem], nextItemID: nextItem.id)
        var client = FakeActivityClient()
        var coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())

        var decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision.primaryTitle, "Next Event")
        XCTAssertEqual(decision.additionalActiveCount, 0)

        let pinnedItem = makeItem(
            id: "pinned",
            title: "Pinned Errand",
            startDate: testNow.addingTimeInterval(-300),
            endDate: testNow.addingTimeInterval(900),
            location: nil,
            notes: "Bring badge"
        )
        snapshot = makeSnapshot(items: [pinnedItem], pinnedItemID: pinnedItem.id)
        client = FakeActivityClient()
        coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())

        decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision.primaryTitle, "Pinned Errand")
        XCTAssertEqual(decision.primarySubtitle, "Bring badge")
        XCTAssertEqual(decision.additionalActiveCount, 0)
    }

    func testFinishedPinnedOnlyEndsActivity() async throws {
        let client = FakeActivityClient()
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let finishedPinned = makeItem(
            id: "pinned",
            title: "Old Task",
            startDate: testNow.addingTimeInterval(-7_200),
            endDate: testNow.addingTimeInterval(-3_600)
        )
        let snapshot = makeSnapshot(items: [finishedPinned], pinnedItemID: finishedPinned.id)

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision, .end)
    }

    func testStaleDateFallsBackToSnapshotStaleAfterWhenNoEarlierBoundaryExists() async throws {
        let client = FakeActivityClient()
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let nowItem = makeItem(
            id: "now",
            title: "Open Ended",
            startDate: testNow.addingTimeInterval(-600),
            endDate: nil
        )
        let snapshot = makeSnapshot(
            staleAfter: testNow.addingTimeInterval(2_400),
            now: nowItem
        )

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision.staleDate, snapshot.staleAfter)
    }

    func testStaleDayActivityDoesNotSuppressStartForCurrentDayAndIsEnded() async throws {
        let staleState = makeContentState(primaryTitle: "Yesterday")
        let client = FakeActivityClient(
            snapshots: [
                ActivityClientSnapshot(
                    id: "stale",
                    localDayIdentifier: "2026-06-23",
                    contentState: staleState
                )
            ]
        )
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())
        let nowItem = makeItem(id: "now", title: "Today")
        let snapshot = makeSnapshot(now: nowItem)

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision.primaryTitle, "Today")
        XCTAssertEqual(
            client.appliedOperations(),
            [
                .end(id: "stale"),
                .start(
                    state: makeContentState(
                        primaryTitle: "Today",
                        primarySubtitle: "Room",
                        primaryStartDate: nowItem.startDate,
                        primaryEndDate: nowItem.endDate,
                        primarySourceIdentifier: nowItem.sourceIdentifier,
                        generatedAt: snapshot.generatedAt
                    ),
                    staleDate: nowItem.endDate!,
                    attributes: PeckerActivityAttributes(
                        localDayIdentifier: "2026-06-24"
                    )
                )
            ]
        )
    }

    func testDuplicateCurrentDayActivitiesAreCollapsedWhileKeepingOneMatchingActivity() async throws {
        let nowItem = makeItem(id: "now", title: "Updated")
        let snapshot = makeSnapshot(now: nowItem)
        let currentState = makeContentState(
            primaryTitle: "Updated",
            primarySubtitle: "Room",
            primaryStartDate: nowItem.startDate,
            primaryEndDate: nowItem.endDate,
            primarySourceIdentifier: nowItem.sourceIdentifier,
            generatedAt: snapshot.generatedAt
        )
        let duplicateState = makeContentState(primaryTitle: "Duplicate")
        let client = FakeActivityClient(
            snapshots: [
                ActivityClientSnapshot(
                    id: "current-b",
                    localDayIdentifier: "2026-06-24",
                    contentState: duplicateState
                ),
                ActivityClientSnapshot(
                    id: "current-a",
                    localDayIdentifier: "2026-06-24",
                    contentState: currentState
                )
            ]
        )
        let coordinator = ActivityCoordinator(client: client, calendar: utcCalendar())

        let decision = try await coordinator.reconcile(
            snapshot: snapshot,
            settings: TimelineSettings(liveActivityEnabled: true),
            now: testNow
        )

        XCTAssertEqual(decision, .none)
        XCTAssertEqual(client.appliedOperations(), [.end(id: "current-b")])
    }
}

private let testNow = DateComponents(
    calendar: utcCalendar(),
    year: 2026,
    month: 6,
    day: 24,
    hour: 10
).date!

private final class FakeActivityClient: ActivityClient, @unchecked Sendable {
    private let snapshots: [ActivityClientSnapshot]
    private var operations: [ActivityClientOperation] = []

    init(currentState: PeckerActivityAttributes.ContentState? = nil) {
        if let currentState {
            self.snapshots = [
                ActivityClientSnapshot(
                    id: "current",
                    localDayIdentifier: "2026-06-24",
                    contentState: currentState
                )
            ]
        } else {
            self.snapshots = []
        }
    }

    init(snapshots: [ActivityClientSnapshot]) {
        self.snapshots = snapshots
    }

    func activitySnapshots() async -> [ActivityClientSnapshot] {
        snapshots
    }

    func start(
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date,
        attributes: PeckerActivityAttributes
    ) async throws {
        operations.append(
            .start(state: state, staleDate: staleDate, attributes: attributes)
        )
    }

    func update(
        id: String,
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date
    ) async {
        operations.append(.update(id: id, state: state, staleDate: staleDate))
    }

    func end(id: String) async {
        operations.append(.end(id: id))
    }

    func appliedOperations() -> [ActivityClientOperation] {
        operations
    }
}

private extension ActivityDecision {
    var primaryTitle: String? {
        contentState?.primaryTitle
    }

    var primarySubtitle: String? {
        contentState?.primarySubtitle
    }

    var additionalActiveCount: Int? {
        contentState?.additionalActiveCount
    }

    var staleDate: Date? {
        switch self {
        case let .start(_, staleDate), let .update(_, staleDate):
            return staleDate
        case .none, .end:
            return nil
        }
    }

    var contentState: PeckerActivityAttributes.ContentState? {
        switch self {
        case let .start(state, _), let .update(state, _):
            return state
        case .none, .end:
            return nil
        }
    }
}

private func makeSnapshot(
    generatedAt: Date = testNow,
    staleAfter: Date = testNow.addingTimeInterval(3_600),
    now: TimelineItem
) -> TodaySnapshot {
    makeSnapshot(
        generatedAt: generatedAt,
        staleAfter: staleAfter,
        items: [now],
        nowItemID: now.id,
        concurrentNowCount: 0
    )
}

private func makeSnapshot(
    generatedAt: Date = testNow,
    staleAfter: Date = testNow.addingTimeInterval(3_600),
    items: [TimelineItem],
    nowItemID: String? = nil,
    concurrentNowCount: Int = 0,
    nextItemID: String? = nil,
    pinnedItemID: String? = nil
) -> TodaySnapshot {
    TodaySnapshot(
        schemaVersion: TodaySnapshot.currentSchemaVersion,
        generatedAt: generatedAt,
        staleAfter: staleAfter,
        items: items,
        nowItemID: nowItemID,
        concurrentNowCount: concurrentNowCount,
        nextItemID: nextItemID,
        pinnedItemID: pinnedItemID,
        pinOrigin: pinnedItemID == nil ? nil : .manual
    )
}

private func makeItem(
    id: String,
    sourceIdentifier: String? = nil,
    title: String,
    startDate: Date = testNow.addingTimeInterval(-300),
    endDate: Date? = testNow.addingTimeInterval(900),
    kind: TimelineKind = .meeting,
    location: String? = "Room",
    notes: String? = nil
) -> TimelineItem {
    TimelineItem(
        id: id,
        sourceIdentifier: sourceIdentifier ?? id,
        title: title,
        startDate: startDate,
        endDate: endDate,
        isAllDay: false,
        source: .calendar,
        kind: kind,
        location: location,
        notes: notes
    )
}

private func makeContentState(
    primaryTitle: String,
    primarySubtitle: String? = nil,
    primaryStartDate: Date? = nil,
    primaryEndDate: Date? = nil,
    primaryKindRawValue: String = TimelineKind.meeting.rawValue,
    primarySourceIdentifier: String? = nil,
    nextTitle: String? = nil,
    nextStartDate: Date? = nil,
    pinnedTitle: String? = nil,
    pinnedSubtitle: String? = nil,
    additionalActiveCount: Int = 0,
    generatedAt: Date = testNow
) -> PeckerActivityAttributes.ContentState {
    PeckerActivityAttributes.ContentState(
        primaryTitle: primaryTitle,
        primarySubtitle: primarySubtitle,
        primaryStartDate: primaryStartDate,
        primaryEndDate: primaryEndDate,
        primaryKindRawValue: primaryKindRawValue,
        primarySourceIdentifier: primarySourceIdentifier,
        nextTitle: nextTitle,
        nextStartDate: nextStartDate,
        pinnedTitle: pinnedTitle,
        pinnedSubtitle: pinnedSubtitle,
        additionalActiveCount: additionalActiveCount,
        generatedAt: generatedAt
    )
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

import EventKit
import Foundation
import NowTimelineCore
import XCTest
@testable import NowTimeline

final class TodayViewModelTests: XCTestCase {
    @MainActor
    func testAppModelRefreshesForLifecycleSettingsAndEventStoreChanges() async {
        let notificationCenter = NotificationCenter()
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied)
        )
        let dependencies = makeDependencies(gateway: gateway)
        let appModel = AppModel(
            dependencies: dependencies,
            notificationCenter: notificationCenter
        )

        appModel.start()
        await gateway.waitForAuthorizationCount(1)

        notificationCenter.post(name: .EKEventStoreChanged, object: nil)
        await gateway.waitForAuthorizationCount(2)

        appModel.relevantSettingsDidChange()
        await gateway.waitForAuthorizationCount(3)

        appModel.becameActive()
        await gateway.waitForAuthorizationCount(4)
    }

    @MainActor
    func testAuthorizedSourcesProduceContentAndSaveBeforePublishing() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            events: [event(at: now.addingTimeInterval(600))],
            reminders: [reminder(at: now.addingTimeInterval(1_200))]
        )
        let store = FakeSnapshotStore(saveIsGated: true)
        let viewModel = makeViewModel(gateway: gateway, store: store)

        let refresh = Task { await viewModel.refresh(now: now) }

        await store.waitUntilSaveEntered()
        guard case .loading = viewModel.state else {
            return XCTFail("Published \(viewModel.state) before saving completed")
        }

        await store.releaseSave()
        await refresh.value

        guard case let .content(snapshot) = viewModel.state else {
            return XCTFail("Expected content, got \(viewModel.state)")
        }
        XCTAssertEqual(snapshot.items.map(\.id), ["calendar:event", "reminder:reminder"])
        XCTAssertEqual(snapshot.generatedAt, now)
        XCTAssertEqual(snapshot.staleAfter, now.addingTimeInterval(15 * 60))
        let savedSnapshots = await store.savedSnapshots()
        let fetchCounts = await gateway.fetchCounts()
        XCTAssertEqual(savedSnapshots, [snapshot])
        XCTAssertEqual(fetchCounts, .init(calendar: 1, reminders: 1))
    }

    @MainActor
    func testDeniedCalendarFetchesAuthorizedRemindersOnly() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            events: [event(at: now)],
            reminders: [reminder(at: now)]
        )
        let viewModel = makeViewModel(gateway: gateway)

        await viewModel.refresh(now: now)

        guard case let .content(snapshot) = viewModel.state else {
            return XCTFail("Expected reminder content")
        }
        XCTAssertEqual(snapshot.items.map(\.id), ["reminder:reminder"])
        let fetchCounts = await gateway.fetchCounts()
        XCTAssertEqual(fetchCounts, .init(calendar: 0, reminders: 1))
    }

    @MainActor
    func testEnabledButUnreadableSourcesRequirePermission() async {
        let authorization = SourceAuthorization(
            calendar: .writeOnly,
            reminders: .notDetermined
        )
        let gateway = FakeEventKitGateway(authorization: authorization)
        let viewModel = makeViewModel(gateway: gateway)

        await viewModel.refresh(now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(viewModel.state, .permissionRequired(authorization))
        let fetchCounts = await gateway.fetchCounts()
        XCTAssertEqual(fetchCounts, .init(calendar: 0, reminders: 0))
    }

    @MainActor
    func testDisabledSourcesProduceAndSaveEmptySnapshotWithoutPermissionPrompt() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let authorization = SourceAuthorization(
            calendar: .fullAccess,
            reminders: .fullAccess
        )
        let gateway = FakeEventKitGateway(authorization: authorization)
        let store = FakeSnapshotStore()
        let viewModel = makeViewModel(
            gateway: gateway,
            store: store,
            settings: .init(calendarEnabled: false, remindersEnabled: false)
        )

        await viewModel.refresh(now: now)

        XCTAssertEqual(viewModel.state, .empty)
        let saved = await store.savedSnapshots()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.items, [])
        let fetchCounts = await gateway.fetchCounts()
        XCTAssertEqual(fetchCounts, .init(calendar: 0, reminders: 0))
    }

    @MainActor
    func testNoMappedItemsProducesAndSavesEmptySnapshot() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            reminders: [
                ReminderRecord(
                    identifier: "undated",
                    title: "Someday",
                    dueDate: nil,
                    notes: nil
                )
            ]
        )
        let store = FakeSnapshotStore()
        let viewModel = makeViewModel(gateway: gateway, store: store)

        await viewModel.refresh(now: now)

        XCTAssertEqual(viewModel.state, .empty)
        let savedSnapshots = await store.savedSnapshots()
        XCTAssertEqual(savedSnapshots.first?.items, [])
    }

    @MainActor
    func testRefreshFailureWithLoadedSnapshotProducesStaleState() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let previous = snapshot(
            at: now.addingTimeInterval(-3_600),
            items: [EventKitMapper().mapEvent(event(at: now))]
        )
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            eventError: TestError.fetch
        )
        let store = FakeSnapshotStore(loadResult: .value(previous))
        let viewModel = makeViewModel(gateway: gateway, store: store)

        await viewModel.refresh(now: now)

        XCTAssertEqual(
            viewModel.state,
            .stale(previous, "Unable to refresh timeline.")
        )
    }

    @MainActor
    func testRefreshFailureWithoutSnapshotProducesStableFailure() async {
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            eventError: TestError.fetch
        )
        let viewModel = makeViewModel(gateway: gateway)

        await viewModel.refresh(now: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertEqual(viewModel.state, .failure("Unable to refresh timeline."))
    }

    @MainActor
    func testCorruptSnapshotDoesNotCrashAndSuccessfulFetchReplacesIt() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            events: [event(at: now)]
        )
        let store = FakeSnapshotStore(loadResult: .corrupt)
        let viewModel = makeViewModel(gateway: gateway, store: store)

        XCTAssertEqual(viewModel.state, .loading)
        await viewModel.refresh(now: now)

        guard case .content = viewModel.state else {
            return XCTFail("Expected content after corrupt cache")
        }
    }

    @MainActor
    func testReminderDurationAndSourceSettingsAreApplied() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dueDate = now.addingTimeInterval(300)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            events: [event(at: now)],
            reminders: [reminder(at: dueDate)]
        )
        let viewModel = makeViewModel(
            gateway: gateway,
            settings: .init(
                calendarEnabled: false,
                remindersEnabled: true,
                reminderDurationMinutes: 45
            )
        )

        await viewModel.refresh(now: now)

        guard case let .content(snapshot) = viewModel.state else {
            return XCTFail("Expected reminder content")
        }
        let item = try XCTUnwrap(snapshot.items.first)
        XCTAssertEqual(item.id, "reminder:reminder")
        XCTAssertEqual(item.endDate, dueDate.addingTimeInterval(45 * 60))
        let fetchCounts = await gateway.fetchCounts()
        XCTAssertEqual(fetchCounts, .init(calendar: 0, reminders: 1))
    }

    @MainActor
    func testSaveFailureUsesPreviousSnapshotAsStale() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let previous = snapshot(
            at: now.addingTimeInterval(-3_600),
            items: [EventKitMapper().mapEvent(event(at: now))]
        )
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            events: [event(at: now.addingTimeInterval(600))]
        )
        let store = FakeSnapshotStore(
            loadResult: .value(previous),
            saveError: TestError.save
        )
        let viewModel = makeViewModel(gateway: gateway, store: store)

        await viewModel.refresh(now: now)

        XCTAssertEqual(
            viewModel.state,
            .stale(previous, "Unable to refresh timeline.")
        )
    }

    @MainActor
    func testSaveFailureWithoutPreviousSnapshotProducesFailure() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            events: [event(at: now)]
        )
        let store = FakeSnapshotStore(saveError: TestError.save)
        let viewModel = makeViewModel(gateway: gateway, store: store)

        await viewModel.refresh(now: now)

        XCTAssertEqual(viewModel.state, .failure("Unable to refresh timeline."))
    }

    @MainActor
    func testCalendarAndReminderFetchesRunConcurrently() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            events: [event(at: now)],
            reminders: [reminder(at: now)],
            synchronizeFetches: true
        )
        let viewModel = makeViewModel(gateway: gateway)

        await viewModel.refresh(now: now)

        let enteredFetches = await gateway.enteredFetches()
        XCTAssertEqual(enteredFetches, [.calendar, .reminders])
        guard case .content = viewModel.state else {
            return XCTFail("Expected content after concurrent fetches")
        }
    }

    @MainActor
    func testProductionFailsExplicitlyWhenAppGroupContainerIsUnavailable() {
        XCTAssertThrowsError(
            try AppDependencies.production(
                containerURLProvider: { nil },
                settingsStoreFactory: {
                    XCTFail("Settings factory should not run without a container")
                    throw TestError.settings
                }
            )
        ) { error in
            guard case AppDependenciesError.appGroupContainerUnavailable = error
            else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    func testCancellationDoesNotOverwriteCurrentStateWithFailure() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let gateway = FakeEventKitGateway(
            authorization: .init(calendar: .fullAccess, reminders: .denied),
            waitForCancellation: true
        )
        let viewModel = makeViewModel(gateway: gateway)
        let refresh = Task { await viewModel.refresh(now: now) }

        await gateway.waitUntilFetchStarts()
        refresh.cancel()
        await refresh.value

        XCTAssertEqual(viewModel.state, .loading)
    }

    @MainActor
    private func makeViewModel(
        gateway: FakeEventKitGateway,
        store: FakeSnapshotStore = FakeSnapshotStore(),
        settings: TimelineSettings = .init()
    ) -> TodayViewModel {
        TodayViewModel(
            dependencies: makeDependencies(
                gateway: gateway,
                store: store,
                settings: settings
            )
        )
    }

    @MainActor
    private func makeDependencies(
        gateway: FakeEventKitGateway,
        store: FakeSnapshotStore = FakeSnapshotStore(),
        settings: TimelineSettings = .init()
    ) -> AppDependencies {
        let defaults = UserDefaults(
            suiteName: "TodayViewModelTests.\(UUID().uuidString)"
        )!
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.update { $0 = settings }
        return AppDependencies(
            gateway: gateway,
            mapper: EventKitMapper(),
            engine: TimelineEngine(),
            snapshotStore: store,
            settingsStore: settingsStore,
            calendar: Calendar(identifier: .gregorian)
        )
    }
}

private actor FakeEventKitGateway: EventKitGatewayProtocol {
    enum Fetch: Hashable {
        case calendar
        case reminders
    }

    struct FetchCounts: Equatable {
        let calendar: Int
        let reminders: Int
    }

    private let sourceAuthorization: SourceAuthorization
    private let events: [EventRecord]
    private let reminders: [ReminderRecord]
    private let eventError: Error?
    private let reminderError: Error?
    private let waitForCancellation: Bool
    private let fetchBarrier: FetchBarrier?
    private var calendarFetchCount = 0
    private var reminderFetchCount = 0
    private var fetchesEntered: Set<Fetch> = []
    private var authorizationCallCount = 0
    private var authorizationWaiters: [
        (count: Int, continuation: CheckedContinuation<Void, Never>)
    ] = []
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var didStartFetch = false

    init(
        authorization: SourceAuthorization,
        events: [EventRecord] = [],
        reminders: [ReminderRecord] = [],
        eventError: Error? = nil,
        reminderError: Error? = nil,
        waitForCancellation: Bool = false,
        synchronizeFetches: Bool = false
    ) {
        sourceAuthorization = authorization
        self.events = events
        self.reminders = reminders
        self.eventError = eventError
        self.reminderError = reminderError
        self.waitForCancellation = waitForCancellation
        fetchBarrier = synchronizeFetches ? FetchBarrier() : nil
    }

    func authorization() -> SourceAuthorization {
        authorizationCallCount += 1
        let readyWaiters = authorizationWaiters.filter {
            authorizationCallCount >= $0.count
        }
        authorizationWaiters.removeAll {
            authorizationCallCount >= $0.count
        }
        readyWaiters.forEach { $0.continuation.resume() }
        return sourceAuthorization
    }

    func requestCalendarAccess() async throws -> Bool { false }
    func requestReminderAccess() async throws -> Bool { false }

    func fetchToday(calendar: Calendar, now: Date) async throws -> [EventRecord] {
        calendarFetchCount += 1
        fetchesEntered.insert(.calendar)
        markFetchStarted()
        if let fetchBarrier {
            await fetchBarrier.enter()
        }
        if waitForCancellation {
            try await Task.sleep(for: .seconds(60))
        }
        if let eventError {
            throw eventError
        }
        return events
    }

    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] {
        reminderFetchCount += 1
        fetchesEntered.insert(.reminders)
        markFetchStarted()
        if let fetchBarrier {
            await fetchBarrier.enter()
        }
        if let reminderError {
            throw reminderError
        }
        return reminders
    }

    func fetchCounts() -> FetchCounts {
        .init(calendar: calendarFetchCount, reminders: reminderFetchCount)
    }

    func enteredFetches() -> Set<Fetch> {
        fetchesEntered
    }

    func waitUntilFetchStarts() async {
        if didStartFetch {
            return
        }
        await withCheckedContinuation {
            fetchStartedContinuation = $0
        }
    }

    func waitForAuthorizationCount(_ count: Int) async {
        if authorizationCallCount >= count {
            return
        }
        await withCheckedContinuation {
            authorizationWaiters.append((count, $0))
        }
    }

    private func markFetchStarted() {
        didStartFetch = true
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil
    }
}

private actor FetchBarrier {
    private var enteredCount = 0
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func enter() async {
        enteredCount += 1
        if enteredCount == 2 {
            let pending = continuations
            continuations.removeAll()
            pending.forEach { $0.resume() }
            return
        }

        await withCheckedContinuation {
            continuations.append($0)
        }
    }
}

private actor FakeSnapshotStore: SnapshotStoring {
    private let loadResult: SnapshotLoadResult
    private let saveError: Error?
    private let saveIsGated: Bool
    private var snapshots: [TodaySnapshot] = []
    private var saveEntered = false
    private var saveEnteredContinuations: [CheckedContinuation<Void, Never>] = []
    private var saveReleaseContinuation: CheckedContinuation<Void, Never>?

    init(
        loadResult: SnapshotLoadResult = .missing,
        saveError: Error? = nil,
        saveIsGated: Bool = false
    ) {
        self.loadResult = loadResult
        self.saveError = saveError
        self.saveIsGated = saveIsGated
    }

    func load() -> SnapshotLoadResult {
        loadResult
    }

    func save(_ snapshot: TodaySnapshot) async throws {
        saveEntered = true
        let enteredContinuations = saveEnteredContinuations
        saveEnteredContinuations.removeAll()
        enteredContinuations.forEach { $0.resume() }
        if saveIsGated {
            await withCheckedContinuation {
                saveReleaseContinuation = $0
            }
        }
        if let saveError {
            throw saveError
        }
        snapshots.append(snapshot)
    }

    func waitUntilSaveEntered() async {
        if saveEntered {
            return
        }
        await withCheckedContinuation {
            saveEnteredContinuations.append($0)
        }
    }

    func releaseSave() {
        saveReleaseContinuation?.resume()
        saveReleaseContinuation = nil
    }

    func savedSnapshots() -> [TodaySnapshot] {
        snapshots
    }
}

private enum TestError: Error {
    case fetch
    case save
    case settings
}

private func event(at date: Date) -> EventRecord {
    EventRecord(
        identifier: "event",
        title: "Team meeting",
        startDate: date,
        endDate: date.addingTimeInterval(1_800),
        isAllDay: false,
        location: nil,
        notes: nil
    )
}

private func reminder(at date: Date) -> ReminderRecord {
    ReminderRecord(
        identifier: "reminder",
        title: "Submit report",
        dueDate: date,
        notes: nil
    )
}

private func snapshot(
    at date: Date,
    items: [TimelineItem]
) -> TodaySnapshot {
    TimelineEngine().makeSnapshot(
        items: items,
        now: date,
        settings: TimelineSettings(),
        staleInterval: 15 * 60
    )
}

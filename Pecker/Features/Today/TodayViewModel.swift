import Foundation
import PeckerCore
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private static let staleInterval: TimeInterval = 15 * 60

    private let dependencies: AppDependencies
    private let snapshotCommitter: SnapshotCommitter
    private let activityReconciliationQueue = ActivityReconciliationQueue()
    private var previousSnapshot: TodaySnapshot?
    private var refreshGeneration = 0

    let timelineManager: TimelineManagerModel
    private(set) var state: TimelineScreenState = .loading
    private(set) var latestAuthorization: SourceAuthorization?
    private(set) var liveActivityStatusText = "\u{7b49}\u{5f85}\u{5185}\u{5bb9}"
    private(set) var nextLiveActivityBoundary: Date?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        timelineManager = TimelineManagerModel(
            gateway: dependencies.gateway,
            mapper: dependencies.mapper,
            recognizer: dependencies.systemEventRecognizer,
            localCards: dependencies.localTimelineCards,
            settingsStore: dependencies.settingsStore,
            calendar: dependencies.calendar
        )
        snapshotCommitter = SnapshotCommitter(
            store: dependencies.snapshotStore
        )
        timelineManager.onMutation = { [weak self] in
            await self?.refresh()
        }
    }

    func refresh(now: Date = .now) async {
        refreshGeneration += 1
        let generation = refreshGeneration

        await loadSnapshot(now: now, generation: generation)
        guard isCurrent(generation), !Task.isCancelled else {
            return
        }

        do {
            try Task.checkCancellation()

            let settings = dependencies.settingsStore.value
            let authorization = await dependencies.gateway.authorization()
            guard isCurrent(generation) else {
                return
            }
            latestAuthorization = authorization
            let fetchCalendar =
                settings.calendarEnabled
                && authorization.calendar == .fullAccess
            let fetchReminders =
                settings.remindersEnabled
                && authorization.reminders == .fullAccess

            guard fetchCalendar || fetchReminders
                    || (!settings.calendarEnabled && !settings.remindersEnabled)
            else {
                let snapshot = emptySnapshot(now: now)
                try await snapshotCommitter.save(snapshot)
                try Task.checkCancellation()
                guard isCurrent(generation) else {
                    return
                }
                await reconcileLiveActivity(
                    snapshot: snapshot,
                    settings: settings,
                    now: now,
                    generation: generation
                )
                guard isCurrent(generation) else {
                    return
                }
                state = .permissionRequired(authorization)
                return
            }

            async let eventRecords: [EventRecord] = fetchCalendar
                ? dependencies.gateway.fetchToday(
                    calendar: dependencies.calendar,
                    now: now
                )
                : []
            async let reminderRecords: [ReminderRecord] = fetchReminders
                ? dependencies.gateway.fetchReminders(
                    calendar: dependencies.calendar,
                    now: now
                )
                : []
            async let pinnedEventRecords: [EventRecord] =
                pinnedSystemEvents(
                    fetchCalendar: fetchCalendar,
                    manualPinnedSourceIdentifier:
                        settings.manualPinnedSourceIdentifier,
                    now: now
                )
            async let pinnedReminderRecords: [ReminderRecord] =
                pinnedSystemReminders(
                    fetchReminders: fetchReminders,
                    manualPinnedSourceIdentifier:
                        settings.manualPinnedSourceIdentifier,
                    now: now
                )

            let (
                events,
                reminders,
                pinnedEvents,
                pinnedReminders
            ) = try await (
                eventRecords,
                reminderRecords,
                pinnedEventRecords,
                pinnedReminderRecords
            )
            try Task.checkCancellation()
            guard isCurrent(generation) else {
                return
            }

            let mergedEvents = mergeRecords(
                primary: events,
                extras: pinnedEvents,
                id: \.identifier
            )
            let mergedReminders = mergeRecords(
                primary: reminders,
                extras: pinnedReminders,
                id: \.identifier
            )
            let recognizedTemplates = await dependencies.systemEventRecognizer
                .synchronize(
                    events: mergedEvents,
                    reminders: mergedReminders,
                    settings: settings,
                    now: now
                )
            let recognizedImageItems = await dependencies.systemEventRecognizer
                .recognizedImageItems(
                    settings: settings,
                    now: now
                )

            let allItems = mergedEvents.map {
                dependencies.mapper.mapEvent(
                    $0,
                    template: recognizedTemplates["calendar:\($0.identifier)"]
                )
            }
                + mergedReminders.compactMap {
                    dependencies.mapper.mapReminder(
                        $0,
                        template: recognizedTemplates["reminder:\($0.identifier)"]
                    )
                }
                + recognizedImageItems
            let items = allItems.filter {
                TimelineDateScope.classify(
                    $0,
                    calendar: dependencies.calendar,
                    now: now
                ) == .today
                    || $0.sourceIdentifier
                        == settings.manualPinnedSourceIdentifier
            }
            let snapshot = dependencies.engine.makeSnapshot(
                items: items,
                now: now,
                settings: settings,
                staleInterval: Self.staleInterval
            )

            guard isCurrent(generation) else {
                return
            }
            try await snapshotCommitter.save(snapshot)
            try Task.checkCancellation()
            guard isCurrent(generation) else {
                return
            }
            await reconcileLiveActivity(
                snapshot: snapshot,
                settings: settings,
                now: now,
                generation: generation
            )
            guard isCurrent(generation) else {
                return
            }

            previousSnapshot = snapshot
            state = snapshot.items.isEmpty ? emptyState() : .content(snapshot)
        } catch is CancellationError {
            return
        } catch {
            guard isCurrent(generation) else {
                return
            }
            let message = TimelineErrorMessage.refreshFailed
            if let previousSnapshot {
                state = .stale(previousSnapshot, message)
            } else {
                state = .failure(message)
            }
        }
    }

    func authorizationNotice() -> TimelineAuthorizationNotice? {
        TimelineAuthorizationNotice.make(
            authorization: latestAuthorization,
            settings: dependencies.settingsStore.value
        )
    }

    private func emptyState() -> TimelineScreenState {
        .empty(authorizationNotice())
    }

    private func reconcileLiveActivity(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date,
        generation: Int
    ) async {
        await activityReconciliationQueue.acquire()
        guard isCurrent(generation), !Task.isCancelled else {
            await activityReconciliationQueue.release()
            return
        }

        let statusText: String
        let nextBoundary: Date?
        do {
            let result = try await dependencies.activityCoordinator
                .reconcileWithBoundary(
                snapshot: snapshot,
                settings: settings,
                now: now
            )
            statusText = self.statusText(
                for: result.decision,
                settings: settings
            )
            nextBoundary = result.nextBoundary
        } catch {
            statusText = "\u{6682}\u{4e0d}\u{53ef}\u{7528}"
            nextBoundary = nil
        }

        if isCurrent(generation), !Task.isCancelled {
            liveActivityStatusText = statusText
            nextLiveActivityBoundary = nextBoundary
        }
        await activityReconciliationQueue.release()
    }

    private func statusText(
        for decision: ActivityDecision,
        settings: TimelineSettings
    ) -> String {
        guard settings.liveActivityEnabled else {
            return "\u{5df2}\u{6682}\u{505c}"
        }

        switch decision {
        case .none, .start, .update:
            return "\u{8fd0}\u{884c}\u{4e2d}"
        case .end:
            return "\u{7b49}\u{5f85}\u{5185}\u{5bb9}"
        }
    }

    private func emptySnapshot(now: Date) -> TodaySnapshot {
        dependencies.engine.makeSnapshot(
            items: [],
            now: now,
            settings: dependencies.settingsStore.value,
            staleInterval: Self.staleInterval
        )
    }

    private func pinnedSystemEvents(
        fetchCalendar: Bool,
        manualPinnedSourceIdentifier: String?,
        now: Date
    ) async throws -> [EventRecord] {
        guard fetchCalendar, let manualPinnedSourceIdentifier else {
            return []
        }
        return try await dependencies.gateway.fetchEvents(
            in: pinnedLookupInterval(now: now),
            calendar: dependencies.calendar
        )
        .filter { $0.identifier == manualPinnedSourceIdentifier }
    }

    private func pinnedSystemReminders(
        fetchReminders: Bool,
        manualPinnedSourceIdentifier: String?,
        now: Date
    ) async throws -> [ReminderRecord] {
        guard fetchReminders, let manualPinnedSourceIdentifier else {
            return []
        }
        return try await dependencies.gateway.fetchReminders(
            in: pinnedLookupInterval(now: now),
            calendar: dependencies.calendar
        )
        .filter {
            $0.identifier == manualPinnedSourceIdentifier
                && !$0.isCompleted
        }
    }

    private func pinnedLookupInterval(now: Date) -> DateInterval {
        let startOfToday = dependencies.calendar.startOfDay(for: now)
        let start = dependencies.calendar.date(
            byAdding: .year,
            value: -1,
            to: startOfToday
        ) ?? startOfToday.addingTimeInterval(-366 * 86_400)
        let end = dependencies.calendar.date(
            byAdding: .year,
            value: 1,
            to: startOfToday
        ) ?? startOfToday.addingTimeInterval(366 * 86_400)
        return DateInterval(start: start, end: end)
    }

    private func mergeRecords<Record>(
        primary: [Record],
        extras: [Record],
        id: (Record) -> String
    ) -> [Record] {
        var seen = Set(primary.map(id))
        var records = primary
        for record in extras where !seen.contains(id(record)) {
            records.append(record)
            seen.insert(id(record))
        }
        return records
    }

    private func loadSnapshot(now: Date, generation: Int) async {
        if let previousSnapshot {
            applyCachedSnapshot(
                previousSnapshot,
                now: now,
                generation: generation
            )
            return
        }

        switch await dependencies.snapshotStore.load() {
        case let .value(snapshot):
            applyCachedSnapshot(snapshot, now: now, generation: generation)
        case .missing, .corrupt, .unsupportedSchema:
            break
        }
    }

    private func applyCachedSnapshot(
        _ snapshot: TodaySnapshot,
        now: Date,
        generation: Int
    ) {
        guard isCurrent(generation) else {
            return
        }
        guard dependencies.calendar.isDate(snapshot.generatedAt, inSameDayAs: now)
        else {
            previousSnapshot = nil
            return
        }

        previousSnapshot = snapshot
        if snapshot.isStale(at: now) {
            state = .stale(snapshot, TimelineErrorMessage.cacheStale)
        } else {
            state = snapshot.items.isEmpty ? emptyState() : .content(snapshot)
        }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == refreshGeneration
    }
}

private actor ActivityReconciliationQueue {
    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isRunning {
            isRunning = true
            return
        }

        await withCheckedContinuation {
            waiters.append($0)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}

actor SnapshotCommitter {
    private let store: any SnapshotStoring
    private var nextCommitID = 0
    private var latestCommit: (id: Int, task: Task<Void, any Error>)?

    init(store: any SnapshotStoring) {
        self.store = store
    }

    func save(_ snapshot: TodaySnapshot) async throws {
        nextCommitID += 1
        let commitID = nextCommitID
        let precedingCommit = latestCommit?.task
        let store = store
        let commit = Task {
            if let precedingCommit {
                _ = try? await precedingCommit.value
            }
            try await store.save(snapshot)
        }
        latestCommit = (commitID, commit)

        defer {
            if latestCommit?.id == commitID {
                latestCommit = nil
            }
        }
        try await commit.value
    }
}

private enum TimelineErrorMessage {
    static let refreshFailed = "Unable to refresh timeline."
    static let cacheStale = "Timeline may be out of date."
}

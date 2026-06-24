import Foundation
import PeckerCore
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private static let staleInterval: TimeInterval = 15 * 60

    private let dependencies: AppDependencies
    private let snapshotCommitter: SnapshotCommitter
    private var previousSnapshot: TodaySnapshot?
    private var refreshGeneration = 0

    private(set) var state: TimelineScreenState = .loading
    private(set) var latestAuthorization: SourceAuthorization?
    private(set) var liveActivityStatusText = "已暂停"

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        snapshotCommitter = SnapshotCommitter(
            store: dependencies.snapshotStore
        )
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
                if isCurrent(generation) {
                    if !settings.liveActivityEnabled {
                        await reconcileLiveActivity(
                            snapshot: emptySnapshot(now: now),
                            settings: settings,
                            now: now
                        )
                    }
                    state = .permissionRequired(authorization)
                }
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

            let (events, reminders) = try await (
                eventRecords,
                reminderRecords
            )
            try Task.checkCancellation()
            guard isCurrent(generation) else {
                return
            }

            let items = events.map(dependencies.mapper.mapEvent)
                + reminders.compactMap {
                    dependencies.mapper.mapReminder(
                        $0,
                        durationMinutes: settings.reminderDurationMinutes
                    )
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
                now: now
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
        now: Date
    ) async {
        do {
            let decision = try await dependencies.activityCoordinator.reconcile(
                snapshot: snapshot,
                settings: settings,
                now: now
            )
            liveActivityStatusText = statusText(
                for: decision,
                settings: settings
            )
        } catch {
            liveActivityStatusText = "暂不可用"
        }
    }

    private func statusText(
        for decision: ActivityDecision,
        settings: TimelineSettings
    ) -> String {
        guard settings.liveActivityEnabled else {
            return "已暂停"
        }

        switch decision {
        case .none, .start, .update:
            return "运行中"
        case .end:
            return "等待内容"
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

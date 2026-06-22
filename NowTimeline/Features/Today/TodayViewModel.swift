import Foundation
import NowTimelineCore
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private static let staleInterval: TimeInterval = 15 * 60

    private let dependencies: AppDependencies
    private var previousSnapshot: TodaySnapshot?
    private var refreshGeneration = 0

    private(set) var state: TimelineScreenState = .loading

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
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
            try await dependencies.snapshotStore.save(snapshot)
            try Task.checkCancellation()
            guard isCurrent(generation) else {
                return
            }

            previousSnapshot = snapshot
            state = snapshot.items.isEmpty ? .empty : .content(snapshot)
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
            state = snapshot.items.isEmpty ? .empty : .content(snapshot)
        }
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == refreshGeneration
    }
}

private enum TimelineErrorMessage {
    static let refreshFailed = "Unable to refresh timeline."
    static let cacheStale = "Timeline may be out of date."
}

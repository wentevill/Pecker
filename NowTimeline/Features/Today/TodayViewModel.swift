import Foundation
import NowTimelineCore
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private static let staleInterval: TimeInterval = 15 * 60

    private let dependencies: AppDependencies
    private var previousSnapshot: TodaySnapshot?

    private(set) var state: TimelineScreenState = .loading

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func refresh(now: Date = .now) async {
        await loadSnapshotIfNeeded()

        do {
            try Task.checkCancellation()

            let settings = dependencies.settingsStore.value
            let authorization = await dependencies.gateway.authorization()
            let fetchCalendar =
                settings.calendarEnabled
                && authorization.calendar == .fullAccess
            let fetchReminders =
                settings.remindersEnabled
                && authorization.reminders == .fullAccess

            guard fetchCalendar || fetchReminders
                    || (!settings.calendarEnabled && !settings.remindersEnabled)
            else {
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

            let (events, reminders) = try await (
                eventRecords,
                reminderRecords
            )
            try Task.checkCancellation()

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

            try await dependencies.snapshotStore.save(snapshot)
            try Task.checkCancellation()

            previousSnapshot = snapshot
            state = snapshot.items.isEmpty ? .empty : .content(snapshot)
        } catch is CancellationError {
            return
        } catch {
            let message = TimelineErrorMessage.refreshFailed
            if let previousSnapshot {
                state = .stale(previousSnapshot, message)
            } else {
                state = .failure(message)
            }
        }
    }

    private func loadSnapshotIfNeeded() async {
        guard previousSnapshot == nil else {
            return
        }

        switch await dependencies.snapshotStore.load() {
        case let .value(snapshot):
            previousSnapshot = snapshot
            state = snapshot.items.isEmpty ? .empty : .content(snapshot)
        case .missing, .corrupt, .unsupportedSchema:
            break
        }
    }
}

private enum TimelineErrorMessage {
    static let refreshFailed = "Unable to refresh timeline."
}

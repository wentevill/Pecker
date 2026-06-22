import EventKit
import Foundation

actor EventKitGateway: EventKitGatewayProtocol {
    private enum GatewayError: Error {
        case invalidDayInterval
    }

    private let store: EKEventStore

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func authorization() -> SourceAuthorization {
        SourceAuthorization(
            calendar: SourceAuthorizationStatus(
                EKEventStore.authorizationStatus(for: .event)
            ),
            reminders: SourceAuthorizationStatus(
                EKEventStore.authorizationStatus(for: .reminder)
            )
        )
    }

    func requestCalendarAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func requestReminderAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    func fetchToday(
        calendar: Calendar,
        now: Date
    ) async throws -> [EventRecord] {
        try Task.checkCancellation()
        let interval = try dayInterval(calendar: calendar, now: now)
        let predicate = store.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: nil
        )

        return store.events(matching: predicate).compactMap { event in
            guard let identifier = event.eventIdentifier else {
                return nil
            }

            return EventRecord(
                identifier: identifier,
                title: event.title ?? "无标题",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                notes: event.notes
            )
        }
    }

    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] {
        try Task.checkCancellation()
        let interval = try dayInterval(calendar: calendar, now: now)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let records = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[ReminderRecord], Error>) in
            store.fetchReminders(matching: predicate) { reminders in
                let records: [ReminderRecord] = (reminders ?? []).compactMap {
                    (reminder: EKReminder) -> ReminderRecord? in
                    let identifier = reminder.calendarItemIdentifier
                    guard
                        !reminder.isCompleted,
                        !identifier.isEmpty,
                        let components = reminder.dueDateComponents,
                        let dueDate = calendar.date(from: components),
                        dueDate < interval.end
                    else {
                        return nil
                    }

                    return ReminderRecord(
                        identifier: identifier,
                        title: reminder.title ?? "无标题",
                        dueDate: dueDate,
                        notes: reminder.notes
                    )
                }
                continuation.resume(returning: records)
            }
        }

        try Task.checkCancellation()
        return records
    }

    private func dayInterval(
        calendar: Calendar,
        now: Date
    ) throws -> DateInterval {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            throw GatewayError.invalidDayInterval
        }
        return DateInterval(start: start, end: end)
    }
}

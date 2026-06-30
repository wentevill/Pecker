import EventKit
import Foundation

enum EventKitGatewaySupport {
    static func dayInterval(
        calendar: Calendar,
        now: Date
    ) -> DateInterval? {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    static func authorizationStatus(
        _ status: EKAuthorizationStatus
    ) -> SourceAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .restricted
        }
    }

    static func includesReminder(
        dueDate: Date,
        interval: DateInterval
    ) -> Bool {
        dueDate >= interval.start && dueDate < interval.end
    }

    static func cancellableFetch<Value: Sendable, Identifier: Sendable>(
        isolation: isolated (any Actor)? = #isolation,
        start: (
            @escaping @Sendable (Value) -> Void
        ) -> Identifier,
        cancel: @escaping @Sendable (Identifier) -> Void
    ) async throws -> Value {
        let state = CancellableFetchState<Value, Identifier>(cancel: cancel)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation(
                isolation: isolation
            ) { continuation in
                guard state.begin(continuation) else { return }

                let identifier = start { value in
                    state.complete(value)
                }
                state.setIdentifier(identifier)
            }
        } onCancel: {
            state.cancel()
        }
    }
}

private final class CancellableFetchState<
    Value: Sendable,
    Identifier: Sendable
>: @unchecked Sendable {
    private let lock = NSLock()
    private let cancelFetch: @Sendable (Identifier) -> Void
    private var continuation: CheckedContinuation<Value, Error>?
    private var identifier: Identifier?
    private var cancellationRequested = false
    private var cancelIssued = false
    private var finished = false

    init(cancel: @escaping @Sendable (Identifier) -> Void) {
        cancelFetch = cancel
    }

    func begin(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
        let shouldStart = lock.withLock {
            guard !finished else {
                return false
            }
            self.continuation = continuation
            return true
        }

        if !shouldStart {
            continuation.resume(throwing: CancellationError())
        }
        return shouldStart
    }

    func setIdentifier(_ identifier: Identifier) {
        let shouldCancel = lock.withLock {
            guard !finished || cancellationRequested else {
                return false
            }
            self.identifier = identifier
            guard cancellationRequested, !cancelIssued else {
                return false
            }
            cancelIssued = true
            return true
        }

        if shouldCancel {
            cancelFetch(identifier)
        }
    }

    func complete(_ value: Value) {
        let continuation: CheckedContinuation<Value, Error>? = lock.withLock {
            guard !finished else {
                return nil
            }
            finished = true
            let continuation = self.continuation
            self.continuation = nil
            identifier = nil
            return continuation
        }
        continuation?.resume(returning: value)
    }

    func cancel() {
        let action = lock.withLock {
            guard !finished else {
                return (
                    continuation: Optional<
                        CheckedContinuation<Value, Error>
                    >.none,
                    identifier: Optional<Identifier>.none
                )
            }

            cancellationRequested = true
            finished = true
            let continuation = self.continuation
            self.continuation = nil

            let identifier = self.identifier
            if identifier != nil {
                cancelIssued = true
            }
            return (continuation, identifier)
        }

        if let identifier = action.identifier {
            cancelFetch(identifier)
        }
        action.continuation?.resume(throwing: CancellationError())
    }
}

private final class EventKitFetchIdentifier: @unchecked Sendable {
    let rawValue: Any

    init(_ rawValue: Any) {
        self.rawValue = rawValue
    }
}

private final class EventKitStoreCanceller: @unchecked Sendable {
    private let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    func cancel(_ identifier: EventKitFetchIdentifier) {
        store.cancelFetchRequest(identifier.rawValue)
    }
}

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
        let interval = try dayInterval(calendar: calendar, now: now)
        return try await fetchEvents(in: interval, calendar: calendar)
    }

    func fetchEvents(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [EventRecord] {
        try Task.checkCancellation()
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
                title: event.title ?? "\u{65e0}\u{6807}\u{9898}",
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
        let interval = try dayInterval(calendar: calendar, now: now)
        return try await fetchReminders(in: interval, calendar: calendar)
            .filter { !$0.isCompleted }
    }

    func fetchReminders(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [ReminderRecord] {
        try Task.checkCancellation()
        let predicate = store.predicateForReminders(in: nil)
        let canceller = EventKitStoreCanceller(store: store)

        return try await EventKitGatewaySupport
            .cancellableFetch(
                start: { completion in
                    let identifier = store.fetchReminders(
                        matching: predicate
                    ) { reminders in
                        let records: [ReminderRecord] = (reminders ?? [])
                            .compactMap { reminder in
                                let identifier =
                                    reminder.calendarItemIdentifier
                                guard
                                    !identifier.isEmpty,
                                    let components =
                                        reminder.dueDateComponents,
                                    let dueDate = calendar.date(
                                        from: components
                                    ),
                                    EventKitGatewaySupport.includesReminder(
                                        dueDate: dueDate,
                                        interval: interval
                                    )
                                else {
                                    return nil
                                }

                                return ReminderRecord(
                                    identifier: identifier,
                                    title: reminder.title ?? "\u{65e0}\u{6807}\u{9898}",
                                    dueDate: dueDate,
                                    notes: reminder.notes,
                                    isCompleted: reminder.isCompleted
                                )
                            }
                        completion(records)
                    }
                    return EventKitFetchIdentifier(identifier)
                },
                cancel: { identifier in
                    canceller.cancel(identifier)
                }
            )
    }

    private func dayInterval(
        calendar: Calendar,
        now: Date
    ) throws -> DateInterval {
        guard let interval = EventKitGatewaySupport.dayInterval(
            calendar: calendar,
            now: now
        ) else {
            throw GatewayError.invalidDayInterval
        }
        return interval
    }
}

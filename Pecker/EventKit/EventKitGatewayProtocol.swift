import EventKit
import Foundation

struct EventRecord: Sendable {
    let identifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
}

struct ReminderRecord: Sendable {
    let identifier: String
    let title: String
    let dueDate: Date?
    let notes: String?
    let isCompleted: Bool

    init(
        identifier: String,
        title: String,
        dueDate: Date?,
        notes: String?,
        isCompleted: Bool = false
    ) {
        self.identifier = identifier
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

enum SourceAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
    case writeOnly

    init(_ status: EKAuthorizationStatus) {
        self = EventKitGatewaySupport.authorizationStatus(status)
    }
}

struct SourceAuthorization: Sendable, Equatable {
    let calendar: SourceAuthorizationStatus
    let reminders: SourceAuthorizationStatus
}

protocol EventKitGatewayProtocol: Sendable {
    func authorization() async -> SourceAuthorization
    func requestCalendarAccess() async throws -> Bool
    func requestReminderAccess() async throws -> Bool
    func fetchToday(calendar: Calendar, now: Date) async throws -> [EventRecord]
    func fetchReminders(calendar: Calendar, now: Date) async throws -> [ReminderRecord]
    func fetchEvents(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [EventRecord]
    func fetchReminders(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [ReminderRecord]
}

extension EventKitGatewayProtocol {
    func fetchEvents(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [EventRecord] {
        []
    }

    func fetchReminders(
        in interval: DateInterval,
        calendar: Calendar
    ) async throws -> [ReminderRecord] {
        []
    }
}

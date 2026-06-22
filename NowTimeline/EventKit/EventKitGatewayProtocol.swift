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
}

enum SourceAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case fullAccess
    case writeOnly

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .fullAccess:
            self = .fullAccess
        case .writeOnly:
            self = .writeOnly
        @unknown default:
            self = .restricted
        }
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
}

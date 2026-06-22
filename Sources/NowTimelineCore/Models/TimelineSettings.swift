import Foundation

public struct TimelineSettings: Codable, Equatable, Sendable {
    public var calendarEnabled: Bool
    public var remindersEnabled: Bool
    public var showTravelEvents: Bool
    public var reminderDurationMinutes: Int
    public var manualPinnedSourceIdentifier: String?
    public var liveActivityEnabled: Bool

    public init(
        calendarEnabled: Bool = true,
        remindersEnabled: Bool = true,
        showTravelEvents: Bool = true,
        reminderDurationMinutes: Int = 30,
        manualPinnedSourceIdentifier: String? = nil,
        liveActivityEnabled: Bool = false
    ) {
        self.calendarEnabled = calendarEnabled
        self.remindersEnabled = remindersEnabled
        self.showTravelEvents = showTravelEvents
        self.reminderDurationMinutes = reminderDurationMinutes
        self.manualPinnedSourceIdentifier = manualPinnedSourceIdentifier
        self.liveActivityEnabled = liveActivityEnabled
    }
}

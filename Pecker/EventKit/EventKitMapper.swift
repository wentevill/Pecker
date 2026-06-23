import Foundation
import PeckerCore

struct EventKitMapper: Sendable {
    func mapEvent(_ record: EventRecord) -> TimelineItem {
        TimelineItem(
            id: "calendar:\(record.identifier)",
            sourceIdentifier: record.identifier,
            title: record.title,
            startDate: record.startDate,
            endDate: record.endDate,
            isAllDay: record.isAllDay,
            source: .calendar,
            kind: .unknown,
            location: record.location,
            notes: record.notes
        )
    }

    func mapReminder(
        _ record: ReminderRecord,
        durationMinutes: Int
    ) -> TimelineItem? {
        guard let dueDate = record.dueDate else {
            return nil
        }

        let normalizedDuration = durationMinutes > 0 ? durationMinutes : 30

        return TimelineItem(
            id: "reminder:\(record.identifier)",
            sourceIdentifier: record.identifier,
            title: record.title,
            startDate: dueDate,
            endDate: dueDate.addingTimeInterval(
                TimeInterval(normalizedDuration * 60)
            ),
            isAllDay: false,
            source: .reminder,
            kind: .unknown,
            location: nil,
            notes: record.notes
        )
    }
}

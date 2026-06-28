import Foundation

public enum TimelineDateScope: String, CaseIterable, Sendable {
    case today
    case future
    case history

    public static func classify(
        _ item: TimelineItem,
        calendar: Calendar,
        now: Date
    ) -> TimelineDateScope {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: startOfToday
        ) else {
            return item.startDate >= startOfToday ? .future : .history
        }

        let effectiveEnd = item.endDate.flatMap { endDate in
            endDate > item.startDate ? endDate : nil
        } ?? item.startDate.addingTimeInterval(0.001)

        if item.startDate < startOfTomorrow, effectiveEnd > startOfToday {
            return .today
        }

        return item.startDate >= startOfTomorrow ? .future : .history
    }
}

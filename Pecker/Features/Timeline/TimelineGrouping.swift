import Foundation
import PeckerCore

enum TimelineGrouping {
    struct Section: Equatable, Identifiable {
        enum Kind: Equatable {
            case overdue
            case allDay
            case active
            case upcoming
            case elapsed
            case date(Date)
        }

        let kind: Kind
        let title: String
        let items: [TimelineItem]

        var id: String {
            switch kind {
            case .overdue: "overdue"
            case .allDay: "allDay"
            case .active: "active"
            case .upcoming: "upcoming"
            case .elapsed: "elapsed"
            case let .date(day): "date-\(day.timeIntervalSince1970)"
            }
        }
    }

    static func sections(
        items: [TimelineItem],
        now: Date,
        activeOnly: Bool = false,
        localizer: AppLocalizer = AppLocalizer(language: .system)
    ) -> [Section] {
        let sortedItems = items.sorted(by: sortItems(_:_:))

        let overdue = sortedItems.filter { isOverdueReminder($0, now: now) }
        let allDay = sortedItems.filter { $0.isAllDay }
        let active = sortedItems.filter { isActive($0, now: now) }
        let upcoming = sortedItems.filter { isUpcoming($0, now: now) }
        let elapsed = sortedItems.filter { isElapsed($0, now: now) }

        let sections: [Section] = [
            makeSection(kind: .overdue, title: localizer.string("timeline.section.overdue"), items: overdue),
            makeSection(kind: .allDay, title: localizer.string("timeline.section.allDay"), items: allDay),
            makeSection(kind: .active, title: localizer.string("timeline.section.active"), items: active),
            makeSection(kind: .upcoming, title: localizer.string("timeline.section.upcoming"), items: upcoming),
            makeSection(kind: .elapsed, title: localizer.string("timeline.section.elapsed"), items: elapsed)
        ]

        return activeOnly
            ? sections.filter { $0.kind == .active && !$0.items.isEmpty }
            : sections.filter { !$0.items.isEmpty }
    }

    static func isActive(_ item: TimelineItem, now: Date) -> Bool {
        guard !item.isAllDay, let endDate = item.endDate else {
            return false
        }

        return item.startDate <= now && endDate > now
    }

    static func dateSections(
        items: [TimelineItem],
        calendar: Calendar,
        descending: Bool,
        localizer: AppLocalizer = AppLocalizer(language: .system)
    ) -> [Section] {
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.startDate)
        }
        let days = grouped.keys.sorted {
            descending ? $0 > $1 : $0 < $1
        }

        return days.compactMap { day in
            guard let items = grouped[day] else {
                return nil
            }
            return Section(
                kind: .date(day),
                title: dateTitle(for: day, localizer: localizer),
                items: sortedDateItems(items, descending: descending)
            )
        }
    }

    private static func isOverdueReminder(_ item: TimelineItem, now: Date) -> Bool {
        guard !item.isAllDay, item.source == .reminder else {
            return false
        }

        guard let endDate = item.endDate else {
            return item.startDate < now
        }

        return item.startDate < now && endDate <= now
    }

    private static func isUpcoming(_ item: TimelineItem, now: Date) -> Bool {
        guard !item.isAllDay else {
            return false
        }

        if isOverdueReminder(item, now: now) {
            return false
        }

        return item.startDate > now
    }

    private static func isElapsed(_ item: TimelineItem, now: Date) -> Bool {
        guard !item.isAllDay else {
            return false
        }

        if isOverdueReminder(item, now: now) || isActive(item, now: now) || isUpcoming(item, now: now) {
            return false
        }

        guard let endDate = item.endDate else {
            return item.source != .reminder && item.startDate <= now
        }

        return endDate <= now
    }

    private static func sortItems(_ lhs: TimelineItem, _ rhs: TimelineItem) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }

        let lhsEnd = lhs.endDate ?? .distantFuture
        let rhsEnd = rhs.endDate ?? .distantFuture
        if lhsEnd != rhsEnd {
            return lhsEnd < rhsEnd
        }

        if lhs.title != rhs.title {
            return lhs.title < rhs.title
        }

        return lhs.id < rhs.id
    }

    private static func sortedDateItems(
        _ items: [TimelineItem],
        descending: Bool
    ) -> [TimelineItem] {
        let sorted = items.sorted(by: sortItems(_:_:))
        return descending ? Array(sorted.reversed()) : sorted
    }

    private static func makeSection(
        kind: Section.Kind,
        title: String,
        items: [TimelineItem]
    ) -> Section {
        Section(
            kind: kind,
            title: title,
            items: items.sorted(by: sortItems(_:_:))
        )
    }

    private static func dateTitle(
        for day: Date,
        localizer: AppLocalizer
    ) -> String {
        day.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .weekday(.wide)
                .locale(localizer.locale)
        )
    }
}

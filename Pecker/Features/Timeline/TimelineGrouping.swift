import Foundation
import PeckerCore

enum TimelineGrouping {
    struct Section: Equatable, Identifiable {
        enum Kind: String, CaseIterable, Equatable {
            case overdue
            case allDay
            case active
            case upcoming
            case elapsed
        }

        let kind: Kind
        let title: String
        let items: [TimelineItem]

        var id: Kind { kind }
    }

    static func sections(
        items: [TimelineItem],
        now: Date,
        activeOnly: Bool = false
    ) -> [Section] {
        let sortedItems = items.sorted(by: sortItems(_:_:))

        let overdue = sortedItems.filter { isOverdueReminder($0, now: now) }
        let allDay = sortedItems.filter { $0.isAllDay }
        let active = sortedItems.filter { isActive($0, now: now) }
        let upcoming = sortedItems.filter { isUpcoming($0, now: now) }
        let elapsed = sortedItems.filter { isElapsed($0, now: now) }

        let sections: [Section] = [
            makeSection(kind: .overdue, title: "\u{5df2}\u{903e}\u{671f}", items: overdue),
            makeSection(kind: .allDay, title: "\u{5168}\u{5929}", items: allDay),
            makeSection(kind: .active, title: "\u{8fdb}\u{884c}\u{4e2d}", items: active),
            makeSection(kind: .upcoming, title: "\u{5373}\u{5c06}\u{5f00}\u{59cb}", items: upcoming),
            makeSection(kind: .elapsed, title: "\u{5df2}\u{7ed3}\u{675f}", items: elapsed)
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
            return false
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
}

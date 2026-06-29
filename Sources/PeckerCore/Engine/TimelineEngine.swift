import Foundation

public struct TimelineEngine: Sendable {
    private let classifier: TimelineClassifier
    private let templateFactory: EventTemplateFactory

    public init(
        classifier: TimelineClassifier = .init(),
        templateFactory: EventTemplateFactory = .init()
    ) {
        self.classifier = classifier
        self.templateFactory = templateFactory
    }

    public func makeSnapshot(
        items: [TimelineItem],
        now: Date,
        settings: TimelineSettings,
        staleInterval: TimeInterval
    ) -> TodaySnapshot {
        let snapshotItems = items
            .filter { item in
                switch item.source {
                case .calendar:
                    settings.calendarEnabled
                case .reminder:
                    settings.remindersEnabled
                case .external:
                    true
                }
            }
            .map { item in
                guard item.kind == .unknown else {
                    return item
                }

                let template = templateFactory.makeTemplate(
                    from: ClassificationInput(
                        title: item.title,
                        location: item.location,
                        notes: item.notes
                    )
                )
                return TimelineItem(
                    id: item.id,
                    sourceIdentifier: item.sourceIdentifier,
                    title: item.title,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    isAllDay: item.isAllDay,
                    source: item.source,
                    kind: template?.kind ?? classifier.classify(
                        title: item.title,
                        location: item.location,
                        notes: item.notes,
                        source: item.source
                    ),
                    location: item.location,
                    notes: item.notes,
                    template: template
                )
            }
            .map { item in
                guard !settings.showTravelEvents,
                      item.kind == .flight
                        || item.kind == .train
                        || item.kind == .travel
                else {
                    return item
                }

                return TimelineItem(
                    id: item.id,
                    sourceIdentifier: item.sourceIdentifier,
                    title: item.title,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    isAllDay: item.isAllDay,
                    source: item.source,
                    kind: .unknown,
                    location: item.location,
                    notes: item.notes,
                    template: nil
                )
            }
            .sorted(by: itemSortsBefore)

        let activeItems = snapshotItems
            .filter { item in
                guard !item.isAllDay, let endDate = item.endDate else {
                    return false
                }

                return item.startDate <= now && endDate > now
            }
            .sorted(by: nowItemSortsBefore)
        let nextItem = snapshotItems.first { item in
            !item.isAllDay && item.startDate > now
        }
        let automaticPinnedItem = snapshotItems
            .filter { item in
                isUnfinished(item, at: now)
                    && automaticPinPriority(for: item.kind) != nil
            }
            .sorted(by: automaticPinSortsBefore)
            .first
        let pinnedItem: TimelineItem?
        let pinOrigin: PinOrigin?
        if let manualPinnedSourceIdentifier =
            settings.manualPinnedSourceIdentifier,
           let manualPinnedItem = snapshotItems.first(where: { item in
               item.sourceIdentifier == manualPinnedSourceIdentifier
                   && isUnfinished(item, at: now)
           })
        {
            pinnedItem = manualPinnedItem
            pinOrigin = .manual
        } else if let automaticPinnedItem {
            pinnedItem = automaticPinnedItem
            pinOrigin = .automatic
        } else {
            pinnedItem = nil
            pinOrigin = nil
        }

        return TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: now,
            staleAfter: now.addingTimeInterval(staleInterval),
            items: snapshotItems,
            nowItemID: activeItems.first?.id,
            concurrentNowCount: max(0, activeItems.count - 1),
            nextItemID: nextItem?.id,
            pinnedItemID: pinnedItem?.id,
            pinOrigin: pinOrigin
        )
    }

    private func isUnfinished(_ item: TimelineItem, at now: Date) -> Bool {
        if let endDate = item.endDate {
            return endDate > now
        }

        return item.startDate >= now
    }

    private func automaticPinSortsBefore(
        _ left: TimelineItem,
        _ right: TimelineItem
    ) -> Bool {
        let leftPriority = automaticPinPriority(for: left.kind)!
        let rightPriority = automaticPinPriority(for: right.kind)!
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        return itemSortsBefore(left, right)
    }

    private func automaticPinPriority(for kind: TimelineKind) -> Int? {
        switch kind {
        case .flight:
            0
        case .train:
            1
        case .interview:
            2
        case .meeting:
            3
        case .deadline:
            4
        case .task, .travel, .unknown:
            nil
        }
    }

    private func itemSortsBefore(
        _ left: TimelineItem,
        _ right: TimelineItem
    ) -> Bool {
        if left.startDate != right.startDate {
            return left.startDate < right.startDate
        }

        let leftEnd = left.endDate ?? .distantFuture
        let rightEnd = right.endDate ?? .distantFuture
        if leftEnd != rightEnd {
            return leftEnd < rightEnd
        }

        if left.title != right.title {
            return left.title < right.title
        }

        return false
    }

    private func nowItemSortsBefore(
        _ left: TimelineItem,
        _ right: TimelineItem
    ) -> Bool {
        let leftPriority = priority(for: left.kind)
        let rightPriority = priority(for: right.kind)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }

        let leftEnd = left.endDate ?? .distantFuture
        let rightEnd = right.endDate ?? .distantFuture
        if leftEnd != rightEnd {
            return leftEnd < rightEnd
        }

        if left.startDate != right.startDate {
            return left.startDate < right.startDate
        }

        if left.title != right.title {
            return left.title < right.title
        }

        return false
    }

    private func priority(for kind: TimelineKind) -> Int {
        switch kind {
        case .flight:
            0
        case .train:
            1
        case .interview:
            2
        case .meeting:
            3
        case .deadline:
            4
        case .task:
            5
        case .travel, .unknown:
            6
        }
    }
}

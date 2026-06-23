import Foundation

public enum PinOrigin: String, Codable, Sendable {
    case automatic, manual
}

public struct TodaySnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Date
    public let staleAfter: Date
    public let items: [TimelineItem]
    public let nowItemID: String?
    public let concurrentNowCount: Int
    public let nextItemID: String?
    public let pinnedItemID: String?
    public let pinOrigin: PinOrigin?

    public init(
        schemaVersion: Int,
        generatedAt: Date,
        staleAfter: Date,
        items: [TimelineItem],
        nowItemID: String?,
        concurrentNowCount: Int,
        nextItemID: String?,
        pinnedItemID: String?,
        pinOrigin: PinOrigin?
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.staleAfter = staleAfter
        self.items = items
        self.nowItemID = nowItemID
        self.concurrentNowCount = concurrentNowCount
        self.nextItemID = nextItemID
        self.pinnedItemID = pinnedItemID
        self.pinOrigin = pinOrigin
    }

    public func isStale(at date: Date) -> Bool {
        date >= staleAfter
    }
}

public extension TodaySnapshot {
    func item(resolving identifier: String?) -> TimelineItem? {
        guard let identifier else {
            return nil
        }

        return items.first { $0.id == identifier }
    }

    var resolvedNowItem: TimelineItem? {
        item(resolving: nowItemID)
    }

    var resolvedNextItem: TimelineItem? {
        item(resolving: nextItemID)
    }

    var resolvedPinnedItem: TimelineItem? {
        item(resolving: pinnedItemID)
    }
}

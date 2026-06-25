import Foundation

public enum TimelineSource: String, Codable, Sendable {
    case calendar, reminder, external
}

public enum TimelineKind: String, Codable, Sendable {
    case meeting, task, flight, train, travel, interview, deadline, unknown
}

extension TimelineKind: CaseIterable {}

public struct TimelineItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceIdentifier: String
    public let title: String
    public let startDate: Date
    public let endDate: Date?
    public let isAllDay: Bool
    public let source: TimelineSource
    public let kind: TimelineKind
    public let location: String?
    public let notes: String?
    public let template: TimelineEventTemplate?

    public init(
        id: String,
        sourceIdentifier: String,
        title: String,
        startDate: Date,
        endDate: Date?,
        isAllDay: Bool,
        source: TimelineSource,
        kind: TimelineKind,
        location: String?,
        notes: String?,
        template: TimelineEventTemplate? = nil
    ) {
        self.id = id
        self.sourceIdentifier = sourceIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.source = source
        self.kind = kind
        self.location = location
        self.notes = notes
        self.template = template
    }
}

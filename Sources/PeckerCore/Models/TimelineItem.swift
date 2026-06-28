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
    public let isCompleted: Bool

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
        template: TimelineEventTemplate? = nil,
        isCompleted: Bool = false
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
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceIdentifier
        case title
        case startDate
        case endDate
        case isAllDay
        case source
        case kind
        case location
        case notes
        case template
        case isCompleted
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceIdentifier = try container.decode(String.self, forKey: .sourceIdentifier)
        title = try container.decode(String.self, forKey: .title)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isAllDay = try container.decode(Bool.self, forKey: .isAllDay)
        source = try container.decode(TimelineSource.self, forKey: .source)
        kind = try container.decode(TimelineKind.self, forKey: .kind)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        template = try container.decodeIfPresent(
            TimelineEventTemplate.self,
            forKey: .template
        )
        isCompleted = try container.decodeIfPresent(
            Bool.self,
            forKey: .isCompleted
        ) ?? false
    }
}

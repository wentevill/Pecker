import Foundation

public struct EventCustomField:
    Codable, Sendable, Equatable, Hashable, Identifiable
{
    public let id: String
    public var name: String
    public var value: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        value: String
    ) {
        self.id = id
        self.name = name
        self.value = value
    }

    public static func legacy(name: String, value: String) -> Self {
        .init(id: "legacy:\(name)", name: name, value: value)
    }
}

public struct StoredEventRecord: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let source: RecognitionSource
    public let sourceIdentifier: String?
    public let rawTitle: String?
    public let rawLocation: String?
    public let rawNotes: String?
    public let imageReference: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool
    public let template: TimelineEventTemplate?
    public let recognitionStatus: RecognitionStatus
    public let updatedAt: Date
    public let customFields: [EventCustomField]

    public init(
        id: String,
        source: RecognitionSource,
        sourceIdentifier: String?,
        rawTitle: String?,
        rawLocation: String?,
        rawNotes: String?,
        imageReference: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool = false,
        template: TimelineEventTemplate?,
        recognitionStatus: RecognitionStatus,
        updatedAt: Date,
        customFields: [EventCustomField] = []
    ) {
        self.id = id
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.rawTitle = rawTitle
        self.rawLocation = rawLocation
        self.rawNotes = rawNotes
        self.imageReference = imageReference
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.template = template
        self.recognitionStatus = recognitionStatus
        self.updatedAt = updatedAt
        self.customFields = customFields
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceIdentifier
        case rawTitle
        case rawLocation
        case rawNotes
        case imageReference
        case startDate
        case endDate
        case isAllDay
        case template
        case recognitionStatus
        case updatedAt
        case customFields
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try container.decode(RecognitionSource.self, forKey: .source)
        sourceIdentifier = try container.decodeIfPresent(
            String.self,
            forKey: .sourceIdentifier
        )
        rawTitle = try container.decodeIfPresent(String.self, forKey: .rawTitle)
        rawLocation = try container.decodeIfPresent(
            String.self,
            forKey: .rawLocation
        )
        rawNotes = try container.decodeIfPresent(String.self, forKey: .rawNotes)
        imageReference = try container.decodeIfPresent(
            String.self,
            forKey: .imageReference
        )
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        isAllDay = try container.decodeIfPresent(
            Bool.self,
            forKey: .isAllDay
        ) ?? false
        template = try container.decodeIfPresent(
            TimelineEventTemplate.self,
            forKey: .template
        )
        recognitionStatus = try container.decode(
            RecognitionStatus.self,
            forKey: .recognitionStatus
        )
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        customFields = try container.decodeIfPresent(
            [EventCustomField].self,
            forKey: .customFields
        ) ?? []
    }
}

public actor EventRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL) {
        fileURL = directoryURL.appendingPathComponent("events.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    public func loadAll() throws -> [StoredEventRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([StoredEventRecord].self, from: data)
            .sorted { $0.updatedAt < $1.updatedAt }
    }

    public func load(source: RecognitionSource) throws -> [StoredEventRecord] {
        try loadAll().filter { $0.source == source }
    }

    public func record(id: String) throws -> StoredEventRecord? {
        try loadAll().first { $0.id == id }
    }

    public func upsert(_ record: StoredEventRecord) throws {
        var records = try loadAll().filter { $0.id != record.id }
        records.append(record)
        try save(records)
    }

    public func delete(source: RecognitionSource) throws {
        try save(loadAll().filter { $0.source != source })
    }

    public func delete(id: String) throws {
        try save(loadAll().filter { $0.id != id })
    }

    public func deleteAll() throws {
        try save([])
    }

    private func save(_ records: [StoredEventRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(records.sorted { $0.updatedAt < $1.updatedAt })
        try data.write(to: fileURL, options: .atomic)
    }
}

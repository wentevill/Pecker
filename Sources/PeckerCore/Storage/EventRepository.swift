import Foundation

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
    public let template: TimelineEventTemplate?
    public let recognitionStatus: RecognitionStatus
    public let updatedAt: Date

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
        template: TimelineEventTemplate?,
        recognitionStatus: RecognitionStatus,
        updatedAt: Date
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
        self.template = template
        self.recognitionStatus = recognitionStatus
        self.updatedAt = updatedAt
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

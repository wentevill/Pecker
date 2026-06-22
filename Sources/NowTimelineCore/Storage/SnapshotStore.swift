import Foundation

public enum SnapshotLoadResult: Sendable {
    case value(TodaySnapshot)
    case missing
    case corrupt
    case unsupportedSchema(Int)
}

public actor SnapshotStore {
    private let directoryURL: URL
    private let fileURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        fileURL = directoryURL.appendingPathComponent("today_snapshot.json")
    }

    public func load() -> SnapshotLoadResult {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError
            where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            return .corrupt
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970

        do {
            let snapshot = try decoder.decode(TodaySnapshot.self, from: data)
            guard snapshot.schemaVersion == TodaySnapshot.currentSchemaVersion else {
                return .unsupportedSchema(snapshot.schemaVersion)
            }
            return .value(snapshot)
        } catch {
            return .corrupt
        }
    }

    public func save(_ snapshot: TodaySnapshot) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}

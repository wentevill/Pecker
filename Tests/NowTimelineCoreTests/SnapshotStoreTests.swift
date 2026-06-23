import Foundation
import Testing
@testable import NowTimelineCore

@Suite struct SnapshotStoreTests {
    @Test func savesAndLoadsSnapshot() async throws {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = SnapshotStore(directoryURL: directoryURL)
        let expected = snapshot(generatedAtMilliseconds: 1_000)

        try await store.save(expected)
        let result = await store.load()

        guard case let .value(actual) = result else {
            Issue.record("Expected a saved snapshot, got \(result)")
            return
        }
        #expect(actual == expected)
    }

    @Test func reportsMissingSnapshot() async {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = SnapshotStore(directoryURL: directoryURL)

        let result = await store.load()

        guard case .missing = result else {
            Issue.record("Expected a missing snapshot, got \(result)")
            return
        }
    }

    @Test func reportsCorruptSnapshot() async throws {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(
            to: directoryURL.appendingPathComponent("today_snapshot.json")
        )
        let store = SnapshotStore(directoryURL: directoryURL)

        let result = await store.load()

        guard case .corrupt = result else {
            Issue.record("Expected a corrupt snapshot, got \(result)")
            return
        }
    }

    @Test func rejectsUnsupportedSchema() async throws {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let unsupported = snapshot(
            schemaVersion: 999,
            generatedAtMilliseconds: 2_000
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try encoder.encode(unsupported).write(
            to: directoryURL.appendingPathComponent("today_snapshot.json")
        )
        let store = SnapshotStore(directoryURL: directoryURL)

        let result = await store.load()

        guard case let .unsupportedSchema(version) = result else {
            Issue.record("Expected an unsupported schema, got \(result)")
            return
        }
        #expect(version == 999)
    }

    @Test func rejectsUnsupportedSchemaBeforeDecodingCurrentModel() async throws {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let json = #"{"schemaVersion":999,"futurePayload":{"x":1}}"#
        try Data(json.utf8).write(
            to: directoryURL.appendingPathComponent("today_snapshot.json")
        )
        let store = SnapshotStore(directoryURL: directoryURL)

        let result = await store.load()

        guard case let .unsupportedSchema(version) = result else {
            Issue.record("Expected an unsupported schema, got \(result)")
            return
        }
        #expect(version == 999)
    }

    @Test func saveCreatesDirectoryAndReplacesPreviousSnapshot() async throws {
        let directoryURL = temporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let store = SnapshotStore(directoryURL: directoryURL)
        let first = snapshot(generatedAtMilliseconds: 3_000)
        let second = snapshot(generatedAtMilliseconds: 4_000)

        try await store.save(first)
        #expect(FileManager.default.fileExists(atPath: directoryURL.path))

        try await store.save(second)
        let result = await store.load()

        guard case let .value(actual) = result else {
            Issue.record("Expected the replacement snapshot, got \(result)")
            return
        }
        #expect(actual == second)
    }
}

private func temporaryDirectoryURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func snapshot(
    schemaVersion: Int = TodaySnapshot.currentSchemaVersion,
    generatedAtMilliseconds: TimeInterval
) -> TodaySnapshot {
    let generatedAt = Date(
        timeIntervalSince1970: generatedAtMilliseconds / 1_000
    )
    return TodaySnapshot(
        schemaVersion: schemaVersion,
        generatedAt: generatedAt,
        staleAfter: generatedAt.addingTimeInterval(900),
        items: [],
        nowItemID: nil,
        concurrentNowCount: 0,
        nextItemID: nil,
        pinnedItemID: nil,
        pinOrigin: nil
    )
}

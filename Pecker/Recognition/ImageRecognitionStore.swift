import Foundation
import PeckerCore

protocol ImageFileStoring: Sendable {
    func saveImage(data: Data, filename: String?, source: RecognitionSource) throws -> String
    func deleteImage(at relativePath: String) throws
}

enum ImageRecognitionStoreError: Error {
    case invalidImageReference
}

struct ImageRecognitionStore: ImageFileStoring {
    private let directoryURL: URL

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    func saveImage(
        data: Data,
        filename: String?,
        source: RecognitionSource
    ) throws -> String {
        let extensionText = Self.fileExtension(from: filename)
        let imageID = UUID().uuidString
        let relativePath = "Images/\(source.rawValue)-\(imageID).\(extensionText)"
        let fileURL = directoryURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        return relativePath
    }

    func deleteImage(at relativePath: String) throws {
        let rootURL = directoryURL.standardizedFileURL
        let fileURL = directoryURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        guard fileURL.path.hasPrefix(rootURL.path + "/") else {
            throw ImageRecognitionStoreError.invalidImageReference
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func fileExtension(from filename: String?) -> String {
        guard let filename else {
            return "jpg"
        }
        let value = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch value {
        case "png", "webp", "jpg", "jpeg":
            return value
        default:
            return "jpg"
        }
    }
}

protocol ImageRecognizing: Sendable {
    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft
    ) async throws -> StoredEventRecord
}

actor NoopImageRecognizer: ImageRecognizing {
    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        throw RecognitionError.unsupportedInput
    }

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft
    ) async throws -> StoredEventRecord {
        throw RecognitionError.unsupportedInput
    }
}

struct ImageRecognitionCoordinator: ImageRecognizing {
    private let imageStore: any ImageFileStoring
    private let systemCoordinator: SystemEventRecognitionCoordinator

    init(
        imageStore: any ImageFileStoring,
        systemCoordinator: SystemEventRecognitionCoordinator
    ) {
        self.imageStore = imageStore
        self.systemCoordinator = systemCoordinator
    }

    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        return try await systemCoordinator.recognizeImage(
            data: data,
            source: source,
            filename: filename,
            settings: settings,
            now: now
        )
    }

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft
    ) async throws -> StoredEventRecord {
        let imageReference = try imageStore.saveImage(
            data: draft.imageData,
            filename: draft.filename,
            source: draft.source
        )
        do {
            return try await systemCoordinator.saveRecognizedImage(
                draft,
                imageReference: imageReference
            )
        } catch {
            try? imageStore.deleteImage(at: imageReference)
            throw error
        }
    }
}

enum LocalTimelineCardError: Error, Equatable {
    case recordNotFound
    case readOnlySource
    case imageCleanupFailed
}

protocol LocalTimelineCardManaging: Sendable {
    func loadAll() async throws -> [StoredEventRecord]
    func update(_ record: StoredEventRecord) async throws
    func delete(id: String) async throws
}

actor NoopLocalTimelineCardService: LocalTimelineCardManaging {
    func loadAll() async throws -> [StoredEventRecord] { [] }
    func update(_ record: StoredEventRecord) async throws {
        throw LocalTimelineCardError.readOnlySource
    }
    func delete(id: String) async throws {
        throw LocalTimelineCardError.recordNotFound
    }
}

struct LocalTimelineCardService: LocalTimelineCardManaging {
    private let repository: any EventRepositoryStoring
    private let imageStore: any ImageFileStoring

    init(
        repository: any EventRepositoryStoring,
        imageStore: any ImageFileStoring
    ) {
        self.repository = repository
        self.imageStore = imageStore
    }

    func loadAll() async throws -> [StoredEventRecord] {
        try await repository.loadAll().filter(Self.isMutable)
    }

    func update(_ record: StoredEventRecord) async throws {
        guard Self.isMutable(record) else {
            throw LocalTimelineCardError.readOnlySource
        }
        try await repository.upsert(record)
    }

    func delete(id: String) async throws {
        guard let record = try await repository.loadAll().first(where: {
            $0.id == id
        }) else {
            throw LocalTimelineCardError.recordNotFound
        }
        guard Self.isMutable(record) else {
            throw LocalTimelineCardError.readOnlySource
        }
        try await repository.delete(id: id)
        if let imageReference = record.imageReference {
            do {
                try imageStore.deleteImage(at: imageReference)
            } catch {
                throw LocalTimelineCardError.imageCleanupFailed
            }
        }
    }

    private static func isMutable(_ record: StoredEventRecord) -> Bool {
        record.source == .importedImage || record.source == .cameraImage
    }
}

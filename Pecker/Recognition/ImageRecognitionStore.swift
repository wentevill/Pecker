import Foundation
import PeckerCore

protocol ImageFileStoring: Sendable {
    func saveImage(data: Data, filename: String?, source: RecognitionSource) throws -> String
    func deleteImage(at relativePath: String) throws
    func quarantineImage(at relativePath: String) throws -> QuarantinedImage
    func restoreImage(_ image: QuarantinedImage) throws
    func removeQuarantinedImage(_ image: QuarantinedImage) throws
}

struct QuarantinedImage: Sendable, Equatable {
    let originalPath: String
    let quarantinePath: String
}

extension ImageFileStoring {
    func quarantineImage(at relativePath: String) throws -> QuarantinedImage {
        try deleteImage(at: relativePath)
        return .init(
            originalPath: relativePath,
            quarantinePath: relativePath
        )
    }

    func restoreImage(_ image: QuarantinedImage) throws {}
    func removeQuarantinedImage(_ image: QuarantinedImage) throws {}
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
        guard filename?.lowercased().hasSuffix(".jpg") == true else {
            throw ImageRecognitionStoreError.invalidImageReference
        }
        let imageID = UUID().uuidString
        let relativePath = "Images/\(source.rawValue)-\(imageID).jpg"
        let fileURL = directoryURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        return relativePath
    }

    func deleteImage(at relativePath: String) throws {
        let fileURL = try validatedFileURL(for: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    func quarantineImage(
        at relativePath: String
    ) throws -> QuarantinedImage {
        let sourceURL = try validatedFileURL(for: relativePath)
        let quarantinePath =
            "Images/.Trash/\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
        let quarantineURL = try validatedFileURL(for: quarantinePath)
        try FileManager.default.createDirectory(
            at: quarantineURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            try FileManager.default.moveItem(at: sourceURL, to: quarantineURL)
        }
        return .init(
            originalPath: relativePath,
            quarantinePath: quarantinePath
        )
    }

    func restoreImage(_ image: QuarantinedImage) throws {
        let sourceURL = try validatedFileURL(for: image.quarantinePath)
        let destinationURL = try validatedFileURL(for: image.originalPath)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return
        }
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    func removeQuarantinedImage(_ image: QuarantinedImage) throws {
        let fileURL = try validatedFileURL(for: image.quarantinePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func validatedFileURL(for relativePath: String) throws -> URL {
        let rootURL = directoryURL.standardizedFileURL
        let fileURL = directoryURL
            .appendingPathComponent(relativePath)
            .standardizedFileURL
        guard fileURL.path.hasPrefix(rootURL.path + "/") else {
            throw ImageRecognitionStoreError.invalidImageReference
        }
        return fileURL
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

    func recognizeImage(
        _ image: PreparedRecognitionImage,
        source: RecognitionSource,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft

    func recognizeImages(
        _ images: [PreparedRecognitionImage],
        source: RecognitionSource,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft
    ) async throws -> StoredEventRecord
}

extension ImageRecognizing {
    func recognizeImage(
        _ image: PreparedRecognitionImage,
        source: RecognitionSource,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        try await recognizeImages(
            [image],
            source: source,
            settings: settings,
            now: now
        )
    }
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

    func recognizeImages(
        _ images: [PreparedRecognitionImage],
        source: RecognitionSource,
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

    func recognizeImage(
        _ image: PreparedRecognitionImage,
        source: RecognitionSource,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        try await systemCoordinator.recognizeImage(
            image,
            source: source,
            settings: settings,
            now: now
        )
    }

    func recognizeImages(
        _ images: [PreparedRecognitionImage],
        source: RecognitionSource,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        try await systemCoordinator.recognizeImages(
            images,
            source: source,
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
        let quarantined: QuarantinedImage?
        if let imageReference = record.imageReference {
            quarantined = try? imageStore.quarantineImage(at: imageReference)
        } else {
            quarantined = nil
        }
        do {
            try await repository.delete(id: id)
        } catch {
            if let quarantined {
                try? imageStore.restoreImage(quarantined)
            }
            throw error
        }
        if let quarantined {
            try? imageStore.removeQuarantinedImage(quarantined)
        }
    }

    private static func isMutable(_ record: StoredEventRecord) -> Bool {
        record.source == .importedImage || record.source == .cameraImage
    }
}

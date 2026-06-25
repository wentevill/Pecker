import Foundation
import PeckerCore

protocol ImageFileStoring: Sendable {
    func saveImage(data: Data, filename: String?, source: RecognitionSource) throws -> String
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
    ) async throws -> StoredEventRecord
}

actor NoopImageRecognizer: ImageRecognizing {
    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
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
    ) async throws -> StoredEventRecord {
        let imageReference = try imageStore.saveImage(
            data: data,
            filename: filename,
            source: source
        )
        return try await systemCoordinator.recognizeImage(
            data: data,
            source: source,
            filename: filename,
            imageReference: imageReference,
            settings: settings,
            now: now
        )
    }
}

import Foundation

public enum AIRecognitionMode: String, Codable, Sendable, Equatable, CaseIterable {
    case off
    case openAI
    case localModel
}

public enum RecognitionSource: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case calendar
    case reminder
    case importedImage
    case cameraImage
}

public struct RecognitionInput: Sendable, Equatable {
    public let id: String
    public let source: RecognitionSource
    public let sourceIdentifier: String?
    public let title: String?
    public let location: String?
    public let notes: String?
    public let startDate: Date?
    public let endDate: Date?
    public let isAllDay: Bool
    public let imageData: Data?
    public let filename: String?

    public init(
        id: String,
        source: RecognitionSource,
        sourceIdentifier: String?,
        title: String?,
        location: String?,
        notes: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        imageData: Data?,
        filename: String?
    ) {
        self.id = id
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.title = title
        self.location = location
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.imageData = imageData
        self.filename = filename
    }

    public static func calendar(
        sourceIdentifier: String,
        title: String,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool,
        location: String?,
        notes: String?
    ) -> RecognitionInput {
        RecognitionInput(
            id: "calendar:\(sourceIdentifier)",
            source: .calendar,
            sourceIdentifier: sourceIdentifier,
            title: title,
            location: location,
            notes: notes,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            imageData: nil,
            filename: nil
        )
    }

    public static func reminder(
        sourceIdentifier: String,
        title: String,
        dueDate: Date?,
        endDate: Date?,
        notes: String?
    ) -> RecognitionInput {
        RecognitionInput(
            id: "reminder:\(sourceIdentifier)",
            source: .reminder,
            sourceIdentifier: sourceIdentifier,
            title: title,
            location: nil,
            notes: notes,
            startDate: dueDate,
            endDate: endDate,
            isAllDay: false,
            imageData: nil,
            filename: nil
        )
    }

    public static func importedImage(
        id: String,
        imageData: Data,
        filename: String?
    ) -> RecognitionInput {
        RecognitionInput(
            id: "image:\(id)",
            source: .importedImage,
            sourceIdentifier: id,
            title: filename,
            location: nil,
            notes: nil,
            startDate: nil,
            endDate: nil,
            isAllDay: false,
            imageData: imageData,
            filename: filename
        )
    }

    public static func cameraImage(
        id: String,
        imageData: Data
    ) -> RecognitionInput {
        RecognitionInput(
            id: "camera:\(id)",
            source: .cameraImage,
            sourceIdentifier: id,
            title: nil,
            location: nil,
            notes: nil,
            startDate: nil,
            endDate: nil,
            isAllDay: false,
            imageData: imageData,
            filename: nil
        )
    }
}

public struct RecognitionResult: Sendable, Equatable, Codable {
    public let payload: ExternalEventTemplatePayload
    public let confidence: Double?

    public init(payload: ExternalEventTemplatePayload, confidence: Double?) {
        self.payload = payload
        self.confidence = confidence
    }
}

public enum RecognitionStatus: String, Codable, Sendable, Equatable, Hashable {
    case pending
    case recognized
    case failed
    case disabled
}

public enum RecognitionError: Error, Sendable, Equatable {
    case localModelUnavailable
    case invalidConfiguration
    case unsupportedInput
    case networkExecutionNotImplemented
    case requestFailed
    case imageInputUnsupported
    case invalidResponse
}

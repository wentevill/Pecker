import Foundation

public enum AIRecognitionMode: String, Codable, Sendable, Equatable, CaseIterable {
    case off
    case openAI
}

public enum RecognitionSource: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case calendar
    case reminder
    case importedImage
    case cameraImage
}

public struct RecognitionImageInput: Sendable, Equatable {
    public let data: Data
    public let filename: String?
    public let mimeType: String

    public init(data: Data, filename: String?, mimeType: String) {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }
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
    public let imageMIMEType: String?
    public let images: [RecognitionImageInput]
    public let referenceDate: Date?
    public let timeZoneIdentifier: String?

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
        filename: String?,
        imageMIMEType: String? = nil,
        images: [RecognitionImageInput]? = nil,
        referenceDate: Date? = nil,
        timeZoneIdentifier: String? = nil
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
        self.imageMIMEType = imageMIMEType
        self.images = images ?? imageData.map {
            [
                RecognitionImageInput(
                    data: $0,
                    filename: filename,
                    mimeType: imageMIMEType ?? "image/jpeg"
                )
            ]
        } ?? []
        self.referenceDate = referenceDate
        self.timeZoneIdentifier = timeZoneIdentifier
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
        filename: String?,
        mimeType: String = "image/jpeg",
        referenceDate: Date? = nil,
        timeZoneIdentifier: String? = nil
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
            filename: filename,
            imageMIMEType: mimeType,
            referenceDate: referenceDate,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    public static func importedImages(
        id: String,
        images: [RecognitionImageInput],
        referenceDate: Date? = nil,
        timeZoneIdentifier: String? = nil
    ) -> RecognitionInput {
        imageInput(
            id: "image:\(id)",
            source: .importedImage,
            sourceIdentifier: id,
            images: images,
            referenceDate: referenceDate,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    public static func cameraImage(
        id: String,
        imageData: Data,
        filename: String = "recognition.jpg",
        mimeType: String = "image/jpeg",
        referenceDate: Date? = nil,
        timeZoneIdentifier: String? = nil
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
            filename: filename,
            imageMIMEType: mimeType,
            referenceDate: referenceDate,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    public static func cameraImages(
        id: String,
        images: [RecognitionImageInput],
        referenceDate: Date? = nil,
        timeZoneIdentifier: String? = nil
    ) -> RecognitionInput {
        imageInput(
            id: "camera:\(id)",
            source: .cameraImage,
            sourceIdentifier: id,
            images: images,
            referenceDate: referenceDate,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    private static func imageInput(
        id: String,
        source: RecognitionSource,
        sourceIdentifier: String,
        images: [RecognitionImageInput],
        referenceDate: Date?,
        timeZoneIdentifier: String?
    ) -> RecognitionInput {
        let primary = images.first
        return RecognitionInput(
            id: id,
            source: source,
            sourceIdentifier: sourceIdentifier,
            title: primary?.filename,
            location: nil,
            notes: nil,
            startDate: nil,
            endDate: nil,
            isAllDay: false,
            imageData: primary?.data,
            filename: primary?.filename,
            imageMIMEType: primary?.mimeType,
            images: images,
            referenceDate: referenceDate,
            timeZoneIdentifier: timeZoneIdentifier
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
    case invalidConfiguration
    case unsupportedInput
    case networkExecutionNotImplemented
    case requestFailed
    case imageInputUnsupported
    case invalidResponse
}

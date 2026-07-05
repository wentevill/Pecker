import Foundation
import PeckerCore

protocol EventRepositoryStoring: Sendable {
    func loadAll() async throws -> [StoredEventRecord]
    func upsert(_ record: StoredEventRecord) async throws
    func delete(source: RecognitionSource) async throws
    func delete(id: String) async throws
    func delete(ids: Set<String>) async throws
}

extension EventRepository: EventRepositoryStoring {}

extension EventRepositoryStoring {
    func delete(id: String) async throws {
        throw RecognitionError.unsupportedInput
    }

    func delete(ids: Set<String>) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
}

protocol SystemEventRecognizing: Sendable {
    func cachedSystemTemplates() async -> [String: TimelineEventTemplate]

    func synchronize(
        events: [EventRecord],
        reminders: [ReminderRecord],
        settings: TimelineSettings,
        now: Date
    ) async -> [String: TimelineEventTemplate]

    func recognizedImageItems(
        settings: TimelineSettings,
        now: Date
    ) async -> [TimelineItem]
}

extension SystemEventRecognizing {
    func cachedSystemTemplates() async -> [String: TimelineEventTemplate] {
        [:]
    }
}

actor NoopSystemEventRecognizer: SystemEventRecognizing {
    func synchronize(
        events: [EventRecord],
        reminders: [ReminderRecord],
        settings: TimelineSettings,
        now: Date
    ) async -> [String: TimelineEventTemplate] {
        [:]
    }

    func recognizedImageItems(
        settings: TimelineSettings,
        now: Date
    ) async -> [TimelineItem] {
        []
    }
}

struct ImageRecognitionDraft: Sendable, Equatable, Identifiable {
    let id: String
    let sourceIdentifier: String
    let source: RecognitionSource
    let filename: String?
    let mimeType: String
    let imageData: Data
    let recognizedAt: Date
    let startDate: Date
    let endDate: Date?
    let isAllDay: Bool
    let template: TimelineEventTemplate

    init(
        id: String,
        sourceIdentifier: String,
        source: RecognitionSource,
        filename: String?,
        mimeType: String = "image/jpeg",
        imageData: Data,
        recognizedAt: Date,
        startDate: Date,
        endDate: Date?,
        isAllDay: Bool = false,
        template: TimelineEventTemplate
    ) {
        self.id = id
        self.sourceIdentifier = sourceIdentifier
        self.source = source
        self.filename = filename
        self.mimeType = mimeType
        self.imageData = imageData
        self.recognizedAt = recognizedAt
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.template = template
    }
}

struct SystemEventRecognitionCoordinator: SystemEventRecognizing {
    typealias ProviderFactory = @Sendable (
        TimelineSettings,
        String
    ) -> any RecognitionProvider

    private let repository: any EventRepositoryStoring
    private let apiKeyStore: any APIKeyStoring
    private let templateFactory: EventTemplateFactory
    private let calendar: Calendar
    private let providerFactory: ProviderFactory

    init(
        repository: any EventRepositoryStoring,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        templateFactory: EventTemplateFactory = EventTemplateFactory(),
        calendar: Calendar = .current,
        providerFactory: @escaping ProviderFactory = { settings, apiKey in
            OpenAIRecognitionProvider(
                configuration: .init(
                    host: settings.openAIHost,
                    apiKey: apiKey,
                    model: settings.openAIModel
                )
            )
        }
    ) {
        self.repository = repository
        self.apiKeyStore = apiKeyStore
        self.templateFactory = templateFactory
        self.calendar = calendar
        self.providerFactory = providerFactory
    }

    func cachedSystemTemplates() async -> [String: TimelineEventTemplate] {
        (try? await recognizedTemplates()) ?? [:]
    }

    func synchronize(
        events: [EventRecord],
        reminders: [ReminderRecord],
        settings: TimelineSettings,
        now: Date
    ) async -> [String: TimelineEventTemplate] {
        do {
            let existingTemplates = try await recognizedTemplates()
            var templates = existingTemplates
            let dayStart = calendar.startOfDay(for: now)
            let dayEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: dayStart
            ) ?? dayStart.addingTimeInterval(86_400)
            let interval = DateInterval(start: dayStart, end: dayEnd)

            if settings.syncCalendarToStorage {
                try await removeMissingRecords(
                    source: .calendar,
                    presentIDs: Set(
                        events.map { "calendar:\($0.identifier)" }
                    ),
                    interval: interval
                )
                for event in events {
                    if let template = try? await synchronize(
                        record: storedRecord(from: event, status: .pending, updatedAt: now),
                        input: .calendar(
                            sourceIdentifier: event.identifier,
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            isAllDay: event.isAllDay,
                            location: event.location,
                            notes: event.notes
                        ),
                        settings: settings,
                        now: now,
                        propagatesErrors: false
                    ) {
                        templates["calendar:\(event.identifier)"] = template
                    }
                }
            }

            if settings.syncRemindersToStorage {
                try await removeMissingRecords(
                    source: .reminder,
                    presentIDs: Set(
                        reminders.map { "reminder:\($0.identifier)" }
                    ),
                    interval: interval
                )
                for reminder in reminders {
                    if let template = try? await synchronize(
                        record: storedRecord(
                            from: reminder,
                            status: .pending,
                            updatedAt: now
                        ),
                        input: .reminder(
                            sourceIdentifier: reminder.identifier,
                            title: reminder.title,
                            dueDate: reminder.dueDate,
                            endDate: nil,
                            notes: reminder.notes
                        ),
                        settings: settings,
                        now: now,
                        propagatesErrors: false
                    ) {
                        templates["reminder:\(reminder.identifier)"] = template
                    }
                }
            }

            return templates
        } catch {
            return [:]
        }
    }

    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ImageRecognitionDraft {
        let canonicalFilename = filename ?? "recognition.jpg"
        let lowercasedFilename = canonicalFilename.lowercased()
        let mimeType: String
        if lowercasedFilename.hasSuffix(".png") {
            mimeType = "image/png"
        } else if lowercasedFilename.hasSuffix(".webp") {
            mimeType = "image/webp"
        } else {
            mimeType = "image/jpeg"
        }
        return try await recognizeImage(
            PreparedRecognitionImage(
                data: data,
                filename: canonicalFilename,
                mimeType: mimeType,
                pixelWidth: 0,
                pixelHeight: 0
            ),
            source: source,
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
        let idPrefix = source == .cameraImage ? "camera" : "image"
        let sourceIdentifier = UUID().uuidString
        let input: RecognitionInput = source == .cameraImage
            ? .cameraImage(
                id: sourceIdentifier,
                imageData: image.data,
                filename: image.filename,
                mimeType: image.mimeType,
                referenceDate: now,
                timeZoneIdentifier: calendar.timeZone.identifier
            )
            : .importedImage(
                id: sourceIdentifier,
                imageData: image.data,
                filename: image.filename,
                mimeType: image.mimeType,
                referenceDate: now,
                timeZoneIdentifier: calendar.timeZone.identifier
            )

        guard settings.aiRecognitionMode != .off,
              let provider = provider(for: settings)
        else {
            throw RecognitionError.invalidConfiguration
        }

        let result = try await provider.recognize(input)
        let validation = try RecognizedEventValidator(calendar: calendar)
            .validate(result.payload)
        guard let template = templateFactory.makeTemplate(
            from: validation.payload
        ) else {
            throw RecognitionPipelineFailure(
                stage: .validation,
                reason: "\u{672a}\u{8bc6}\u{522b}\u{5230}\u{53ef}\u{4fdd}\u{5b58}\u{7684}\u{4e8b}\u{4ef6}\u{5185}\u{5bb9}",
                technicalSummary: "\u{6a21}\u{677f}\u{5de5}\u{5382}\u{65e0}\u{6cd5}\u{4ece}\u{6838}\u{5bf9}\u{540e}\u{7684}\u{5b57}\u{6bb5}\u{6784}\u{5efa}\u{4e8b}\u{4ef6}",
                httpStatus: nil,
                serviceCode: nil,
                serviceMessage: nil,
                missingFields: [],
                responseExcerpt: nil
            )
        }

        return ImageRecognitionDraft(
            id: "\(idPrefix):\(sourceIdentifier)",
            sourceIdentifier: sourceIdentifier,
            source: source,
            filename: image.filename,
            mimeType: image.mimeType,
            imageData: image.data,
            recognizedAt: now,
            startDate: validation.startDate,
            endDate: validation.endDate,
            isAllDay: validation.isAllDay,
            template: template
        )
    }

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft,
        imageReference: String
    ) async throws -> StoredEventRecord {
        let editableFields = editableRecordFields(from: draft)
        let record = StoredEventRecord(
            id: draft.id,
            source: draft.source,
            sourceIdentifier: draft.sourceIdentifier,
            rawTitle: editableFields.title,
            rawLocation: editableFields.location,
            rawNotes: editableFields.notes,
            imageReference: imageReference,
            startDate: draft.startDate,
            endDate: draft.endDate,
            isAllDay: draft.isAllDay,
            template: draft.template,
            recognitionStatus: .recognized,
            updatedAt: draft.recognizedAt
        )
        try await repository.upsert(record)
        return record
    }

    func recognizedImageItems(
        settings: TimelineSettings,
        now: Date
    ) async -> [TimelineItem] {
        guard let records = try? await repository.loadAll() else {
            return []
        }

        return records
            .filter { record in
                record.recognitionStatus == .recognized
                    && (record.source == .importedImage || record.source == .cameraImage)
                    && record.template != nil
            }
            .compactMap { timelineItem(from: $0, now: now) }
    }

    private func synchronize(
        record: StoredEventRecord,
        input: RecognitionInput,
        settings: TimelineSettings,
        now: Date,
        propagatesErrors: Bool
    ) async throws -> TimelineEventTemplate? {
        guard settings.aiRecognitionMode != .off else {
            try? await repository.upsert(record.with(status: .disabled, updatedAt: now))
            if propagatesErrors {
                throw RecognitionError.invalidConfiguration
            }
            return nil
        }

        guard let provider = provider(for: settings) else {
            try? await repository.upsert(record.with(status: .failed, updatedAt: now))
            if propagatesErrors {
                throw RecognitionError.invalidConfiguration
            }
            return nil
        }

        do {
            let result = try await provider.recognize(input)
            let template = templateFactory.makeTemplate(from: result.payload)
            guard let template else {
                try? await repository.upsert(record.with(status: .failed, updatedAt: now))
                if propagatesErrors {
                    throw RecognitionError.unsupportedInput
                }
                return nil
            }
            try await repository.upsert(
                record.with(
                    template: template,
                    status: .recognized,
                    updatedAt: now
                )
            )
            return template
        } catch {
            try? await repository.upsert(record.with(status: .failed, updatedAt: now))
            if propagatesErrors {
                throw error
            }
            return nil
        }
    }

    private func provider(for settings: TimelineSettings) -> (any RecognitionProvider)? {
        switch settings.aiRecognitionMode {
        case .openAI:
            guard let apiKey = try? apiKeyStore.loadOpenAIAPIKey(),
                  !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            return providerFactory(settings, apiKey)
        case .off:
            return nil
        }
    }

    private func recognizedTemplates() async throws -> [String: TimelineEventTemplate] {
        let records = try await repository.loadAll()
        return Dictionary(
            uniqueKeysWithValues: records.compactMap { record in
                guard record.recognitionStatus == .recognized,
                      let template = record.template
                else {
                    return nil
                }
                return (record.id, template)
            }
        )
    }

    private func removeMissingRecords(
        source: RecognitionSource,
        presentIDs: Set<String>,
        interval: DateInterval
    ) async throws {
        let records = try await repository.loadAll()
        let staleIDs: [String] = records.compactMap { record in
            guard record.source == source,
                  let start = record.startDate,
                  interval.contains(start),
                  !presentIDs.contains(record.id)
            else {
                return nil
            }
            return record.id
        }
        try await repository.delete(ids: Set(staleIDs))
    }

    private func timelineItem(
        from record: StoredEventRecord,
        now: Date
    ) -> TimelineItem? {
        guard let template = record.template else {
            return nil
        }
        let presentation = template.presentation
        return TimelineItem(
            id: record.id,
            sourceIdentifier: record.sourceIdentifier ?? record.id,
            title: presentation.title,
            startDate: record.startDate ?? now,
            endDate: record.endDate,
            isAllDay: record.isAllDay,
            source: .external,
            kind: template.kind,
            location: record.rawLocation,
            notes: record.rawNotes ?? presentation.subtitle,
            template: template
        )
    }

    private func editableRecordFields(
        from draft: ImageRecognitionDraft
    ) -> (title: String?, location: String?, notes: String?) {
        switch draft.template {
        case let .generic(event):
            (
                title: event.title,
                location: event.location,
                notes: event.notes
            )
        case .trainTicket, .flightTicket:
            (
                title: draft.template.presentation.title,
                location: nil,
                notes: draft.template.presentation.subtitle
            )
        }
    }

    private func storedRecord(
        from event: EventRecord,
        status: RecognitionStatus,
        updatedAt: Date
    ) -> StoredEventRecord {
        StoredEventRecord(
            id: "calendar:\(event.identifier)",
            source: .calendar,
            sourceIdentifier: event.identifier,
            rawTitle: event.title,
            rawLocation: event.location,
            rawNotes: event.notes,
            imageReference: nil,
            startDate: event.startDate,
            endDate: event.endDate,
            template: nil,
            recognitionStatus: status,
            updatedAt: updatedAt
        )
    }

    private func storedRecord(
        from reminder: ReminderRecord,
        status: RecognitionStatus,
        updatedAt: Date
    ) -> StoredEventRecord {
        StoredEventRecord(
            id: "reminder:\(reminder.identifier)",
            source: .reminder,
            sourceIdentifier: reminder.identifier,
            rawTitle: reminder.title,
            rawLocation: nil,
            rawNotes: reminder.notes,
            imageReference: nil,
            startDate: reminder.dueDate,
            endDate: nil,
            template: nil,
            recognitionStatus: status,
            updatedAt: updatedAt
        )
    }
}

private extension StoredEventRecord {
    func with(
        template: TimelineEventTemplate? = nil,
        status: RecognitionStatus,
        updatedAt: Date
    ) -> StoredEventRecord {
        StoredEventRecord(
            id: id,
            source: source,
            sourceIdentifier: sourceIdentifier,
            rawTitle: rawTitle,
            rawLocation: rawLocation,
            rawNotes: rawNotes,
            imageReference: imageReference,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            template: template,
            recognitionStatus: status,
            updatedAt: updatedAt
        )
    }
}

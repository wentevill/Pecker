import Foundation
import PeckerCore

protocol EventRepositoryStoring: Sendable {
    func loadAll() async throws -> [StoredEventRecord]
    func upsert(_ record: StoredEventRecord) async throws
    func delete(source: RecognitionSource) async throws
}

extension EventRepository: EventRepositoryStoring {}

protocol SystemEventRecognizing: Sendable {
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
    let imageData: Data
    let recognizedAt: Date
    let startDate: Date
    let endDate: Date?
    let template: TimelineEventTemplate
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
            switch settings.aiRecognitionMode {
            case .openAI:
                OpenAIRecognitionProvider(
                    configuration: .init(
                        host: settings.openAIHost,
                        apiKey: apiKey,
                        model: settings.openAIModel
                    )
                )
            case .localModel:
                LocalModelRecognitionProvider()
            case .off:
                LocalModelRecognitionProvider()
            }
        }
    ) {
        self.repository = repository
        self.apiKeyStore = apiKeyStore
        self.templateFactory = templateFactory
        self.calendar = calendar
        self.providerFactory = providerFactory
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

            if settings.syncCalendarToStorage {
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
        let idPrefix = source == .cameraImage ? "camera" : "image"
        let sourceIdentifier = UUID().uuidString
        let input: RecognitionInput = source == .cameraImage
            ? .cameraImage(id: sourceIdentifier, imageData: data)
            : .importedImage(id: sourceIdentifier, imageData: data, filename: filename)

        guard settings.aiRecognitionMode != .off,
              let provider = provider(for: settings)
        else {
            throw RecognitionError.invalidConfiguration
        }

        let result = try await provider.recognize(input)
        guard let template = templateFactory.makeTemplate(from: result.payload) else {
            throw RecognitionError.unsupportedInput
        }
        let timing = try RecognizedEventTiming.parse(
            fields: result.payload.fields,
            calendar: calendar
        )

        return ImageRecognitionDraft(
            id: "\(idPrefix):\(sourceIdentifier)",
            sourceIdentifier: sourceIdentifier,
            source: source,
            filename: filename,
            imageData: data,
            recognizedAt: now,
            startDate: timing.startDate,
            endDate: timing.endDate,
            template: template
        )
    }

    func saveRecognizedImage(
        _ draft: ImageRecognitionDraft,
        imageReference: String
    ) async throws -> StoredEventRecord {
        let record = StoredEventRecord(
            id: draft.id,
            source: draft.source,
            sourceIdentifier: draft.sourceIdentifier,
            rawTitle: draft.filename,
            rawLocation: nil,
            rawNotes: nil,
            imageReference: imageReference,
            startDate: draft.startDate,
            endDate: draft.endDate,
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
        case .localModel:
            return providerFactory(settings, "")
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
            isAllDay: false,
            source: .external,
            kind: template.kind,
            location: record.rawLocation,
            notes: record.rawNotes ?? presentation.subtitle,
            template: template
        )
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

private struct RecognizedEventTiming {
    let startDate: Date
    let endDate: Date?

    static func parse(
        fields: [String: String],
        calendar: Calendar
    ) throws -> RecognizedEventTiming {
        let explicitStart = value(
            in: fields,
            keys: ["startDateTime", "start_datetime", "departureDateTime"]
        ).flatMap(parseISO8601)
        let eventDate = value(in: fields, keys: ["eventDate", "event_date", "date"])
        let startTime = value(
            in: fields,
            keys: ["departureTime", "departure_time", "startTime", "start_time"]
        )
        let startDate = explicitStart ?? combine(
            date: eventDate,
            time: startTime,
            calendar: calendar
        )

        guard let startDate else {
            throw RecognitionError.invalidResponse
        }

        let explicitEndText = value(
            in: fields,
            keys: ["endDateTime", "end_datetime", "arrivalDateTime"]
        )
        let explicitEnd = explicitEndText.flatMap(parseISO8601)
        let arrivalDate = value(
            in: fields,
            keys: ["arrivalDate", "arrival_date"]
        )
        let endTime = value(
            in: fields,
            keys: ["arrivalTime", "arrival_time", "endTime", "end_time"]
        )
        var endDate = explicitEnd ?? combine(
            date: arrivalDate ?? eventDate,
            time: endTime,
            calendar: calendar
        )

        if explicitEndText == nil,
           arrivalDate == nil,
           let parsedEnd = endDate,
           parsedEnd < startDate
        {
            endDate = calendar.date(byAdding: .day, value: 1, to: parsedEnd)
        }

        if let endDate, endDate <= startDate {
            throw RecognitionError.invalidResponse
        }

        return RecognizedEventTiming(startDate: startDate, endDate: endDate)
    }

    private static func value(
        in fields: [String: String],
        keys: [String]
    ) -> String? {
        keys.lazy
            .compactMap { fields[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func combine(
        date: String?,
        time: String?,
        calendar: Calendar
    ) -> Date? {
        guard let date, let time else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)")
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
            template: template,
            recognitionStatus: status,
            updatedAt: updatedAt
        )
    }
}

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
}

struct SystemEventRecognitionCoordinator: SystemEventRecognizing {
    typealias ProviderFactory = @Sendable (
        TimelineSettings,
        String
    ) -> any RecognitionProvider

    private let repository: any EventRepositoryStoring
    private let apiKeyStore: any APIKeyStoring
    private let templateFactory: EventTemplateFactory
    private let providerFactory: ProviderFactory

    init(
        repository: any EventRepositoryStoring,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        templateFactory: EventTemplateFactory = EventTemplateFactory(),
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
                    if let template = await synchronize(
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
                        now: now
                    ) {
                        templates["calendar:\(event.identifier)"] = template
                    }
                }
            }

            if settings.syncRemindersToStorage {
                for reminder in reminders {
                    let endDate = endDate(
                        forReminderDueDate: reminder.dueDate,
                        durationMinutes: settings.reminderDurationMinutes
                    )
                    if let template = await synchronize(
                        record: storedRecord(
                            from: reminder,
                            endDate: endDate,
                            status: .pending,
                            updatedAt: now
                        ),
                        input: .reminder(
                            sourceIdentifier: reminder.identifier,
                            title: reminder.title,
                            dueDate: reminder.dueDate,
                            endDate: endDate,
                            notes: reminder.notes
                        ),
                        settings: settings,
                        now: now
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
        imageReference: String,
        settings: TimelineSettings,
        now: Date
    ) async throws -> StoredEventRecord {
        let idPrefix = source == .cameraImage ? "camera" : "image"
        let sourceIdentifier = UUID().uuidString
        let record = StoredEventRecord(
            id: "\(idPrefix):\(sourceIdentifier)",
            source: source,
            sourceIdentifier: sourceIdentifier,
            rawTitle: filename,
            rawLocation: nil,
            rawNotes: nil,
            imageReference: imageReference,
            startDate: nil,
            endDate: nil,
            template: nil,
            recognitionStatus: .pending,
            updatedAt: now
        )
        let input: RecognitionInput = source == .cameraImage
            ? .cameraImage(id: sourceIdentifier, imageData: data)
            : .importedImage(id: sourceIdentifier, imageData: data, filename: filename)

        let template = await synchronize(
            record: record,
            input: input,
            settings: settings,
            now: now
        )
        return StoredEventRecord(
            id: record.id,
            source: source,
            sourceIdentifier: sourceIdentifier,
            rawTitle: filename,
            rawLocation: nil,
            rawNotes: nil,
            imageReference: imageReference,
            startDate: nil,
            endDate: nil,
            template: template,
            recognitionStatus: template == nil ? .failed : .recognized,
            updatedAt: now
        )
    }

    private func synchronize(
        record: StoredEventRecord,
        input: RecognitionInput,
        settings: TimelineSettings,
        now: Date
    ) async -> TimelineEventTemplate? {
        guard settings.aiRecognitionMode != .off else {
            try? await repository.upsert(record.with(status: .disabled, updatedAt: now))
            return nil
        }

        guard let provider = provider(for: settings) else {
            try? await repository.upsert(record.with(status: .failed, updatedAt: now))
            return nil
        }

        do {
            let result = try await provider.recognize(input)
            let template = templateFactory.makeTemplate(from: result.payload)
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
        endDate: Date?,
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
            endDate: endDate,
            template: nil,
            recognitionStatus: status,
            updatedAt: updatedAt
        )
    }

    private func endDate(
        forReminderDueDate dueDate: Date?,
        durationMinutes: Int
    ) -> Date? {
        guard let dueDate else {
            return nil
        }

        let normalizedDuration = durationMinutes > 0 ? durationMinutes : 30
        return dueDate.addingTimeInterval(TimeInterval(normalizedDuration * 60))
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

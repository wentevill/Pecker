import Foundation
import PeckerCore
import Testing
@testable import Pecker

@Test func coordinatorPreservesCalendarTimeWindowForStorageAndRecognitionInput() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider()
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let startDate = Date(timeIntervalSince1970: 1_000)
    let endDate = Date(timeIntervalSince1970: 2_800)
    let now = Date(timeIntervalSince1970: 5_000)

    _ = await coordinator.synchronize(
        events: [
            EventRecord(
                identifier: "event-1",
                title: "Design review",
                startDate: startDate,
                endDate: endDate,
                isAllDay: true,
                location: "Room A",
                notes: "Bring mockups"
            )
        ],
        reminders: [],
        settings: TimelineSettings(
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true,
            syncCalendarToStorage: true
        ),
        now: now
    )

    let records = await repository.records()
    #expect(records.first?.id == "calendar:event-1")
    #expect(records.first?.startDate == startDate)
    #expect(records.first?.endDate == endDate)

    let inputs = await provider.inputs()
    #expect(inputs.first?.id == "calendar:event-1")
    #expect(inputs.first?.startDate == startDate)
    #expect(inputs.first?.endDate == endDate)
    #expect(inputs.first?.isAllDay == true)
}

@Test func coordinatorAlignsReminderStorageAndRecognitionInputWithTimelineDuration() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider()
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let dueDate = Date(timeIntervalSince1970: 1_000)
    let expectedEndDate = dueDate.addingTimeInterval(45 * 60)
    let now = Date(timeIntervalSince1970: 5_000)

    _ = await coordinator.synchronize(
        events: [],
        reminders: [
            ReminderRecord(
                identifier: "reminder-1",
                title: "Pay bill",
                dueDate: dueDate,
                notes: "Use checking"
            )
        ],
        settings: TimelineSettings(
            reminderDurationMinutes: 45,
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true,
            syncRemindersToStorage: true
        ),
        now: now
    )

    let records = await repository.records()
    #expect(records.first?.id == "reminder:reminder-1")
    #expect(records.first?.startDate == dueDate)
    #expect(records.first?.endDate == expectedEndDate)

    let inputs = await provider.inputs()
    #expect(inputs.first?.id == "reminder:reminder-1")
    #expect(inputs.first?.startDate == dueDate)
    #expect(inputs.first?.endDate == expectedEndDate)
    #expect(inputs.first?.isAllDay == false)
}

private actor RecordingEventRepository: EventRepositoryStoring {
    private var storedRecords: [StoredEventRecord] = []

    func loadAll() async throws -> [StoredEventRecord] {
        storedRecords
    }

    func upsert(_ record: StoredEventRecord) async throws {
        storedRecords.removeAll { $0.id == record.id }
        storedRecords.append(record)
    }

    func delete(source: RecognitionSource) async throws {
        storedRecords.removeAll { $0.source == source }
    }

    func records() -> [StoredEventRecord] {
        storedRecords
    }
}

private actor RecordingRecognitionProvider: RecognitionProvider {
    private var recordedInputs: [RecognitionInput] = []

    func recognize(_ input: RecognitionInput) async throws -> RecognitionResult {
        recordedInputs.append(input)
        return RecognitionResult(
            payload: ExternalEventTemplatePayload(kind: .unknown, fields: [:]),
            confidence: nil
        )
    }

    func inputs() -> [RecognitionInput] {
        recordedInputs
    }
}

private struct StaticAPIKeyStore: APIKeyStoring {
    let apiKey: String?

    func saveOpenAIAPIKey(_ key: String) throws {}

    func loadOpenAIAPIKey() throws -> String? {
        apiKey
    }

    func clearOpenAIAPIKey() throws {}
}

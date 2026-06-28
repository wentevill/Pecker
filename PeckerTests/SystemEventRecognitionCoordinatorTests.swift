import Foundation
import PeckerCore
import Testing
import XCTest
@testable import Pecker

final class SystemEventRecognitionCoordinatorImageXCTests: XCTestCase {
    func testImageRecognitionStoresRecognizedTemplateFromProviderPayload() async throws {
        let repository = RecordingEventRepository()
        let provider = RecordingRecognitionProvider(
            result: RecognitionResult(
                payload: ExternalEventTemplatePayload(
                    kind: .train,
                    fields: [
                        "trainNumber": "G123",
                        "departureStation": "上海虹桥",
                        "arrivalStation": "北京南",
                        "carriageNumber": "08",
                        "seatNumber": "03A"
                    ]
                ),
                confidence: 0.88
            )
        )
        let coordinator = SystemEventRecognitionCoordinator(
            repository: repository,
            apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
            providerFactory: { _, _ in provider }
        )

        let draft = try await coordinator.recognizeImage(
            data: Data([0xFF, 0xD8, 0xFF]),
            source: .importedImage,
            filename: "ticket.jpg",
            settings: TimelineSettings(
                aiRecognitionMode: .openAI,
                openAIAPIKeyConfigured: true
            ),
            now: Date(timeIntervalSince1970: 5_000)
        )
        let record = try await coordinator.saveRecognizedImage(
            draft,
            imageReference: "Images/ticket.jpg"
        )

        guard case let .trainTicket(ticket) = record.template else {
            return XCTFail("Expected image recognition to create a train ticket template")
        }
        XCTAssertEqual(record.recognitionStatus, .recognized)
        XCTAssertEqual(ticket.trainNumber, "G123")
        XCTAssertEqual(ticket.departureStation, "上海虹桥")
        XCTAssertEqual(ticket.arrivalStation, "北京南")
        XCTAssertEqual(ticket.carriageNumber, "08")
        XCTAssertEqual(ticket.seatNumber, "03A")
    }

    func testImageRecognitionThrowsUnsupportedInputWhenProviderFindsNoEventCard() async throws {
        let repository = RecordingEventRepository()
        let provider = RecordingRecognitionProvider(
            result: RecognitionResult(
                payload: ExternalEventTemplatePayload(kind: .unknown, fields: [:]),
                confidence: 0.22
            )
        )
        let coordinator = SystemEventRecognitionCoordinator(
            repository: repository,
            apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
            providerFactory: { _, _ in provider }
        )

        do {
            _ = try await coordinator.recognizeImage(
                data: Data([1, 2, 3]),
                source: .cameraImage,
                filename: nil,
                settings: TimelineSettings(
                    aiRecognitionMode: .openAI,
                    openAIAPIKeyConfigured: true
                ),
                now: Date(timeIntervalSince1970: 5_000)
            )
            XCTFail("Expected unsupportedInput when image does not produce an event card")
        } catch let error as RecognitionError {
            XCTAssertEqual(error, .unsupportedInput)
        }

        let records = await repository.records()
        XCTAssertTrue(records.isEmpty)
    }

    func testRecognizedImageRecordsBecomeExternalTimelineItems() async throws {
        let repository = RecordingEventRepository()
        let recognizedAt = Date(timeIntervalSince1970: 5_000)
        try await repository.upsert(StoredEventRecord(
            id: "image:ticket-1",
            source: .importedImage,
            sourceIdentifier: "ticket-1",
            rawTitle: "ticket.jpg",
            rawLocation: nil,
            rawNotes: nil,
            imageReference: "Images/ticket.jpg",
            startDate: recognizedAt,
            endDate: nil,
            template: .trainTicket(.init(
                trainNumber: "G123",
                departureStation: "上海虹桥",
                arrivalStation: "北京南",
                departureTimeText: "09:24",
                arrivalTimeText: nil,
                carriageNumber: "08",
                seatNumber: "03A",
                checkInGate: nil,
                passengerName: nil,
                ticketNumber: nil
            )),
            recognitionStatus: .recognized,
            updatedAt: recognizedAt
        ))
        let coordinator = SystemEventRecognitionCoordinator(
            repository: repository,
            apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test")
        )

        let items = await coordinator.recognizedImageItems(
            settings: TimelineSettings(aiRecognitionMode: .openAI),
            now: Date(timeIntervalSince1970: 5_060)
        )

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "image:ticket-1")
        XCTAssertEqual(items.first?.source, .external)
        XCTAssertEqual(items.first?.title, "G123")
        XCTAssertEqual(items.first?.kind, .train)
        XCTAssertEqual(items.first?.template?.presentation.subtitle, "上海虹桥 → 北京南")
        XCTAssertEqual(items.first?.startDate, recognizedAt)
    }
}

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

@Test func coordinatorKeepsReminderStorageAndRecognitionInputWithoutSyntheticEndDate() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider()
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let dueDate = Date(timeIntervalSince1970: 1_000)
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
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true,
            syncRemindersToStorage: true
        ),
        now: now
    )

    let records = await repository.records()
    #expect(records.first?.id == "reminder:reminder-1")
    #expect(records.first?.startDate == dueDate)
    #expect(records.first?.endDate == nil)

    let inputs = await provider.inputs()
    #expect(inputs.first?.id == "reminder:reminder-1")
    #expect(inputs.first?.startDate == dueDate)
    #expect(inputs.first?.endDate == nil)
    #expect(inputs.first?.isAllDay == false)
}

@Test func imageRecognitionStoresRecognizedTemplateFromProviderPayload() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider(
        result: RecognitionResult(
            payload: ExternalEventTemplatePayload(
                kind: .train,
                fields: [
                    "trainNumber": "G123",
                    "departureStation": "上海虹桥",
                    "arrivalStation": "北京南",
                    "carriageNumber": "08",
                    "seatNumber": "03A"
                ]
            ),
            confidence: 0.88
        )
    )
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let now = Date(timeIntervalSince1970: 5_000)

    let draft = try await coordinator.recognizeImage(
        data: Data([0xFF, 0xD8, 0xFF]),
        source: .importedImage,
        filename: "ticket.jpg",
        settings: TimelineSettings(
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true
        ),
        now: now
    )
    let record = try await coordinator.saveRecognizedImage(
        draft,
        imageReference: "Images/ticket.jpg"
    )

    guard case let .trainTicket(ticket) = record.template else {
        Issue.record("Expected image recognition to create a train ticket template")
        return
    }
    #expect(record.recognitionStatus == .recognized)
    #expect(ticket.trainNumber == "G123")
    #expect(ticket.departureStation == "上海虹桥")
    #expect(ticket.arrivalStation == "北京南")
    #expect(ticket.carriageNumber == "08")
    #expect(ticket.seatNumber == "03A")

    let records = await repository.records()
    #expect(records.first?.id == record.id)
    #expect(records.first?.template == record.template)
    #expect(records.first?.recognitionStatus == .recognized)

    let inputs = await provider.inputs()
    #expect(inputs.first?.source == .importedImage)
    #expect(inputs.first?.imageData == Data([0xFF, 0xD8, 0xFF]))
}

@Test func imageRecognitionThrowsUnsupportedInputWhenProviderFindsNoEventCard() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider(
        result: RecognitionResult(
            payload: ExternalEventTemplatePayload(kind: .unknown, fields: [:]),
            confidence: 0.22
        )
    )
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )

    await #expect(throws: RecognitionError.unsupportedInput) {
        _ = try await coordinator.recognizeImage(
            data: Data([1, 2, 3]),
            source: .cameraImage,
            filename: nil,
            settings: TimelineSettings(
                aiRecognitionMode: .openAI,
                openAIAPIKeyConfigured: true
            ),
            now: Date(timeIntervalSince1970: 5_000)
        )
    }

    let records = await repository.records()
    #expect(records.isEmpty)
}

@Test func imageRecognitionReturnsDraftWithoutPersisting() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider(
        result: RecognitionResult(
            payload: ExternalEventTemplatePayload(
                kind: .train,
                fields: [
                    "trainNumber": "G123",
                    "departureStation": "上海虹桥",
                    "arrivalStation": "北京南"
                ]
            ),
            confidence: 0.88
        )
    )
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let imageData = Data([0xFF, 0xD8, 0xFF])
    let now = Date(timeIntervalSince1970: 5_000)

    let draft = try await coordinator.recognizeImage(
        data: imageData,
        source: .importedImage,
        filename: "ticket.jpg",
        settings: TimelineSettings(
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true
        ),
        now: now
    )

    #expect(draft.imageData == imageData)
    #expect(draft.source == .importedImage)
    #expect(draft.filename == "ticket.jpg")
    #expect(draft.recognizedAt == now)
    #expect(draft.template.presentation.title == "G123")
    #expect(await repository.records().isEmpty)
}

@Test func confirmedImageDraftPersistsRecognizedRecord() async throws {
    let repository = RecordingEventRepository()
    let coordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test")
    )
    let draft = ImageRecognitionDraft(
        id: "image:draft-1",
        sourceIdentifier: "draft-1",
        source: .importedImage,
        filename: "ticket.jpg",
        imageData: Data([0xFF, 0xD8, 0xFF]),
        recognizedAt: Date(timeIntervalSince1970: 5_000),
        template: .trainTicket(.init(
            trainNumber: "G123",
            departureStation: "上海虹桥",
            arrivalStation: "北京南",
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: "08",
            seatNumber: "03A",
            checkInGate: nil,
            passengerName: nil,
            ticketNumber: nil
        ))
    )

    let saved = try await coordinator.saveRecognizedImage(
        draft,
        imageReference: "Images/ticket.jpg"
    )

    #expect(saved.id == draft.id)
    #expect(saved.imageReference == "Images/ticket.jpg")
    #expect(saved.recognitionStatus == .recognized)
    #expect(await repository.records() == [saved])
}

@Test func imageCoordinatorRecognitionDoesNotWriteImage() async throws {
    let repository = RecordingEventRepository()
    let provider = RecordingRecognitionProvider(
        result: RecognitionResult(
            payload: ExternalEventTemplatePayload(
                kind: .train,
                fields: ["trainNumber": "G123"]
            ),
            confidence: nil
        )
    )
    let systemCoordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test"),
        providerFactory: { _, _ in provider }
    )
    let imageStore = RecordingImageFileStore()
    let coordinator = ImageRecognitionCoordinator(
        imageStore: imageStore,
        systemCoordinator: systemCoordinator
    )

    let draft = try await coordinator.recognizeImage(
        data: Data([1, 2, 3]),
        source: .importedImage,
        filename: "ticket.jpg",
        settings: TimelineSettings(
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true
        ),
        now: Date(timeIntervalSince1970: 5_000)
    )

    #expect(draft.template.presentation.title == "G123")
    #expect(imageStore.savedImages.isEmpty)
    #expect(await repository.records().isEmpty)
}

@Test func imageCoordinatorRollsBackImageWhenRecordSaveFails() async throws {
    let repository = FailingEventRepository()
    let systemCoordinator = SystemEventRecognitionCoordinator(
        repository: repository,
        apiKeyStore: StaticAPIKeyStore(apiKey: "sk-test")
    )
    let imageStore = RecordingImageFileStore()
    let coordinator = ImageRecognitionCoordinator(
        imageStore: imageStore,
        systemCoordinator: systemCoordinator
    )
    let draft = ImageRecognitionDraft(
        id: "image:draft-1",
        sourceIdentifier: "draft-1",
        source: .importedImage,
        filename: "ticket.jpg",
        imageData: Data([1, 2, 3]),
        recognizedAt: Date(timeIntervalSince1970: 5_000),
        template: .trainTicket(.init(
            trainNumber: "G123",
            departureStation: nil,
            arrivalStation: nil,
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: nil,
            seatNumber: nil,
            checkInGate: nil,
            passengerName: nil,
            ticketNumber: nil
        ))
    )

    await #expect(throws: TestPersistenceError.failed) {
        _ = try await coordinator.saveRecognizedImage(draft)
    }

    #expect(imageStore.savedImages.count == 1)
    #expect(imageStore.deletedPaths == ["Images/test.jpg"])
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

private enum TestPersistenceError: Error {
    case failed
}

private actor FailingEventRepository: EventRepositoryStoring {
    func loadAll() async throws -> [StoredEventRecord] {
        []
    }

    func upsert(_ record: StoredEventRecord) async throws {
        throw TestPersistenceError.failed
    }

    func delete(source: RecognitionSource) async throws {}
}

private final class RecordingImageFileStore: ImageFileStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSavedImages: [Data] = []
    private var storedDeletedPaths: [String] = []

    var savedImages: [Data] {
        lock.withLock { storedSavedImages }
    }

    var deletedPaths: [String] {
        lock.withLock { storedDeletedPaths }
    }

    func saveImage(
        data: Data,
        filename: String?,
        source: RecognitionSource
    ) throws -> String {
        lock.withLock {
            storedSavedImages.append(data)
        }
        return "Images/test.jpg"
    }

    func deleteImage(at relativePath: String) throws {
        lock.withLock {
            storedDeletedPaths.append(relativePath)
        }
    }
}

private actor RecordingRecognitionProvider: RecognitionProvider {
    private let result: RecognitionResult
    private var recordedInputs: [RecognitionInput] = []

    init(
        result: RecognitionResult = RecognitionResult(
            payload: ExternalEventTemplatePayload(kind: .unknown, fields: [:]),
            confidence: nil
        )
    ) {
        self.result = result
    }

    func recognize(_ input: RecognitionInput) async throws -> RecognitionResult {
        recordedInputs.append(input)
        return result
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

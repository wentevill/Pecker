import Foundation
import Testing
@testable import PeckerCore

@Test func eventRepositorySavesLoadsAndUpsertsRecords() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    let first = StoredEventRecord(
        id: "calendar:event-1",
        source: .calendar,
        sourceIdentifier: "event-1",
        rawTitle: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
        rawLocation: "\u{68c0}\u{7968}\u{53e3} B7",
        rawNotes: "08\u{8f66} 03A",
        imageReference: nil,
        startDate: Date(timeIntervalSince1970: 100),
        endDate: Date(timeIntervalSince1970: 200),
        template: nil,
        recognitionStatus: .pending,
        updatedAt: Date(timeIntervalSince1970: 300)
    )
    let updated = StoredEventRecord(
        id: first.id,
        source: .calendar,
        sourceIdentifier: "event-1",
        rawTitle: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
        rawLocation: "\u{68c0}\u{7968}\u{53e3} A1",
        rawNotes: "09\u{8f66} 02F",
        imageReference: nil,
        startDate: first.startDate,
        endDate: first.endDate,
        template: .trainTicket(.init(
            trainNumber: "G123",
            departureStation: "\u{4e0a}\u{6d77}\u{8679}\u{6865}",
            arrivalStation: "\u{5317}\u{4eac}\u{5357}",
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: "09",
            seatNumber: "02F",
            checkInGate: "A1",
            passengerName: nil,
            ticketNumber: nil
        )),
        recognitionStatus: .recognized,
        updatedAt: Date(timeIntervalSince1970: 400)
    )

    try await repository.upsert(first)
    try await repository.upsert(updated)

    let records = try await repository.loadAll()
    #expect(records == [updated])
}

@Test func eventRepositoryFiltersAndDeletesBySource() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    let calendar = record(id: "calendar:event-1", source: .calendar)
    let reminder = record(id: "reminder:task-1", source: .reminder)
    let image = record(id: "image:ticket-1", source: .importedImage)

    try await repository.upsert(calendar)
    try await repository.upsert(reminder)
    try await repository.upsert(image)

    #expect(try await repository.load(source: .calendar) == [calendar])

    try await repository.delete(source: .calendar)

    #expect(try await repository.loadAll().map(\.id).sorted() == [
        image.id,
        reminder.id
    ].sorted())
}

@Test func eventRepositoryLoadsAndDeletesOneRecordByID() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    let ticket = record(id: "image:ticket-1", source: .importedImage)
    let other = record(id: "image:ticket-2", source: .importedImage)
    try await repository.upsert(ticket)
    try await repository.upsert(other)

    #expect(try await repository.record(id: ticket.id) == ticket)

    try await repository.delete(id: ticket.id)

    #expect(try await repository.record(id: ticket.id) == nil)
    #expect(try await repository.loadAll() == [other])
}

@Test func eventRepositoryDeletesOnlyRequestedIDs() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    try await repository.upsert(
        record(id: "calendar:keep", source: .calendar)
    )
    try await repository.upsert(
        record(id: "calendar:remove", source: .calendar)
    )
    try await repository.upsert(
        record(id: "image:keep", source: .importedImage)
    )

    try await repository.delete(ids: ["calendar:remove"])

    #expect(try await repository.loadAll().map(\.id).sorted() == [
        "calendar:keep",
        "image:keep"
    ])
}

@Test func storedEventRecordRoundTripsAllDayState() throws {
    let allDay = StoredEventRecord(
        id: "image:all-day",
        source: .importedImage,
        sourceIdentifier: "all-day",
        rawTitle: "\u{793e}\u{533a}\u{6d3b}\u{52a8}",
        rawLocation: nil,
        rawNotes: nil,
        imageReference: "Images/poster.jpg",
        startDate: Date(timeIntervalSince1970: 100),
        endDate: nil,
        isAllDay: true,
        template: .generic(.init(
            kind: .unknown,
            title: "\u{793e}\u{533a}\u{6d3b}\u{52a8}",
            location: nil,
            notes: nil
        )),
        recognitionStatus: .recognized,
        updatedAt: Date(timeIntervalSince1970: 200)
    )

    let decoded = try JSONDecoder().decode(
        StoredEventRecord.self,
        from: JSONEncoder().encode(allDay)
    )

    #expect(decoded.isAllDay)
}

@Test func storedEventRecordDefaultsLegacyAllDayStateToFalse() throws {
    let current = record(id: "image:legacy", source: .importedImage)
    let data = try JSONEncoder().encode(current)
    var object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    object.removeValue(forKey: "isAllDay")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(
        StoredEventRecord.self,
        from: legacyData
    )

    #expect(!decoded.isAllDay)
}

@Test func storedEventRecordRoundTripsOrderedCustomFields() throws {
    let fields = [
        EventCustomField(id: "booking", name: "Booking", value: "K8X2PL"),
        EventCustomField(id: "loyalty", name: "Loyalty", value: "KF 882019")
    ]
    let current = record(
        id: "image:custom-fields",
        source: .importedImage,
        customFields: fields
    )

    let decoded = try JSONDecoder().decode(
        StoredEventRecord.self,
        from: JSONEncoder().encode(current)
    )

    #expect(decoded.customFields == fields)
}

@Test func storedEventRecordDefaultsLegacyCustomFieldsToEmpty() throws {
    let current = record(id: "image:legacy-fields", source: .importedImage)
    let data = try JSONEncoder().encode(current)
    var object = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    object.removeValue(forKey: "customFields")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(
        StoredEventRecord.self,
        from: legacyData
    )

    #expect(decoded.customFields.isEmpty)
}

private func record(
    id: String,
    source: RecognitionSource,
    customFields: [EventCustomField] = []
) -> StoredEventRecord {
    StoredEventRecord(
        id: id,
        source: source,
        sourceIdentifier: id,
        rawTitle: id,
        rawLocation: nil,
        rawNotes: nil,
        imageReference: source == .importedImage ? "Images/ticket-1.jpg" : nil,
        startDate: nil,
        endDate: nil,
        template: nil,
        recognitionStatus: .pending,
        updatedAt: Date(timeIntervalSince1970: 100),
        customFields: customFields
    )
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("EventRepositoryTests-\(UUID().uuidString)")
}

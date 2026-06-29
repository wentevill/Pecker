import Foundation
import Testing
@testable import PeckerCore

@Test func eventRepositorySavesLoadsAndUpsertsRecords() async throws {
    let repository = EventRepository(directoryURL: temporaryDirectory())
    let first = StoredEventRecord(
        id: "calendar:event-1",
        source: .calendar,
        sourceIdentifier: "event-1",
        rawTitle: "G123 上海虹桥 → 北京南",
        rawLocation: "检票口 B7",
        rawNotes: "08车 03A",
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
        rawTitle: "G123 上海虹桥 → 北京南",
        rawLocation: "检票口 A1",
        rawNotes: "09车 02F",
        imageReference: nil,
        startDate: first.startDate,
        endDate: first.endDate,
        template: .trainTicket(.init(
            trainNumber: "G123",
            departureStation: "上海虹桥",
            arrivalStation: "北京南",
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

@Test func storedEventRecordRoundTripsAllDayState() throws {
    let allDay = StoredEventRecord(
        id: "image:all-day",
        source: .importedImage,
        sourceIdentifier: "all-day",
        rawTitle: "社区活动",
        rawLocation: nil,
        rawNotes: nil,
        imageReference: "Images/poster.jpg",
        startDate: Date(timeIntervalSince1970: 100),
        endDate: nil,
        isAllDay: true,
        template: .generic(.init(
            kind: .unknown,
            title: "社区活动",
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

private func record(
    id: String,
    source: RecognitionSource
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
        updatedAt: Date(timeIntervalSince1970: 100)
    )
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("EventRepositoryTests-\(UUID().uuidString)")
}

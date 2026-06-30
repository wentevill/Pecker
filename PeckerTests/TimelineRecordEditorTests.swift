import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class TimelineRecordEditorTests: XCTestCase {
    func testLocalServiceDeletesRecordAndImage() async throws {
        let record = makeRecord()
        let repository = EditorRepository(record: record)
        let images = EditorImageStore()
        let service = LocalTimelineCardService(
            repository: repository,
            imageStore: images
        )

        try await service.delete(id: record.id)

        let remainingRecords = await repository.records
        XCTAssertTrue(remainingRecords.isEmpty)
        XCTAssertEqual(images.deletedPaths, ["Images/patrol.jpg"])
    }

    func testGenericEditorUpdatesCoreFields() throws {
        let record = makeRecord()
        var editor = try TimelineRecordEditor(record: record)
        editor.title = "\u{591c}\u{95f4}\u{5de1}\u{903b}"
        editor.kind = .task
        editor.startDate = Date(timeIntervalSince1970: 2_000)
        editor.endDate = Date(timeIntervalSince1970: 2_600)
        editor.location = "\u{56ed}\u{533a}"
        editor.notes = "\u{5de1}\u{67e5}\u{4ed3}\u{5e93}"

        let updated = try editor.makeRecord(
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        XCTAssertEqual(updated.rawTitle, "\u{591c}\u{95f4}\u{5de1}\u{903b}")
        XCTAssertEqual(updated.startDate, editor.startDate)
        XCTAssertEqual(updated.endDate, editor.endDate)
        XCTAssertEqual(updated.rawLocation, "\u{56ed}\u{533a}")
        XCTAssertEqual(updated.rawNotes, "\u{5de1}\u{67e5}\u{4ed3}\u{5e93}")
        XCTAssertEqual(
            updated.template,
            .generic(.init(
                kind: .task,
                title: "\u{591c}\u{95f4}\u{5de1}\u{903b}",
                location: "\u{56ed}\u{533a}",
                notes: "\u{5de1}\u{67e5}\u{4ed3}\u{5e93}"
            ))
        )
    }

    func testEditorRejectsInvalidTitleAndRange() throws {
        var editor = try TimelineRecordEditor(record: makeRecord())
        editor.title = " "
        XCTAssertThrowsError(try editor.makeRecord(updatedAt: .now)) {
            XCTAssertEqual($0 as? TimelineRecordEditorError, .emptyTitle)
        }

        editor.title = "\u{5de1}\u{903b}"
        editor.endDate = editor.startDate
        XCTAssertThrowsError(try editor.makeRecord(updatedAt: .now)) {
            XCTAssertEqual($0 as? TimelineRecordEditorError, .invalidDateRange)
        }
    }

    func testFlightEditorPreservesStructuredTicketFields() throws {
        let ticket = FlightTicketTemplate(
            flightNumber: "SQ 833",
            carrier: "Singapore Airlines",
            departureAirport: "Shanghai Pudong",
            departureAirportCode: "PVG",
            arrivalAirport: "Singapore Changi",
            arrivalAirportCode: "SIN",
            departureTimeText: "14:35",
            arrivalTimeText: "20:25",
            terminal: "T3",
            gate: "B7",
            seat: "12A",
            travelStatus: "Boarding"
        )
        let record = StoredEventRecord(
            id: "image:flight",
            source: .importedImage,
            sourceIdentifier: "flight",
            rawTitle: "SQ 833",
            rawLocation: nil,
            rawNotes: nil,
            imageReference: nil,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            template: .flightTicket(ticket),
            recognitionStatus: .recognized,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        var editor = try TimelineRecordEditor(record: record)
        editor.title = "SQ 834"
        let updated = try editor.makeRecord(
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        guard case let .flightTicket(updatedTicket) = updated.template else {
            return XCTFail("Expected flight ticket")
        }
        XCTAssertEqual(updatedTicket.flightNumber, "SQ 834")
        XCTAssertEqual(updatedTicket.departureAirportCode, "PVG")
        XCTAssertEqual(updatedTicket.arrivalAirportCode, "SIN")
        XCTAssertEqual(updatedTicket.gate, "B7")
        XCTAssertEqual(updatedTicket.seat, "12A")
    }

    func testGenericEditorPreservesRecognitionFields() throws {
        let fields = [
            "title": "Design interview",
            "location": "Zoom",
            "interviewer": "Design Lead"
        ]
        let record = StoredEventRecord(
            id: "image:interview",
            source: .importedImage,
            sourceIdentifier: "interview",
            rawTitle: "Design interview",
            rawLocation: "Zoom",
            rawNotes: nil,
            imageReference: nil,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            template: .generic(.init(
                kind: .interview,
                title: "Design interview",
                location: "Zoom",
                notes: nil,
                fields: fields
            )),
            recognitionStatus: .recognized,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        var editor = try TimelineRecordEditor(record: record)
        editor.title = "Final interview"
        let updated = try editor.makeRecord(
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        guard case let .generic(event) = updated.template else {
            return XCTFail("Expected generic template")
        }
        XCTAssertEqual(event.fields["interviewer"], "Design Lead")
    }

    func testEditorRejectsSystemOwnedRecord() {
        let record = StoredEventRecord(
            id: "calendar:event",
            source: .calendar,
            sourceIdentifier: "event",
            rawTitle: "\u{4f1a}\u{8bae}",
            rawLocation: nil,
            rawNotes: nil,
            imageReference: nil,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: nil,
            template: nil,
            recognitionStatus: .recognized,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertThrowsError(try TimelineRecordEditor(record: record)) {
            XCTAssertEqual($0 as? TimelineRecordEditorError, .readOnlySource)
        }
    }

    private func makeRecord() -> StoredEventRecord {
        StoredEventRecord(
            id: "image:patrol",
            source: .importedImage,
            sourceIdentifier: "patrol",
            rawTitle: "\u{5de1}\u{903b}",
            rawLocation: nil,
            rawNotes: "\u{5de1}\u{67e5}\u{697c}\u{68af}\u{53e3}、\u{4ed3}\u{5e93}、\u{56f4}\u{680f}",
            imageReference: "Images/patrol.jpg",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_600),
            template: .generic(.init(
                kind: .task,
                title: "\u{5de1}\u{903b}",
                location: nil,
                notes: "\u{5de1}\u{67e5}\u{697c}\u{68af}\u{53e3}、\u{4ed3}\u{5e93}、\u{56f4}\u{680f}"
            )),
            recognitionStatus: .recognized,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}

private actor EditorRepository: EventRepositoryStoring {
    var records: [StoredEventRecord]

    init(record: StoredEventRecord) {
        records = [record]
    }

    func loadAll() async throws -> [StoredEventRecord] {
        records
    }

    func upsert(_ record: StoredEventRecord) async throws {
        records.removeAll { $0.id == record.id }
        records.append(record)
    }

    func delete(source: RecognitionSource) async throws {
        records.removeAll { $0.source == source }
    }

    func delete(id: String) async throws {
        records.removeAll { $0.id == id }
    }
}

private final class EditorImageStore: ImageFileStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var paths: [String] = []

    var deletedPaths: [String] {
        lock.withLock { paths }
    }

    func saveImage(
        data: Data,
        filename: String?,
        source: RecognitionSource
    ) throws -> String {
        "Images/test.jpg"
    }

    func deleteImage(at relativePath: String) throws {
        lock.withLock { paths.append(relativePath) }
    }
}

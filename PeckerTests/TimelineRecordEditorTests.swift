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
        editor.title = "夜间巡逻"
        editor.kind = .task
        editor.startDate = Date(timeIntervalSince1970: 2_000)
        editor.endDate = Date(timeIntervalSince1970: 2_600)
        editor.location = "园区"
        editor.notes = "巡查仓库"

        let updated = try editor.makeRecord(
            updatedAt: Date(timeIntervalSince1970: 3_000)
        )

        XCTAssertEqual(updated.rawTitle, "夜间巡逻")
        XCTAssertEqual(updated.startDate, editor.startDate)
        XCTAssertEqual(updated.endDate, editor.endDate)
        XCTAssertEqual(updated.rawLocation, "园区")
        XCTAssertEqual(updated.rawNotes, "巡查仓库")
        XCTAssertEqual(
            updated.template,
            .generic(.init(
                kind: .task,
                title: "夜间巡逻",
                location: "园区",
                notes: "巡查仓库"
            ))
        )
    }

    func testEditorRejectsInvalidTitleAndRange() throws {
        var editor = try TimelineRecordEditor(record: makeRecord())
        editor.title = " "
        XCTAssertThrowsError(try editor.makeRecord(updatedAt: .now)) {
            XCTAssertEqual($0 as? TimelineRecordEditorError, .emptyTitle)
        }

        editor.title = "巡逻"
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

    func testEditorRejectsSystemOwnedRecord() {
        let record = StoredEventRecord(
            id: "calendar:event",
            source: .calendar,
            sourceIdentifier: "event",
            rawTitle: "会议",
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
            rawTitle: "巡逻",
            rawLocation: nil,
            rawNotes: "巡查楼梯口、仓库、围栏",
            imageReference: "Images/patrol.jpg",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_600),
            template: .generic(.init(
                kind: .task,
                title: "巡逻",
                location: nil,
                notes: "巡查楼梯口、仓库、围栏"
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

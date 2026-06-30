import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class LiveActivityPresentationAdapterTests: XCTestCase {
    func testEveryTimelineKindMapsToItsApprovedSymbol() {
        let expected: [TimelineKind: String] = [
            .meeting: "person.2.fill",
            .task: "checklist",
            .flight: "airplane",
            .train: "train.side.front.car",
            .travel: "suitcase.fill",
            .interview: "person.text.rectangle",
            .deadline: "calendar.badge.exclamationmark",
            .unknown: "clock.fill"
        ]
        let adapter = LiveActivityPresentationAdapter()

        for (kind, symbol) in expected {
            let item = makeItem(kind: kind)
            let state = adapter.makeState(
                item: item,
                status: .now,
                generatedAt: testNow
            )

            XCTAssertEqual(state.itemIdentifier, item.id)
            XCTAssertEqual(state.title, item.title)
            XCTAssertEqual(state.kindRawValue, kind.rawValue)
            XCTAssertEqual(state.symbolName, symbol)
            XCTAssertEqual(state.statusRawValue, "now")
            XCTAssertEqual(state.startDate, item.startDate)
            XCTAssertEqual(state.endDate, item.endDate)
        }
    }

    func testTrainTicketMapsRouteAndBoundedCredentials() {
        let item = makeItem(
            kind: .train,
            template: .trainTicket(.init(
                trainNumber: "C5770",
                departureStation: "\u{6210}\u{90fd}\u{4e1c}",
                arrivalStation: "\u{91cd}\u{5e86}\u{897f}",
                departureTimeText: "10:30",
                arrivalTimeText: "11:48",
                carriageNumber: "02",
                seatNumber: "06D",
                checkInGate: "B3",
                passengerName: "Wen",
                ticketNumber: "E123",
                seatClass: "\u{4e8c}\u{7b49}\u{5ea7}",
                priceText: "¥96"
            ))
        )

        let state = LiveActivityPresentationAdapter().makeState(
            item: item,
            status: .now,
            generatedAt: testNow
        )

        XCTAssertEqual(state.title, "C5770")
        XCTAssertEqual(state.secondaryIdentity, "\u{6210}\u{90fd}\u{4e1c} → \u{91cd}\u{5e86}\u{897f}")
        XCTAssertEqual(state.leadingEndpoint, "\u{6210}\u{90fd}\u{4e1c}")
        XCTAssertEqual(state.trailingEndpoint, "\u{91cd}\u{5e86}\u{897f}")
        XCTAssertEqual(
            state.metadata,
            ["02 \u{8f66}", "06D \u{5ea7}", "B3 \u{68c0}\u{7968}\u{53e3}", "\u{4e8c}\u{7b49}\u{5ea7}"]
        )
    }

    func testFlightTicketMapsAirportsAndBoundedCredentials() {
        let item = makeItem(
            kind: .flight,
            template: .flightTicket(.init(
                flightNumber: "SQ 833",
                carrier: "Singapore Airlines",
                departureAirport: "\u{4e0a}\u{6d77}\u{6d66}\u{4e1c}",
                departureAirportCode: "PVG",
                arrivalAirport: "\u{65b0}\u{52a0}\u{5761}\u{6a1f}\u{5b9c}",
                arrivalAirportCode: "SIN",
                departureTimeText: "14:35",
                arrivalTimeText: "20:25",
                terminal: "T3",
                gate: "B7",
                seat: "12A",
                travelStatus: "\u{767b}\u{673a}\u{4e2d}"
            ))
        )

        let state = LiveActivityPresentationAdapter().makeState(
            item: item,
            status: .pinned,
            generatedAt: testNow
        )

        XCTAssertEqual(state.title, "SQ 833")
        XCTAssertEqual(state.secondaryIdentity, "Singapore Airlines")
        XCTAssertEqual(state.leadingEndpoint, "PVG · \u{4e0a}\u{6d77}\u{6d66}\u{4e1c}")
        XCTAssertEqual(state.trailingEndpoint, "SIN · \u{65b0}\u{52a0}\u{5761}\u{6a1f}\u{5b9c}")
        XCTAssertEqual(state.metadata, ["T3", "Gate B7", "12A \u{5ea7}", "\u{767b}\u{673a}\u{4e2d}"])
        XCTAssertEqual(state.statusRawValue, "pinned")
    }

    func testGenericItemPrioritizesLocationAndOneSupportingDetail() {
        let item = makeItem(
            kind: .interview,
            location: "Zoom",
            notes: "\u{51c6}\u{5907}\u{4f5c}\u{54c1}\u{96c6}",
            template: .generic(.init(
                kind: .interview,
                title: "\u{4ea7}\u{54c1}\u{8bbe}\u{8ba1}\u{5e08}\u{7ec8}\u{9762}",
                location: "Zoom",
                notes: "\u{51c6}\u{5907}\u{4f5c}\u{54c1}\u{96c6}",
                fields: [
                    "title": "\u{4ea7}\u{54c1}\u{8bbe}\u{8ba1}\u{5e08}\u{7ec8}\u{9762}",
                    "location": "Zoom",
                    "interviewer": "Design Lead"
                ]
            ))
        )

        let state = LiveActivityPresentationAdapter().makeState(
            item: item,
            status: .next,
            generatedAt: testNow
        )

        XCTAssertEqual(state.location, "Zoom")
        XCTAssertEqual(state.supportingDetail, "\u{51c6}\u{5907}\u{4f5c}\u{54c1}\u{96c6}")
        XCTAssertTrue(state.metadata.isEmpty)
        XCTAssertLessThanOrEqual(state.metadata.count, 4)
    }

    private func makeItem(
        kind: TimelineKind,
        location: String? = "Room",
        notes: String? = "Notes",
        template: TimelineEventTemplate? = nil
    ) -> TimelineItem {
        TimelineItem(
            id: "item-\(kind.rawValue)",
            sourceIdentifier: "source-\(kind.rawValue)",
            title: "Title \(kind.rawValue)",
            startDate: testNow.addingTimeInterval(-600),
            endDate: testNow.addingTimeInterval(1_800),
            isAllDay: false,
            source: .external,
            kind: kind,
            location: location,
            notes: notes,
            template: template
        )
    }
}

private let testNow = Date(timeIntervalSinceReferenceDate: 812_246_400)

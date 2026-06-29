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
                departureStation: "成都东",
                arrivalStation: "重庆西",
                departureTimeText: "10:30",
                arrivalTimeText: "11:48",
                carriageNumber: "02",
                seatNumber: "06D",
                checkInGate: "B3",
                passengerName: "Wen",
                ticketNumber: "E123",
                seatClass: "二等座",
                priceText: "¥96"
            ))
        )

        let state = LiveActivityPresentationAdapter().makeState(
            item: item,
            status: .now,
            generatedAt: testNow
        )

        XCTAssertEqual(state.title, "C5770")
        XCTAssertEqual(state.secondaryIdentity, "成都东 → 重庆西")
        XCTAssertEqual(state.leadingEndpoint, "成都东")
        XCTAssertEqual(state.trailingEndpoint, "重庆西")
        XCTAssertEqual(
            state.metadata,
            ["02 车", "06D 座", "B3 检票口", "二等座"]
        )
    }

    func testFlightTicketMapsAirportsAndBoundedCredentials() {
        let item = makeItem(
            kind: .flight,
            template: .flightTicket(.init(
                flightNumber: "SQ 833",
                carrier: "Singapore Airlines",
                departureAirport: "上海浦东",
                departureAirportCode: "PVG",
                arrivalAirport: "新加坡樟宜",
                arrivalAirportCode: "SIN",
                departureTimeText: "14:35",
                arrivalTimeText: "20:25",
                terminal: "T3",
                gate: "B7",
                seat: "12A",
                travelStatus: "登机中"
            ))
        )

        let state = LiveActivityPresentationAdapter().makeState(
            item: item,
            status: .pinned,
            generatedAt: testNow
        )

        XCTAssertEqual(state.title, "SQ 833")
        XCTAssertEqual(state.secondaryIdentity, "Singapore Airlines")
        XCTAssertEqual(state.leadingEndpoint, "PVG · 上海浦东")
        XCTAssertEqual(state.trailingEndpoint, "SIN · 新加坡樟宜")
        XCTAssertEqual(state.metadata, ["T3", "Gate B7", "12A 座", "登机中"])
        XCTAssertEqual(state.statusRawValue, "pinned")
    }

    func testGenericItemPrioritizesLocationAndOneSupportingDetail() {
        let item = makeItem(
            kind: .interview,
            location: "Zoom",
            notes: "准备作品集",
            template: .generic(.init(
                kind: .interview,
                title: "产品设计师终面",
                location: "Zoom",
                notes: "准备作品集",
                fields: [
                    "title": "产品设计师终面",
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
        XCTAssertEqual(state.supportingDetail, "准备作品集")
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

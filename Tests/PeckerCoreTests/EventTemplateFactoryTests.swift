import Foundation
import Testing
@testable import PeckerCore

@Test func factoryCreatesTrainTicketFromLocalRules() {
    let factory = EventTemplateFactory()

    let template = factory.makeTemplate(
        from: ClassificationInput(
            title: "G123 上海虹桥 → 北京南",
            location: "检票口 B7",
            notes: "08车 03A"
        )
    )

    guard case let .trainTicket(ticket) = template else {
        Issue.record("Expected train ticket template")
        return
    }
    #expect(ticket.trainNumber == "G123")
    #expect(ticket.departureStation == "上海虹桥")
    #expect(ticket.arrivalStation == "北京南")
    #expect(ticket.carriageNumber == "08")
    #expect(ticket.seatNumber == "03A")
    #expect(ticket.checkInGate == "B7")
    #expect(template?.kind == .train)
    #expect(template?.presentation.style == .trainTicket)
}

@Test func factoryCreatesTrainTicketFromExternalPayload() {
    let factory = EventTemplateFactory()

    let template = factory.makeTemplate(
        from: ExternalEventTemplatePayload(
            kind: .train,
            fields: [
                "trainNumber": "D2281",
                "departureStation": "南京南",
                "arrivalStation": "杭州东",
                "departureTime": "09:24",
                "arrivalTime": "11:06",
                "carriageNumber": "05",
                "seatNumber": "12F",
                "checkInGate": "A12",
                "passengerName": "Wen",
                "ticketNumber": "ETK-001",
                "seatClass": "二等座",
                "price": "¥96"
            ]
        )
    )

    #expect(template == .trainTicket(.init(
        trainNumber: "D2281",
        departureStation: "南京南",
        arrivalStation: "杭州东",
        departureTimeText: "09:24",
        arrivalTimeText: "11:06",
        carriageNumber: "05",
        seatNumber: "12F",
        checkInGate: "A12",
        passengerName: "Wen",
        ticketNumber: "ETK-001",
        seatClass: "二等座",
        priceText: "¥96"
    )))
}

@Test func externalPayloadNormalizesJSONScalarsToStrings() throws {
    let payload = try JSONDecoder().decode(
        ExternalEventTemplatePayload.self,
        from: Data(
            #"""
            {
              "kind": "task",
              "fields": {
                "title": "巡检",
                "count": 2,
                "ratio": 1.5,
                "urgent": true,
                "empty": null
              }
            }
            """#.utf8
        )
    )

    #expect(payload.fields["title"] == "巡检")
    #expect(payload.fields["count"] == "2")
    #expect(payload.fields["ratio"] == "1.5")
    #expect(payload.fields["urgent"] == "true")
    #expect(payload.fields["empty"] == nil)
}

@Test func externalPayloadRejectsNestedFieldValues() {
    let data = Data(
        #"{"kind":"task","fields":{"title":"巡检","metadata":{"source":"OCR"}}}"#.utf8
    )

    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(
            ExternalEventTemplatePayload.self,
            from: data
        )
    }
}

@Test func factoryCreatesGenericTaskFromExternalPayload() {
    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(
            kind: .task,
            fields: [
                "title": "巡逻",
                "location": "",
                "notes": "巡查楼梯口、仓库、围栏"
            ]
        )
    )

    #expect(template == .generic(.init(
        kind: .task,
        title: "巡逻",
        location: nil,
        notes: "巡查楼梯口、仓库、围栏",
        fields: [
            "title": "巡逻",
            "location": "",
            "notes": "巡查楼梯口、仓库、围栏"
        ]
    )))
    #expect(template?.presentation.fields.first?.label == "类型")
}

@Test func unknownPayloadWithDestinationBuildsGenericTemplate() {
    let fields = [
        "destination": "苏州",
        "eventDate": "2026-07-03",
        "location": "苏州文化中心",
        "notes": "携带报名二维码"
    ]

    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(kind: .unknown, fields: fields)
    )

    #expect(template == .generic(.init(
        kind: .unknown,
        title: "苏州",
        location: "苏州文化中心",
        notes: "携带报名二维码",
        fields: fields
    )))
}

@Test func factoryCreatesStructuredFlightFromExternalPayload() {
    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(
            kind: .flight,
            fields: [
                "flightNumber": "SQ 833",
                "carrier": "Singapore Airlines",
                "departureAirport": "Shanghai Pudong",
                "departureAirportCode": "PVG",
                "arrivalAirport": "Singapore Changi",
                "arrivalAirportCode": "SIN",
                "terminal": "T3",
                "gate": "B7",
                "seat": "12A"
            ]
        )
    )

    #expect(template == .flightTicket(.init(
        flightNumber: "SQ 833",
        carrier: "Singapore Airlines",
        departureAirport: "Shanghai Pudong",
        departureAirportCode: "PVG",
        arrivalAirport: "Singapore Changi",
        arrivalAirportCode: "SIN",
        departureTimeText: nil,
        arrivalTimeText: nil,
        terminal: "T3",
        gate: "B7",
        seat: "12A",
        travelStatus: nil
    )))
}

@Test func flightWithoutTicketFieldsUsesGenericTemplate() {
    let fields = [
        "title": "Airport pickup",
        "location": "T2 arrivals",
        "notes": "Meet at exit 3"
    ]

    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(kind: .flight, fields: fields)
    )

    #expect(template == .generic(.init(
        kind: .flight,
        title: "Airport pickup",
        location: "T2 arrivals",
        notes: "Meet at exit 3",
        fields: fields
    )))
}

@Test func genericTemplatePreservesRecognitionFieldsAcrossCodableRoundTrip() throws {
    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(
            kind: .interview,
            fields: [
                "title": "Design interview",
                "location": "Zoom",
                "interviewer": "Design Lead"
            ]
        )
    )

    let encoded = try JSONEncoder().encode(template)
    let decoded = try JSONDecoder().decode(
        TimelineEventTemplate.self,
        from: encoded
    )

    guard case let .generic(event) = decoded else {
        Issue.record("Expected generic event template")
        return
    }
    #expect(event.fields["interviewer"] == "Design Lead")
}

@Test func classifierUsesFactoryButKeepsReminderFallback() {
    let classifier = TimelineClassifier()

    #expect(classifier.classify(
        title: "G123 上海虹桥 → 北京南",
        location: nil,
        notes: nil,
        source: .calendar
    ) == .train)
    #expect(classifier.classify(
        title: "Buy milk",
        location: nil,
        notes: nil,
        source: .reminder
    ) == .task)
}

@Test func trainLocalRulesDoNotMatchLatinSubstrings() {
    let factory = EventTemplateFactory()

    #expect(factory.makeTemplate(from: .init(
        title: "Training plan",
        location: nil,
        notes: nil
    )) == nil)
}

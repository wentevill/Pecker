import Foundation
import Testing
@testable import PeckerCore

@Test func factoryCreatesTrainTicketFromLocalRules() {
    let factory = EventTemplateFactory()

    let template = factory.makeTemplate(
        from: ClassificationInput(
            title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
            location: "\u{68c0}\u{7968}\u{53e3} B7",
            notes: "08\u{8f66} 03A"
        )
    )

    guard case let .trainTicket(ticket) = template else {
        Issue.record("Expected train ticket template")
        return
    }
    #expect(ticket.trainNumber == "G123")
    #expect(ticket.departureStation == "\u{4e0a}\u{6d77}\u{8679}\u{6865}")
    #expect(ticket.arrivalStation == "\u{5317}\u{4eac}\u{5357}")
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
                "departureStation": "\u{5357}\u{4eac}\u{5357}",
                "arrivalStation": "\u{676d}\u{5dde}\u{4e1c}",
                "departureTime": "09:24",
                "arrivalTime": "11:06",
                "carriageNumber": "05",
                "seatNumber": "12F",
                "checkInGate": "A12",
                "passengerName": "Wen",
                "ticketNumber": "ETK-001",
                "seatClass": "\u{4e8c}\u{7b49}\u{5ea7}",
                "price": "¥96"
            ]
        )
    )

    #expect(template == .trainTicket(.init(
        trainNumber: "D2281",
        departureStation: "\u{5357}\u{4eac}\u{5357}",
        arrivalStation: "\u{676d}\u{5dde}\u{4e1c}",
        departureTimeText: "09:24",
        arrivalTimeText: "11:06",
        carriageNumber: "05",
        seatNumber: "12F",
        checkInGate: "A12",
        passengerName: "Wen",
        ticketNumber: "ETK-001",
        seatClass: "\u{4e8c}\u{7b49}\u{5ea7}",
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
                "title": "\#u{5de1}\#u{68c0}",
                "count": 2,
                "ratio": 1.5,
                "urgent": true,
                "empty": null
              }
            }
            """#.utf8
        )
    )

    #expect(payload.fields["title"] == "\u{5de1}\u{68c0}")
    #expect(payload.fields["count"] == "2")
    #expect(payload.fields["ratio"] == "1.5")
    #expect(payload.fields["urgent"] == "true")
    #expect(payload.fields["empty"] == nil)
}

@Test func externalPayloadRejectsNestedFieldValues() {
    let data = Data(
        #"{"kind":"task","fields":{"title":"\#u{5de1}\#u{68c0}","metadata":{"source":"OCR"}}}"#.utf8
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
                "title": "\u{5de1}\u{903b}",
                "location": "",
                "notes": "\u{5de1}\u{67e5}\u{697c}\u{68af}\u{53e3}、\u{4ed3}\u{5e93}、\u{56f4}\u{680f}"
            ]
        )
    )

    #expect(template == .generic(.init(
        kind: .task,
        title: "\u{5de1}\u{903b}",
        location: nil,
        notes: "\u{5de1}\u{67e5}\u{697c}\u{68af}\u{53e3}、\u{4ed3}\u{5e93}、\u{56f4}\u{680f}",
        fields: [
            "title": "\u{5de1}\u{903b}",
            "location": "",
            "notes": "\u{5de1}\u{67e5}\u{697c}\u{68af}\u{53e3}、\u{4ed3}\u{5e93}、\u{56f4}\u{680f}"
        ]
    )))
    #expect(template?.presentation.fields.first?.label == "\u{7c7b}\u{578b}")
}

@Test func unknownPayloadWithDestinationBuildsGenericTemplate() {
    let fields = [
        "destination": "\u{82cf}\u{5dde}",
        "eventDate": "2026-07-03",
        "location": "\u{82cf}\u{5dde}\u{6587}\u{5316}\u{4e2d}\u{5fc3}",
        "notes": "\u{643a}\u{5e26}\u{62a5}\u{540d}\u{4e8c}\u{7ef4}\u{7801}"
    ]

    let template = EventTemplateFactory().makeTemplate(
        from: ExternalEventTemplatePayload(kind: .unknown, fields: fields)
    )

    #expect(template == .generic(.init(
        kind: .unknown,
        title: "\u{82cf}\u{5dde}",
        location: "\u{82cf}\u{5dde}\u{6587}\u{5316}\u{4e2d}\u{5fc3}",
        notes: "\u{643a}\u{5e26}\u{62a5}\u{540d}\u{4e8c}\u{7ef4}\u{7801}",
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
        title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
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

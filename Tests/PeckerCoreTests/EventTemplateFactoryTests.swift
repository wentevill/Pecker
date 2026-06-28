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

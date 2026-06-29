import Foundation
import PeckerCore

struct LiveActivityPresentationAdapter: Sendable {
    func makeState(
        item: TimelineItem,
        status: PeckerLiveActivityStatus,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        switch item.template {
        case let .trainTicket(ticket):
            trainState(
                item: item,
                ticket: ticket,
                status: status,
                generatedAt: generatedAt
            )
        case let .flightTicket(ticket):
            flightState(
                item: item,
                ticket: ticket,
                status: status,
                generatedAt: generatedAt
            )
        case let .generic(event):
            genericState(
                item: item,
                event: event,
                status: status,
                generatedAt: generatedAt
            )
        case nil:
            genericState(
                item: item,
                event: nil,
                status: status,
                generatedAt: generatedAt
            )
        }
    }

    private func trainState(
        item: TimelineItem,
        ticket: TrainTicketTemplate,
        status: PeckerLiveActivityStatus,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        let route = [ticket.departureStation, ticket.arrivalStation]
            .compactMap(clean)
            .joined(separator: " → ")
        let metadata = [
            ticket.carriageNumber.map { "\($0) 车" },
            ticket.seatNumber.map { "\($0) 座" },
            ticket.checkInGate.map { "\($0) 检票口" },
            ticket.seatClass
        ]
        .compactMap(clean)

        return state(
            item: item,
            status: status,
            title: clean(ticket.trainNumber) ?? item.title,
            secondaryIdentity: clean(route),
            leadingEndpoint: clean(ticket.departureStation),
            trailingEndpoint: clean(ticket.arrivalStation),
            location: clean(item.location),
            supportingDetail: clean(item.notes),
            metadata: metadata,
            generatedAt: generatedAt
        )
    }

    private func flightState(
        item: TimelineItem,
        ticket: FlightTicketTemplate,
        status: PeckerLiveActivityStatus,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        let metadata = [
            ticket.terminal,
            ticket.gate.map { "Gate \($0)" },
            ticket.seat.map { "\($0) 座" },
            ticket.travelStatus
        ]
        .compactMap(clean)

        return state(
            item: item,
            status: status,
            title: clean(ticket.flightNumber) ?? item.title,
            secondaryIdentity: clean(ticket.carrier),
            leadingEndpoint: endpoint(
                name: ticket.departureAirport,
                code: ticket.departureAirportCode
            ),
            trailingEndpoint: endpoint(
                name: ticket.arrivalAirport,
                code: ticket.arrivalAirportCode
            ),
            location: clean(item.location),
            supportingDetail: clean(item.notes),
            metadata: metadata,
            generatedAt: generatedAt
        )
    }

    private func genericState(
        item: TimelineItem,
        event: GenericEventTemplate?,
        status: PeckerLiveActivityStatus,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        let location = clean(event?.location) ?? clean(item.location)
        let notes = clean(event?.notes) ?? clean(item.notes)
        let preservedDetail = event?.fields
            .sorted { $0.key < $1.key }
            .lazy
            .filter { !Self.genericIdentityKeys.contains($0.key) }
            .map(\.value)
            .compactMap(clean)
            .first

        return state(
            item: item,
            status: status,
            title: clean(event?.title) ?? item.title,
            secondaryIdentity: nil,
            leadingEndpoint: nil,
            trailingEndpoint: nil,
            location: location,
            supportingDetail: notes ?? preservedDetail,
            metadata: [],
            generatedAt: generatedAt
        )
    }

    private func state(
        item: TimelineItem,
        status: PeckerLiveActivityStatus,
        title: String,
        secondaryIdentity: String?,
        leadingEndpoint: String?,
        trailingEndpoint: String?,
        location: String?,
        supportingDetail: String?,
        metadata: [String],
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        PeckerActivityAttributes.ContentState(
            itemIdentifier: item.id,
            title: title,
            secondaryIdentity: secondaryIdentity,
            kindRawValue: item.kind.rawValue,
            symbolName: symbolName(for: item.kind),
            statusRawValue: status.rawValue,
            startDate: item.startDate,
            endDate: item.endDate,
            leadingEndpoint: leadingEndpoint,
            trailingEndpoint: trailingEndpoint,
            location: location,
            supportingDetail: supportingDetail,
            metadata: metadata,
            generatedAt: generatedAt
        )
    }

    private func endpoint(name: String?, code: String?) -> String? {
        switch (clean(code), clean(name)) {
        case let (code?, name?):
            "\(code) · \(name)"
        case let (code?, nil):
            code
        case let (nil, name?):
            name
        case (nil, nil):
            nil
        }
    }

    private func symbolName(for kind: TimelineKind) -> String {
        switch kind {
        case .meeting:
            "person.2.fill"
        case .task:
            "checklist"
        case .flight:
            "airplane"
        case .train:
            "train.side.front.car"
        case .travel:
            "suitcase.fill"
        case .interview:
            "person.text.rectangle"
        case .deadline:
            "calendar.badge.exclamationmark"
        case .unknown:
            "clock.fill"
        }
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static let genericIdentityKeys: Set<String> = [
        "title",
        "eventTitle",
        "事件标题",
        "location",
        "地点",
        "notes",
        "description",
        "details",
        "备注"
    ]
}

private extension PeckerLiveActivityStatus {
    var rawValue: String {
        switch self {
        case .now:
            "now"
        case .next:
            "next"
        case .pinned:
            "pinned"
        }
    }
}
